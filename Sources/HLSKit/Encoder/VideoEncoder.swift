// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(VideoToolbox)

    import CoreMedia
    import CoreVideo
    import Foundation
    import os
    import VideoToolbox

    /// Real-time video encoder using Apple VideoToolbox.
    ///
    /// Converts raw YUV420p pixel buffers to H.264 or HEVC compressed
    /// frames using hardware-accelerated `VTCompressionSession`.
    ///
    /// ## Usage
    /// ```swift
    /// let encoder = VideoEncoder()
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
    ///
    /// ## Supported Codecs
    /// - H.264: Baseline, Main, High profiles
    /// - HEVC: Main, Main10 profiles
    public actor VideoEncoder: LiveEncoder {

        // MARK: - State

        private var session: VTCompressionSession?
        private var config: LiveEncoderConfiguration?
        private var isTornDown = false
        private var encodedCodec: EncodedCodec = .h264
        private var frameWidth = 0
        private var frameHeight = 0
        private var videoBitrateHint = 0
        private var frameDuration = 1.0 / 30.0

        /// Thread-safe accumulator for VT output callback.
        private let pendingFrames = OSAllocatedUnfairLock(
            initialState: [EncodedFrame]()
        )

        /// Creates a video encoder.
        public init() {}

        // MARK: - LiveEncoder

        public func configure(
            _ configuration: LiveEncoderConfiguration
        ) async throws {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            try validateConfiguration(configuration)
            disposeSession()
            let session = try createSession(for: configuration)
            try configureProperties(
                session, configuration: configuration
            )
            VTCompressionSessionPrepareToEncodeFrames(session)
            applyConfiguration(session, configuration)
        }

        public func encode(
            _ buffer: RawMediaBuffer
        ) async throws -> [EncodedFrame] {
            guard !isTornDown else {
                throw LiveEncoderError.tornDown
            }
            guard let session = session, config != nil else {
                throw LiveEncoderError.notConfigured
            }
            try validateBuffer(buffer)
            try encodeBuffer(buffer, session: session)
            return drainPendingFrames()
        }

        public func flush() async throws -> [EncodedFrame] {
            guard !isTornDown else { return [] }
            guard let session = session else { return [] }
            VTCompressionSessionCompleteFrames(
                session,
                untilPresentationTimeStamp: .invalid
            )
            return drainPendingFrames()
        }

        public func teardown() {
            disposeSession()
            config = nil
            isTornDown = true
            _ = drainPendingFrames()
        }
    }

    // MARK: - Configuration

    extension VideoEncoder {

        private func validateConfiguration(
            _ configuration: LiveEncoderConfiguration
        ) throws {
            guard let videoCodec = configuration.videoCodec else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "VideoEncoder requires videoCodec"
                )
            }
            guard videoCodec == .h264 || videoCodec == .h265 else {
                throw LiveEncoderError.unsupportedConfiguration(
                    "VideoEncoder supports H.264 and HEVC, "
                        + "got \(videoCodec.rawValue)"
                )
            }
        }

        private func createSession(
            for configuration: LiveEncoderConfiguration
        ) throws -> VTCompressionSession {
            let preset = configuration.qualityPreset ?? .p720
            let width = preset.resolution?.width ?? 1280
            let height = preset.resolution?.height ?? 720
            let codecType =
                configuration.videoCodec == .h265
                ? kCMVideoCodecType_HEVC
                : kCMVideoCodecType_H264

            var sessionRef: VTCompressionSession?
            let status = VTCompressionSessionCreate(
                allocator: kCFAllocatorDefault,
                width: Int32(width),
                height: Int32(height),
                codecType: codecType,
                encoderSpecification: nil,
                imageBufferAttributes: nil,
                compressedDataAllocator: nil,
                outputCallback: nil,
                refcon: nil,
                compressionSessionOut: &sessionRef
            )
            guard status == noErr, let session = sessionRef else {
                throw LiveEncoderError.encodingFailed(
                    "VTCompressionSessionCreate failed: \(status)"
                )
            }
            return session
        }

        private func configureProperties(
            _ session: VTCompressionSession,
            configuration: LiveEncoderConfiguration
        ) throws {
            let preset = configuration.qualityPreset ?? .p720
            let bitrate =
                configuration.videoBitrate
                ?? preset.videoBitrate ?? 2_800_000
            let keyframeInterval =
                configuration.keyframeInterval ?? 6.0
            let fps = preset.frameRate ?? 30.0
            let gopSize = Int(keyframeInterval * fps)

            setProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitrate as CFNumber)
            setProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: gopSize as CFNumber)
            setProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
            setProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

            if let level = profileLevel(
                for: configuration.videoCodec ?? .h264,
                profile: preset.videoProfile
            ) {
                setProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: level)
            }
        }

        private func applyConfiguration(
            _ session: VTCompressionSession,
            _ configuration: LiveEncoderConfiguration
        ) {
            let preset = configuration.qualityPreset ?? .p720
            self.session = session
            self.config = configuration
            self.encodedCodec =
                configuration.videoCodec == .h265
                ? .h265 : .h264
            self.frameWidth = preset.resolution?.width ?? 1280
            self.frameHeight = preset.resolution?.height ?? 720
            self.videoBitrateHint =
                configuration.videoBitrate
                ?? preset.videoBitrate ?? 2_800_000
            self.frameDuration = 1.0 / (preset.frameRate ?? 30.0)
        }

        private func setProperty(
            _ session: VTCompressionSession,
            key: CFString,
            value: CFTypeRef
        ) {
            VTSessionSetProperty(session, key: key, value: value)
        }

        private func disposeSession() {
            if let session = session {
                VTCompressionSessionInvalidate(session)
                self.session = nil
            }
        }
    }

    // MARK: - Encoding

    extension VideoEncoder {

        private func validateBuffer(
            _ buffer: RawMediaBuffer
        ) throws {
            guard
                buffer.mediaType == .video
                    || buffer.mediaType == .audioVideo
            else {
                throw LiveEncoderError.formatMismatch(
                    "Expected video buffer, "
                        + "got \(buffer.mediaType.rawValue)"
                )
            }
        }

        private func encodeBuffer(
            _ buffer: RawMediaBuffer,
            session: VTCompressionSession
        ) throws {
            let pixelBuffer = try createPixelBuffer(
                from: buffer.data,
                width: frameWidth,
                height: frameHeight
            )
            let pts = CMTime(
                seconds: buffer.timestamp.seconds,
                preferredTimescale: 90_000
            )
            let dur = CMTime(
                seconds: buffer.duration.seconds,
                preferredTimescale: 90_000
            )

            let codec = encodedCodec
            let bitrateHint = videoBitrateHint
            let accumulator = pendingFrames

            let status = VTCompressionSessionEncodeFrame(
                session,
                imageBuffer: pixelBuffer,
                presentationTimeStamp: pts,
                duration: dur,
                frameProperties: nil,
                infoFlagsOut: nil,
                outputHandler: { status, _, sampleBuffer in
                    guard status == noErr,
                        let sb = sampleBuffer
                    else { return }
                    if let frame = Self.extractFrame(
                        from: sb, codec: codec,
                        bitrateHint: bitrateHint
                    ) {
                        accumulator.withLock {
                            $0.append(frame)
                        }
                    }
                }
            )
            guard status == noErr else {
                throw LiveEncoderError.encodingFailed(
                    "VTCompressionSession encode failed: "
                        + "\(status)"
                )
            }
        }

        private func drainPendingFrames() -> [EncodedFrame] {
            pendingFrames.withLock { frames in
                let result = frames
                frames.removeAll()
                return result
            }
        }

        private static func extractFrame(
            from sampleBuffer: CMSampleBuffer,
            codec: EncodedCodec,
            bitrateHint: Int
        ) -> EncodedFrame? {
            guard
                let dataBuffer =
                    CMSampleBufferGetDataBuffer(sampleBuffer)
            else { return nil }

            let length = CMBlockBufferGetDataLength(dataBuffer)
            guard length > 0 else { return nil }

            var data = Data(count: length)
            let copyStatus = data.withUnsafeMutableBytes { ptr in
                guard let base = ptr.baseAddress else {
                    return OSStatus(-1)
                }
                return CMBlockBufferCopyDataBytes(
                    dataBuffer, atOffset: 0,
                    dataLength: length, destination: base
                )
            }
            guard copyStatus == noErr else { return nil }

            let pts = CMSampleBufferGetPresentationTimeStamp(
                sampleBuffer
            )
            let dur = CMSampleBufferGetDuration(sampleBuffer)
            let isKeyframe = detectKeyframe(sampleBuffer)

            return EncodedFrame(
                data: data,
                timestamp: MediaTimestamp(
                    seconds: CMTimeGetSeconds(pts)
                ),
                duration: MediaTimestamp(
                    seconds: CMTimeGetSeconds(dur)
                ),
                isKeyframe: isKeyframe,
                codec: codec,
                bitrateHint: bitrateHint
            )
        }

        private static func detectKeyframe(
            _ sampleBuffer: CMSampleBuffer
        ) -> Bool {
            let attachments =
                CMSampleBufferGetSampleAttachmentsArray(
                    sampleBuffer, createIfNecessary: false
                ) as? [[CFString: Any]]
            let notSync =
                attachments?.first?[
                    kCMSampleAttachmentKey_NotSync
                ] as? Bool
            return !(notSync ?? false)
        }
    }

#endif
