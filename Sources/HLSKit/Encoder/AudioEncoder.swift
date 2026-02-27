// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)

    @preconcurrency import AVFoundation
    import os

    /// Real-time audio encoder using Apple's `AVAudioConverter`.
    ///
    /// Encodes PCM audio (Int16 interleaved) into AAC. Accumulates PCM
    /// samples into 1024-sample frames as required by AAC, and tracks
    /// encoder delay for accurate timestamps.
    ///
    /// All CoreAudio operations execute on a dedicated serial
    /// `DispatchQueue`, avoiding the `dispatch_assert_queue` crash that
    /// occurs when CoreAudio internal calls run on the Swift cooperative
    /// thread pool.
    ///
    /// ## Lifecycle
    /// ```swift
    /// let encoder = AudioEncoder()
    /// try await encoder.configure(.podcastAudio)
    /// let frames = try await encoder.encode(pcmBuffer)
    /// let remaining = try await encoder.flush()
    /// await encoder.teardown()
    /// ```
    ///
    /// - Important: This encoder is only available on Apple platforms
    ///   where `AVFoundation` is available.
    ///
    /// - Note: `@unchecked Sendable` — thread safety guaranteed by
    ///   routing all mutable state through the serial `audioQueue`.
    public final class AudioEncoder: LiveEncoder, @unchecked Sendable {

        // MARK: - Queue

        private let audioQueue = DispatchQueue(
            label: "com.atelier-socle.hlskit.audio-encoder",
            qos: .userInteractive
        )

        // MARK: - State (accessed only on audioQueue)

        private var converter: AVAudioConverter?
        private var inputFormat: AVAudioFormat?
        private var outputFormat: AVAudioFormat?
        private var configuration: LiveEncoderConfiguration?
        private var pcmBuffer: Data = Data()
        private var currentTimestamp: Double = 0.0
        private var isTornDown: Bool = false
        private var framesEncoded: Int64 = 0

        /// Number of samples per AAC frame.
        private let samplesPerFrame: Int = 1024

        /// Creates an audio encoder.
        public init() {}

        // MARK: - LiveEncoder

        public func configure(
            _ configuration: LiveEncoderConfiguration
        ) async throws {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                self.audioQueue.async {
                    do {
                        try self.performConfigure(configuration)
                        cont.resume()
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }

        public func encode(
            _ buffer: RawMediaBuffer
        ) async throws -> [EncodedFrame] {
            try await withCheckedThrowingContinuation { cont in
                self.audioQueue.async {
                    do {
                        let frames = try self.performEncode(buffer)
                        cont.resume(returning: frames)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }

        public func flush() async throws -> [EncodedFrame] {
            try await withCheckedThrowingContinuation { cont in
                self.audioQueue.async {
                    do {
                        let frames = try self.performFlush()
                        cont.resume(returning: frames)
                    } catch {
                        cont.resume(throwing: error)
                    }
                }
            }
        }

        public func teardown() async {
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                self.audioQueue.async {
                    self.performTeardown()
                    cont.resume()
                }
            }
        }
    }

    // MARK: - Private Implementation (always on audioQueue)

    extension AudioEncoder {

        private func performConfigure(
            _ configuration: LiveEncoderConfiguration
        ) throws {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            try validateConfiguration(configuration)
            disposeConverter()
            try setupConverter(for: configuration)
            self.configuration = configuration
            self.pcmBuffer = Data()
            self.currentTimestamp = 0.0
            self.framesEncoded = 0
        }

        private func performEncode(
            _ buffer: RawMediaBuffer
        ) throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard let config = configuration, converter != nil
            else {
                throw LiveEncoderError.notConfigured
            }
            try validateBuffer(buffer, against: config)

            pcmBuffer.append(buffer.data)
            return try drainCompleteFrames(config: config)
        }

        private func performFlush() throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard let config = configuration, converter != nil
            else {
                throw LiveEncoderError.notConfigured
            }

            var frames: [EncodedFrame] = []

            if !pcmBuffer.isEmpty {
                let bytesPerAACFrame =
                    samplesPerFrame * 2 * config.channels
                let padding =
                    bytesPerAACFrame - pcmBuffer.count
                pcmBuffer.append(
                    Data(repeating: 0, count: padding)
                )

                if let encoded = try encodeFrame(
                    config: config
                ) {
                    frames.append(encoded)
                }
                pcmBuffer = Data()
            }

            return frames
        }

        private func performTeardown() {
            disposeConverter()
            configuration = nil
            pcmBuffer = Data()
            isTornDown = true
        }
    }

    // MARK: - Configuration Helpers

    extension AudioEncoder {

        private func validateConfiguration(
            _ configuration: LiveEncoderConfiguration
        ) throws {
            guard configuration.audioCodec == .aac else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "AudioEncoder only supports AAC output, "
                        + "got \(configuration.audioCodec.rawValue)"
                )
            }
            guard !configuration.passthrough else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "AudioEncoder does not support "
                        + "passthrough mode"
                )
            }
        }

        /// Creates an `AVAudioConverter` for PCM Int16 → AAC
        /// and assigns `converter`, `inputFormat`, `outputFormat`.
        private func setupConverter(
            for config: LiveEncoderConfiguration
        ) throws {
            guard
                let inFmt = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: config.sampleRate,
                    channels: AVAudioChannelCount(
                        config.channels
                    ),
                    interleaved: true
                )
            else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "Cannot create PCM input format"
                )
            }

            var outputDesc = AudioStreamBasicDescription(
                mSampleRate: config.sampleRate,
                mFormatID: kAudioFormatMPEG4AAC,
                mFormatFlags: 0,
                mBytesPerPacket: 0,
                mFramesPerPacket: UInt32(samplesPerFrame),
                mBytesPerFrame: 0,
                mChannelsPerFrame: UInt32(
                    config.channels
                ),
                mBitsPerChannel: 0,
                mReserved: 0
            )

            guard
                let outFmt = AVAudioFormat(
                    streamDescription: &outputDesc
                )
            else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "Cannot create AAC output format"
                )
            }

            guard
                let conv = AVAudioConverter(
                    from: inFmt, to: outFmt
                )
            else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "AVAudioConverter creation failed "
                        + "for PCM → AAC"
                )
            }

            conv.bitRate = config.bitrate
            self.inputFormat = inFmt
            self.outputFormat = outFmt
            self.converter = conv
        }

        private func disposeConverter() {
            converter = nil
            inputFormat = nil
            outputFormat = nil
        }
    }

    // MARK: - Buffer Validation

    extension AudioEncoder {

        private func validateBuffer(
            _ buffer: RawMediaBuffer,
            against config: LiveEncoderConfiguration
        ) throws {
            guard buffer.mediaType == .audio else {
                throw LiveEncoderError.formatMismatch(
                    "Expected audio buffer, "
                        + "got \(buffer.mediaType.rawValue)"
                )
            }

            switch buffer.formatInfo {
            case .audio(let sampleRate, let channels, _, _):
                guard sampleRate == config.sampleRate else {
                    throw LiveEncoderError.formatMismatch(
                        "Expected sample rate "
                            + "\(config.sampleRate), "
                            + "got \(sampleRate)"
                    )
                }
                guard channels == config.channels else {
                    throw LiveEncoderError.formatMismatch(
                        "Expected \(config.channels) "
                            + "channels, got \(channels)"
                    )
                }
            case .video:
                throw LiveEncoderError.formatMismatch(
                    "Expected audio format info, got video"
                )
            }
        }
    }

    // MARK: - Encoding

    extension AudioEncoder {

        private func drainCompleteFrames(
            config: LiveEncoderConfiguration
        ) throws -> [EncodedFrame] {
            let bytesPerAACFrame =
                samplesPerFrame * 2 * config.channels
            var frames: [EncodedFrame] = []

            while pcmBuffer.count >= bytesPerAACFrame {
                if let encoded = try encodeFrame(
                    config: config
                ) {
                    frames.append(encoded)
                }
            }

            return frames
        }

        /// Encodes one 1024-sample AAC frame using
        /// `AVAudioConverter`.
        private func encodeFrame(
            config: LiveEncoderConfiguration
        ) throws -> EncodedFrame? {
            guard let converter, let inputFormat,
                let outputFormat
            else {
                throw LiveEncoderError.notConfigured
            }

            let bytesPerAACFrame =
                samplesPerFrame * 2 * config.channels
            let frameData = Data(
                pcmBuffer.prefix(bytesPerAACFrame)
            )
            pcmBuffer.removeFirst(bytesPerAACFrame)

            // Build AVAudioPCMBuffer from raw Int16 data
            guard
                let inputBuffer = AVAudioPCMBuffer(
                    pcmFormat: inputFormat,
                    frameCapacity: AVAudioFrameCount(
                        samplesPerFrame
                    )
                )
            else {
                return nil
            }
            inputBuffer.frameLength = AVAudioFrameCount(
                samplesPerFrame
            )

            frameData.withUnsafeBytes { raw in
                guard let src = raw.baseAddress,
                    let dst = inputBuffer.int16ChannelData?[0]
                else { return }
                memcpy(dst, src, frameData.count)
            }

            // Encode via AVAudioConverter
            let data = try convertBuffer(
                inputBuffer,
                converter: converter,
                outputFormat: outputFormat
            )
            guard let data else { return nil }

            return makeEncodedFrame(
                data: data, config: config
            )
        }

        /// Runs the AVAudioConverter conversion for one buffer.
        private func convertBuffer(
            _ input: AVAudioPCMBuffer,
            converter: AVAudioConverter,
            outputFormat: AVAudioFormat
        ) throws -> Data? {
            let maxSize = max(
                converter.maximumOutputPacketSize, 8192
            )
            let outputBuffer = AVAudioCompressedBuffer(
                format: outputFormat,
                packetCapacity: 1,
                maximumPacketSize: maxSize
            )

            var error: NSError?
            let pending = OSAllocatedUnfairLock(
                initialState: true
            )

            let status = converter.convert(
                to: outputBuffer, error: &error
            ) { _, outStatus in
                let provide = pending.withLock {
                    let val = $0
                    $0 = false
                    return val
                }
                if provide {
                    outStatus.pointee = .haveData
                    return input
                }
                outStatus.pointee = .noDataNow
                return nil
            }

            if let error {
                throw LiveEncoderError.encodingFailed(
                    "AVAudioConverter error: "
                        + error.localizedDescription
                )
            }

            guard status != .error else {
                throw LiveEncoderError.encodingFailed(
                    "AVAudioConverter returned error status"
                )
            }

            guard outputBuffer.byteLength > 0 else {
                return nil
            }

            return Data(
                bytes: outputBuffer.data,
                count: Int(outputBuffer.byteLength)
            )
        }

        private func makeEncodedFrame(
            data: Data,
            config: LiveEncoderConfiguration
        ) -> EncodedFrame {
            let frameDuration =
                Double(samplesPerFrame) / config.sampleRate
            let timestamp = currentTimestamp
            currentTimestamp += frameDuration
            framesEncoded += 1

            return EncodedFrame(
                data: data,
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

#endif
