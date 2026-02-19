// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    import AVFoundation

    /// Builds AVFoundation encoding settings from HLSKit configuration types.
    ///
    /// Maps ``QualityPreset`` and ``TranscodingConfig`` to the dictionaries
    /// expected by `AVAssetWriterInput` and `AVAssetReaderTrackOutput`.
    ///
    /// - SeeAlso: ``AppleTranscoder``, ``QualityPreset``
    struct EncodingSettings: Sendable {

        // MARK: - Writer Settings

        /// Build video encoding settings for `AVAssetWriterInput`.
        ///
        /// - Parameters:
        ///   - preset: Quality preset defining resolution and bitrate.
        ///   - config: Transcoding configuration.
        ///   - sourceResolution: Source video resolution for fallback.
        /// - Returns: Video settings dictionary.
        static func videoSettings(
            preset: QualityPreset,
            config: TranscodingConfig,
            sourceResolution: Resolution?
        ) -> [String: Any] {
            let resolution =
                preset.resolution
                ?? sourceResolution
                ?? Resolution(width: 1280, height: 720)
            let bitrate = preset.videoBitrate ?? 2_800_000
            let codecType = avCodecType(for: config.videoCodec)

            var compressionProperties: [String: Any] = [
                AVVideoAverageBitRateKey: bitrate,
                AVVideoMaxKeyFrameIntervalDurationKey:
                    preset.keyFrameInterval,
                AVVideoAllowFrameReorderingKey: true
            ]

            if let maxBitrate = preset.maxVideoBitrate {
                compressionProperties[
                    AVVideoAverageBitRateKey
                ] = min(bitrate, maxBitrate)
            }

            if config.videoCodec == .h264 {
                let profileLevel = avProfileLevel(
                    profile: preset.videoProfile,
                    level: preset.videoLevel,
                    codec: config.videoCodec
                )
                compressionProperties[
                    AVVideoProfileLevelKey
                ] = profileLevel
            }

            if let frameRate = preset.frameRate {
                compressionProperties[
                    AVVideoExpectedSourceFrameRateKey
                ] = frameRate
            }

            return [
                AVVideoCodecKey: codecType,
                AVVideoWidthKey: resolution.width,
                AVVideoHeightKey: resolution.height,
                AVVideoCompressionPropertiesKey: compressionProperties
            ]
        }

        /// Build audio encoding settings for `AVAssetWriterInput`.
        ///
        /// Returns `nil` when audio passthrough is enabled, since
        /// passthrough feeds compressed samples directly.
        ///
        /// - Parameters:
        ///   - preset: Quality preset defining audio parameters.
        ///   - config: Transcoding configuration.
        /// - Returns: Audio settings dictionary, or `nil` for passthrough.
        static func audioSettings(
            preset: QualityPreset,
            config: TranscodingConfig
        ) -> [String: Any]? {
            guard !config.audioPassthrough else { return nil }

            let formatID = audioFormatID(for: config.audioCodec)
            return [
                AVFormatIDKey: formatID,
                AVSampleRateKey: preset.audioSampleRate,
                AVNumberOfChannelsKey: preset.audioChannels,
                AVEncoderBitRateKey: preset.audioBitrate
            ]
        }

        // MARK: - Reader Settings

        /// Build video reader output settings (decode to raw pixels).
        ///
        /// - Returns: Video output settings for `AVAssetReaderTrackOutput`.
        static func videoReaderSettings() -> [String: Any] {
            [
                kCVPixelBufferPixelFormatTypeKey as String:
                    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            ]
        }

        /// Build audio reader output settings.
        ///
        /// Returns `nil` for passthrough mode, which causes
        /// `AVAssetReaderTrackOutput` to output compressed samples.
        ///
        /// - Parameter passthrough: Whether audio passthrough is enabled.
        /// - Returns: Audio output settings, or `nil` for passthrough.
        static func audioReaderSettings(
            passthrough: Bool
        ) -> [String: Any]? {
            guard !passthrough else { return nil }

            return [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ]
        }

        // MARK: - Codec Mapping

        /// Map ``VideoCodec`` to `AVVideoCodecType`.
        ///
        /// - Parameter codec: The HLSKit video codec.
        /// - Returns: The corresponding AVFoundation codec type.
        static func avCodecType(
            for codec: VideoCodec
        ) -> AVVideoCodecType {
            switch codec {
            case .h264:
                return .h264
            case .h265:
                return .hevc
            case .vp9:
                return .h264
            case .av1:
                return .h264
            }
        }

        /// Map ``VideoProfile`` and level to an AVFoundation profile
        /// level string.
        ///
        /// - Parameters:
        ///   - profile: Video codec profile.
        ///   - level: Video codec level string.
        ///   - codec: Video codec type.
        /// - Returns: AVFoundation profile level constant.
        static func avProfileLevel(
            profile: VideoProfile?,
            level: String?,
            codec: VideoCodec
        ) -> String {
            guard codec == .h264 else {
                return AVVideoProfileLevelH264HighAutoLevel
            }

            switch (profile, level) {
            case (.baseline, "3.0"):
                return AVVideoProfileLevelH264Baseline30
            case (.baseline, "3.1"):
                return AVVideoProfileLevelH264Baseline31
            case (.baseline, _):
                return AVVideoProfileLevelH264BaselineAutoLevel
            case (.main, "3.1"):
                return AVVideoProfileLevelH264Main31
            case (.main, _):
                return AVVideoProfileLevelH264MainAutoLevel
            case (.high, "4.0"):
                return AVVideoProfileLevelH264High40
            case (.high, "4.1"):
                return AVVideoProfileLevelH264High41
            case (.high, _):
                return AVVideoProfileLevelH264HighAutoLevel
            default:
                return AVVideoProfileLevelH264HighAutoLevel
            }
        }

        /// Map ``AudioCodec`` to Core Audio `AudioFormatID`.
        ///
        /// - Parameter codec: The HLSKit audio codec.
        /// - Returns: The corresponding Core Audio format ID.
        static func audioFormatID(
            for codec: AudioCodec
        ) -> AudioFormatID {
            switch codec {
            case .aac:
                return kAudioFormatMPEG4AAC
            case .heAAC:
                return kAudioFormatMPEG4AAC_HE
            case .heAACv2:
                return kAudioFormatMPEG4AAC_HE_V2
            case .flac:
                return kAudioFormatFLAC
            case .opus:
                return kAudioFormatOpus
            }
        }
    }

#endif
