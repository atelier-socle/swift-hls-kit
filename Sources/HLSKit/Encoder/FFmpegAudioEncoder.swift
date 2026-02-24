// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation

    /// Real-time audio encoder using an ffmpeg subprocess.
    ///
    /// Launches ffmpeg with stdin/stdout pipes to encode raw PCM audio into
    /// AAC (ADTS format). Uses a background reader on stdout to avoid pipe
    /// deadlocks. Suitable for Linux and systems without AudioToolbox.
    ///
    /// ## Lifecycle
    /// ```swift
    /// let encoder = FFmpegAudioEncoder()
    /// try await encoder.configure(.podcastAudio)
    /// let frames = try await encoder.encode(pcmBuffer)
    /// let remaining = try await encoder.flush()
    /// await encoder.teardown()
    /// ```
    ///
    /// - Important: Requires ffmpeg to be installed and available in PATH.
    public actor FFmpegAudioEncoder: LiveEncoder {

        // MARK: - State

        private var process: Process?
        private var stdinPipe: Pipe?
        private var collector: OutputCollector?
        private var configuration: LiveEncoderConfiguration?
        private var isTornDown: Bool = false
        private var currentTimestamp: Double = 0.0
        private var framesEncoded: Int64 = 0
        private var residualData: Data = Data()
        private let parser = ADTSParser()

        /// Whether ffmpeg is available on this system.
        public static var isAvailable: Bool {
            FFmpegProcessRunner.findExecutable("ffmpeg") != nil
        }

        /// Creates an FFmpeg audio encoder.
        public init() {}

        // MARK: - LiveEncoder

        public func configure(
            _ configuration: LiveEncoderConfiguration
        ) throws {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }

            guard configuration.audioCodec == .aac else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "FFmpegAudioEncoder only supports AAC output, "
                        + "got \(configuration.audioCodec.rawValue)"
                )
            }

            guard !configuration.passthrough else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "FFmpegAudioEncoder does not support passthrough mode"
                )
            }

            guard
                let ffmpegPath =
                    FFmpegProcessRunner.findExecutable("ffmpeg")
            else {
                throw LiveEncoderError.ffmpegNotAvailable
            }

            teardownProcess()

            let stdin = Pipe()
            let stdout = Pipe()
            let stderr = Pipe()

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: ffmpegPath)
            proc.arguments = Self.buildArguments(for: configuration)
            proc.standardInput = stdin
            proc.standardOutput = stdout
            proc.standardError = stderr

            // Start collecting stdout BEFORE launching the process
            let output = OutputCollector()
            stdout.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                Task { await output.append(data) }
            }

            do {
                try proc.run()
            } catch {
                stdout.fileHandleForReading.readabilityHandler = nil
                throw LiveEncoderError.ffmpegProcessError(
                    "Failed to launch ffmpeg: "
                        + "\(error.localizedDescription)"
                )
            }

            self.process = proc
            self.stdinPipe = stdin
            self.collector = output
            self.configuration = configuration
            self.currentTimestamp = 0.0
            self.framesEncoded = 0
            self.residualData = Data()
        }

        public func encode(
            _ buffer: RawMediaBuffer
        ) async throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard let config = configuration else {
                throw LiveEncoderError.notConfigured
            }
            guard let stdin = stdinPipe else {
                throw LiveEncoderError.notConfigured
            }
            guard let proc = process, proc.isRunning else {
                throw LiveEncoderError.ffmpegProcessError(
                    "ffmpeg process is not running"
                )
            }

            guard buffer.mediaType == .audio else {
                throw LiveEncoderError.formatMismatch(
                    "Expected audio buffer, "
                        + "got \(buffer.mediaType.rawValue)"
                )
            }

            // Write PCM data to ffmpeg stdin (non-blocking: stdout
            // is drained by readabilityHandler in background)
            stdin.fileHandleForWriting.write(buffer.data)

            // Give ffmpeg a moment to process
            try? await Task.sleep(nanoseconds: 10_000_000)

            // Drain whatever the collector has accumulated
            let outputData = await collector?.drain() ?? Data()
            return parseADTSFrames(from: outputData, config: config)
        }

        public func flush() async throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard let config = configuration else {
                throw LiveEncoderError.notConfigured
            }
            guard let stdin = stdinPipe else {
                throw LiveEncoderError.notConfigured
            }

            // Close stdin to signal EOF — stdout reader runs in background
            stdin.fileHandleForWriting.closeFile()

            // Wait for ffmpeg to exit via continuation (not blocking)
            if let proc = process, proc.isRunning {
                await withCheckedContinuation { continuation in
                    proc.terminationHandler = { _ in
                        continuation.resume()
                    }
                }
            }

            // Small delay for readabilityHandler to flush
            try? await Task.sleep(nanoseconds: 50_000_000)

            let remainingData = await collector?.drain() ?? Data()
            return parseADTSFrames(from: remainingData, config: config)
        }

        public func teardown() {
            teardownProcess()
            configuration = nil
            isTornDown = true
            residualData = Data()
        }

        // MARK: - Argument Building

        /// Builds ffmpeg command-line arguments for the given configuration.
        ///
        /// - Parameter configuration: The encoder configuration.
        /// - Returns: Array of ffmpeg arguments.
        static func buildArguments(
            for configuration: LiveEncoderConfiguration
        ) -> [String] {
            var args: [String] = []

            args.append(
                contentsOf: ["-hide_banner", "-loglevel", "error"]
            )

            // Input: raw PCM s16le
            args.append(contentsOf: ["-f", "s16le"])
            let rate = "\(Int(configuration.sampleRate))"
            let ch = "\(configuration.channels)"
            args.append(contentsOf: ["-ar", rate])
            args.append(contentsOf: ["-ac", ch])
            args.append(contentsOf: ["-i", "pipe:0"])

            // Output: AAC
            args.append(contentsOf: ["-c:a", "aac"])
            let br = "\(configuration.bitrate / 1000)k"
            args.append(contentsOf: ["-b:a", br])
            args.append(contentsOf: ["-ar", rate])
            args.append(contentsOf: ["-ac", ch])

            if let profile = configuration.aacProfile {
                let name: String
                switch profile {
                case .lc: name = "aac_low"
                case .he: name = "aac_he"
                case .heV2: name = "aac_he_v2"
                case .ld: name = "aac_ld"
                case .eld: name = "aac_eld"
                }
                args.append(contentsOf: ["-profile:a", name])
            }

            args.append(contentsOf: ["-f", "adts", "pipe:1"])

            return args
        }

        // MARK: - Private

        private func parseADTSFrames(
            from data: Data,
            config: LiveEncoderConfiguration
        ) -> [EncodedFrame] {
            guard !data.isEmpty else { return [] }

            var inputData = residualData
            inputData.append(data)

            let result = parser.parseFrames(from: inputData)

            if result.bytesConsumed < inputData.count {
                residualData = Data(
                    inputData.suffix(
                        from: inputData.startIndex
                            + result.bytesConsumed
                    )
                )
            } else {
                residualData = Data()
            }

            let frameDuration = 1024.0 / config.sampleRate

            return result.frames.map { adtsFrame in
                let timestamp = currentTimestamp
                currentTimestamp += frameDuration
                framesEncoded += 1

                return EncodedFrame(
                    data: adtsFrame.payload,
                    timestamp: MediaTimestamp(
                        seconds: timestamp,
                        timescale: Int32(config.sampleRate)
                    ),
                    duration: MediaTimestamp(
                        seconds: frameDuration,
                        timescale: Int32(config.sampleRate)
                    ),
                    isKeyframe: true,
                    codec: .aac,
                    bitrateHint: config.bitrate
                )
            }
        }

        private func teardownProcess() {
            if let proc = process, proc.isRunning {
                proc.terminate()
            }
            stdinPipe = nil
            collector = nil
            process = nil
        }
    }

    // MARK: - OutputCollector

    /// Thread-safe collector for stdout data from ffmpeg.
    ///
    /// Called from `readabilityHandler` (background thread) and drained
    /// from the ``FFmpegAudioEncoder`` actor.
    actor OutputCollector {
        private var buffer: Data = Data()

        /// Appends data received from the stdout pipe.
        func append(_ data: Data) {
            buffer.append(data)
        }

        /// Drains and returns all accumulated data, resetting the buffer.
        func drain() -> Data {
            let data = buffer
            buffer = Data()
            return data
        }
    }

#endif
