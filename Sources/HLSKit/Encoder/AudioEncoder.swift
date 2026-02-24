// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AudioToolbox)

    import AudioToolbox
    import Foundation

    /// Real-time audio encoder using Apple AudioToolbox.
    ///
    /// Wraps `AudioConverterRef` to encode PCM audio (Int16 or Float32) into AAC.
    /// Accumulates PCM samples into 1024-sample frames as required by AAC, and
    /// tracks encoder delay for accurate timestamps.
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
    /// - Important: This encoder is only available on Apple platforms where
    ///   `AudioToolbox` is available.
    public actor AudioEncoder: LiveEncoder {

        // MARK: - State

        private var converter: AudioConverterRef?
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
        ) throws {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            try validateConfiguration(configuration)
            disposeConverter()
            let ref = try createConverter(for: configuration)
            configureBitrate(ref, bitrate: configuration.bitrate)
            applyConfiguration(ref, configuration)
        }

        public func encode(
            _ buffer: RawMediaBuffer
        ) throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard let config = configuration, converter != nil else {
                throw LiveEncoderError.notConfigured
            }
            try validateBuffer(buffer, against: config)

            pcmBuffer.append(buffer.data)
            return try drainCompleteFrames(config: config)
        }

        public func flush() throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard let config = configuration, converter != nil else {
                throw LiveEncoderError.notConfigured
            }

            var frames: [EncodedFrame] = []

            if !pcmBuffer.isEmpty {
                let bytesPerAACFrame =
                    samplesPerFrame * 2 * config.channels
                let padding = bytesPerAACFrame - pcmBuffer.count
                pcmBuffer.append(
                    Data(repeating: 0, count: padding)
                )

                if let encoded = try encodeFrame(config: config) {
                    frames.append(encoded)
                }
                pcmBuffer = Data()
            }

            return frames
        }

        public func teardown() {
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
                    "AudioEncoder does not support passthrough mode"
                )
            }
        }

        private func createConverter(
            for configuration: LiveEncoderConfiguration
        ) throws -> AudioConverterRef {
            var inputASBD = AudioStreamBasicDescription(
                mSampleRate: configuration.sampleRate,
                mFormatID: kAudioFormatLinearPCM,
                mFormatFlags:
                    kAudioFormatFlagIsSignedInteger
                    | kAudioFormatFlagIsPacked,
                mBytesPerPacket: UInt32(
                    2 * configuration.channels
                ),
                mFramesPerPacket: 1,
                mBytesPerFrame: UInt32(
                    2 * configuration.channels
                ),
                mChannelsPerFrame: UInt32(
                    configuration.channels
                ),
                mBitsPerChannel: 16,
                mReserved: 0
            )

            var outputASBD = AudioStreamBasicDescription(
                mSampleRate: configuration.sampleRate,
                mFormatID: kAudioFormatMPEG4AAC,
                mFormatFlags: 0,
                mBytesPerPacket: 0,
                mFramesPerPacket: UInt32(samplesPerFrame),
                mBytesPerFrame: 0,
                mChannelsPerFrame: UInt32(
                    configuration.channels
                ),
                mBitsPerChannel: 0,
                mReserved: 0
            )

            var ref: AudioConverterRef?
            let status = AudioConverterNew(
                &inputASBD, &outputASBD, &ref
            )

            guard status == noErr, let converter = ref else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "AudioConverterNew failed: \(status)"
                )
            }
            return converter
        }

        private func configureBitrate(
            _ ref: AudioConverterRef, bitrate: Int
        ) {
            var value = UInt32(bitrate)
            AudioConverterSetProperty(
                ref,
                kAudioConverterEncodeBitRate,
                UInt32(MemoryLayout<UInt32>.size),
                &value
            )
        }

        private func applyConfiguration(
            _ ref: AudioConverterRef,
            _ configuration: LiveEncoderConfiguration
        ) {
            self.converter = ref
            self.configuration = configuration
            self.pcmBuffer = Data()
            self.currentTimestamp = 0.0
            self.framesEncoded = 0
        }

        private func disposeConverter() {
            if let ref = converter {
                AudioConverterDispose(ref)
                converter = nil
            }
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
                        "Expected \(config.channels) channels, "
                            + "got \(channels)"
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
                if let encoded = try encodeFrame(config: config) {
                    frames.append(encoded)
                }
            }

            return frames
        }

        private func encodeFrame(
            config: LiveEncoderConfiguration
        ) throws -> EncodedFrame? {
            guard let ref = converter else {
                throw LiveEncoderError.notConfigured
            }

            let bytesPerAACFrame =
                samplesPerFrame * 2 * config.channels
            var frameData = Data(
                pcmBuffer.prefix(bytesPerAACFrame)
            )
            pcmBuffer.removeFirst(bytesPerAACFrame)

            var bridge = AudioConverterBridge(
                converter: ref,
                channels: config.channels
            )
            guard let data = bridge.convert(input: &frameData)
            else {
                return nil
            }

            return makeEncodedFrame(data: data, config: config)
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
