// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation

    /// Real-time video encoder using an ffmpeg subprocess.
    ///
    /// Converts raw YUV420p pixel data to H.264/HEVC via ffmpeg
    /// stdin/stdout pipe streaming. Uses a background reader on
    /// stdout to avoid pipe deadlocks.
    ///
    /// ## Architecture
    /// ```
    /// Raw YUV → stdin → [ffmpeg] → stdout → H.264/HEVC NAL units
    /// ```
    ///
    /// ## Usage
    /// ```swift
    /// let encoder = FFmpegVideoEncoder()
    /// try await encoder.configure(LiveEncoderConfiguration(
    ///     videoCodec: .h264,
    ///     videoBitrate: 2_800_000,
    ///     keyframeInterval: 6.0,
    ///     qualityPreset: .p720
    /// ))
    /// let frames = try await encoder.encode(videoBuffer)
    /// let remaining = try await encoder.flush()
    /// await encoder.teardown()
    /// ```
    public actor FFmpegVideoEncoder: LiveEncoder {

        // MARK: - State

        private var process: Process?
        private var stdinPipe: Pipe?
        private var collector: OutputCollector?
        private var configuration: LiveEncoderConfiguration?
        private var isTornDown = false
        private var currentTimestamp: Double = 0.0
        private var frameCount: Int = 0
        private var residualData: Data = Data()
        private var videoCodec: VideoCodec = .h264
        private var frameDuration: Double = 1.0 / 30.0
        private var videoBitrateHint: Int = 0

        /// Whether ffmpeg is available on this system.
        public static var isAvailable: Bool {
            FFmpegProcessRunner.findExecutable("ffmpeg") != nil
        }

        /// Creates an FFmpeg video encoder.
        public init() {}

        // MARK: - LiveEncoder

        public func configure(
            _ configuration: LiveEncoderConfiguration
        ) throws {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }

            guard let codec = configuration.videoCodec else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "FFmpegVideoEncoder requires videoCodec"
                )
            }

            guard codec == .h264 || codec == .h265 else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "FFmpegVideoEncoder supports H.264 and "
                        + "HEVC, got \(codec.rawValue)"
                )
            }

            guard
                let ffmpegPath =
                    FFmpegProcessRunner.findExecutable("ffmpeg")
            else {
                throw LiveEncoderError.ffmpegNotAvailable
            }

            teardownProcess()

            let args = Self.buildArguments(for: configuration)
            let stdin = Pipe()
            let stdout = Pipe()
            let stderr = Pipe()

            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: ffmpegPath)
            proc.arguments = args
            proc.standardInput = stdin
            proc.standardOutput = stdout
            proc.standardError = stderr

            let output = OutputCollector()
            stdout.fileHandleForReading.readabilityHandler =
                { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    Task { await output.append(data) }
                }

            do {
                try proc.run()
            } catch {
                stdout.fileHandleForReading.readabilityHandler =
                    nil
                throw LiveEncoderError.ffmpegProcessError(
                    "Failed to launch ffmpeg: "
                        + "\(error.localizedDescription)"
                )
            }

            applyState(
                proc, stdin: stdin, output: output,
                configuration: configuration, codec: codec
            )
        }

        public func encode(
            _ buffer: RawMediaBuffer
        ) async throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard configuration != nil else {
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
            guard
                buffer.mediaType == .video
                    || buffer.mediaType == .audioVideo
            else {
                throw LiveEncoderError.formatMismatch(
                    "Expected video buffer, "
                        + "got \(buffer.mediaType.rawValue)"
                )
            }

            stdin.fileHandleForWriting.write(buffer.data)
            try? await Task.sleep(nanoseconds: 10_000_000)

            let outputData =
                await collector?.drain() ?? Data()
            return parseNALFrames(from: outputData)
        }

        public func flush() async throws -> [EncodedFrame] {
            guard !isTornDown else { return [] }
            guard let stdin = stdinPipe else { return [] }

            stdin.fileHandleForWriting.closeFile()

            if let proc = process, proc.isRunning {
                await withCheckedContinuation { continuation in
                    proc.terminationHandler = { _ in
                        continuation.resume()
                    }
                }
            }

            try? await Task.sleep(nanoseconds: 50_000_000)

            let remainingData =
                await collector?.drain() ?? Data()
            return parseNALFrames(from: remainingData)
        }

        public func teardown() {
            teardownProcess()
            configuration = nil
            isTornDown = true
            residualData = Data()
        }

        // MARK: - Argument Building

        /// Builds ffmpeg command-line arguments for video encoding.
        ///
        /// - Parameter configuration: The encoder configuration.
        /// - Returns: Array of ffmpeg arguments.
        static func buildArguments(
            for configuration: LiveEncoderConfiguration
        ) -> [String] {
            let preset = configuration.qualityPreset ?? .p720
            let width = preset.resolution?.width ?? 1280
            let height = preset.resolution?.height ?? 720
            let bitrate =
                configuration.videoBitrate
                ?? preset.videoBitrate ?? 2_800_000
            let keyframeInterval =
                configuration.keyframeInterval ?? 6.0
            let fps = preset.frameRate ?? 30.0
            let gopSize = Int(keyframeInterval * fps)
            let codec = configuration.videoCodec ?? .h264
            let profile = preset.videoProfile ?? .high

            var args: [String] = []
            args.append(
                contentsOf: [
                    "-hide_banner", "-loglevel", "error"
                ]
            )

            args.append(contentsOf: ["-f", "rawvideo"])
            args.append(contentsOf: ["-pix_fmt", "yuv420p"])
            args.append(
                contentsOf: ["-s", "\(width)x\(height)"]
            )
            args.append(
                contentsOf: ["-r", String(Int(fps))]
            )
            args.append(contentsOf: ["-i", "pipe:0"])

            appendCodecArgs(
                codec: codec, profile: profile,
                bitrate: bitrate, gopSize: gopSize,
                to: &args
            )

            return args
        }

        // MARK: - Private

        private func parseNALFrames(
            from data: Data
        ) -> [EncodedFrame] {
            guard !data.isEmpty else { return [] }

            var inputData = residualData
            inputData.append(data)

            let result = NALUnitParser.parseAccessUnits(
                from: inputData, codec: videoCodec
            )

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

            let codec: EncodedCodec =
                videoCodec == .h265 ? .h265 : .h264

            return result.accessUnits.map { au in
                let timestamp = currentTimestamp
                currentTimestamp += frameDuration
                frameCount += 1

                return EncodedFrame(
                    data: au.data,
                    timestamp: MediaTimestamp(
                        seconds: timestamp
                    ),
                    duration: MediaTimestamp(
                        seconds: frameDuration
                    ),
                    isKeyframe: au.isKeyframe,
                    codec: codec,
                    bitrateHint: videoBitrateHint
                )
            }
        }

        private func applyState(
            _ proc: Process, stdin: Pipe,
            output: OutputCollector,
            configuration: LiveEncoderConfiguration,
            codec: VideoCodec
        ) {
            self.process = proc
            self.stdinPipe = stdin
            self.collector = output
            self.configuration = configuration
            self.videoCodec = codec
            let preset = configuration.qualityPreset ?? .p720
            let fps = preset.frameRate ?? 30.0
            self.frameDuration = 1.0 / fps
            self.videoBitrateHint =
                configuration.videoBitrate
                ?? preset.videoBitrate ?? 2_800_000
            self.currentTimestamp = 0.0
            self.frameCount = 0
            self.residualData = Data()
        }

        private func teardownProcess() {
            if let proc = process, proc.isRunning {
                proc.terminate()
            }
            stdinPipe = nil
            collector = nil
            process = nil
        }

        private static func appendCodecArgs(
            codec: VideoCodec, profile: VideoProfile,
            bitrate: Int, gopSize: Int,
            to args: inout [String]
        ) {
            switch codec {
            case .h264:
                args.append(contentsOf: ["-c:v", "libx264"])
                args.append(
                    contentsOf: [
                        "-profile:v",
                        ffmpegProfileName(profile)
                    ]
                )
            case .h265:
                args.append(contentsOf: ["-c:v", "libx265"])
                args.append(contentsOf: ["-tag:v", "hvc1"])
            case .av1:
                args.append(
                    contentsOf: ["-c:v", "libaom-av1"]
                )
            case .vp9:
                args.append(
                    contentsOf: ["-c:v", "libvpx-vp9"]
                )
            }

            let brK = "\(bitrate / 1000)k"
            let maxK = "\(Int(Double(bitrate) * 1.5) / 1000)k"
            let bufK = "\(bitrate * 2 / 1000)k"
            args.append(contentsOf: ["-b:v", brK])
            args.append(contentsOf: ["-maxrate", maxK])
            args.append(contentsOf: ["-bufsize", bufK])
            args.append(contentsOf: ["-g", String(gopSize)])
            args.append(
                contentsOf: ["-keyint_min", String(gopSize)]
            )

            switch codec {
            case .h264:
                args.append(
                    contentsOf: ["-f", "h264", "pipe:1"]
                )
            case .h265:
                args.append(
                    contentsOf: ["-f", "hevc", "pipe:1"]
                )
            case .av1:
                args.append(
                    contentsOf: ["-f", "ivf", "pipe:1"]
                )
            case .vp9:
                args.append(
                    contentsOf: ["-f", "ivf", "pipe:1"]
                )
            }
        }

        private static func ffmpegProfileName(
            _ profile: VideoProfile
        ) -> String {
            switch profile {
            case .baseline: "baseline"
            case .main: "main"
            case .high: "high"
            case .mainHEVC: "main"
            case .main10HEVC: "main10"
            }
        }
    }

#endif
