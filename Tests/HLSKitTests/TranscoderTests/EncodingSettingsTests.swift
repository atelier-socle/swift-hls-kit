// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import AVFoundation
    import Testing

    @testable import HLSKit

    @Suite("EncodingSettings")
    struct EncodingSettingsTests {

        // MARK: - Video Settings

        @Test("Video settings for H.264 720p")
        func videoSettingsH264_720p() {
            let settings = EncodingSettings.videoSettings(
                preset: .p720,
                config: TranscodingConfig(),
                sourceResolution: nil
            )
            let codecType =
                settings[AVVideoCodecKey]
                as? AVVideoCodecType
            #expect(codecType == .h264)
            #expect(settings[AVVideoWidthKey] as? Int == 1280)
            #expect(settings[AVVideoHeightKey] as? Int == 720)

            let compression =
                settings[
                    AVVideoCompressionPropertiesKey
                ] as? [String: Any]
            #expect(compression != nil)
            let bitrate =
                compression?[AVVideoAverageBitRateKey]
                as? Int
            #expect(bitrate == 2_800_000)
        }

        @Test("Video settings for H.265 1080p")
        func videoSettingsH265_1080p() {
            let config = TranscodingConfig(videoCodec: .h265)
            let settings = EncodingSettings.videoSettings(
                preset: .p1080,
                config: config,
                sourceResolution: nil
            )
            let codecType =
                settings[AVVideoCodecKey]
                as? AVVideoCodecType
            #expect(codecType == .hevc)
            #expect(settings[AVVideoWidthKey] as? Int == 1920)
            #expect(settings[AVVideoHeightKey] as? Int == 1080)
        }

        @Test("Video settings for 360p baseline profile")
        func videoSettings360pBaseline() {
            let settings = EncodingSettings.videoSettings(
                preset: .p360,
                config: TranscodingConfig(),
                sourceResolution: nil
            )
            let compression =
                settings[
                    AVVideoCompressionPropertiesKey
                ] as? [String: Any]
            let profile =
                compression?[AVVideoProfileLevelKey]
                as? String
            #expect(
                profile == AVVideoProfileLevelH264Baseline30
            )
        }

        @Test("Video settings use source resolution fallback")
        func videoSettingsSourceFallback() {
            let preset = QualityPreset(
                name: "test",
                resolution: nil,
                videoBitrate: 1_000_000,
                videoProfile: nil
            )
            let sourceRes = Resolution(width: 854, height: 480)
            let settings = EncodingSettings.videoSettings(
                preset: preset,
                config: TranscodingConfig(),
                sourceResolution: sourceRes
            )
            #expect(settings[AVVideoWidthKey] as? Int == 854)
            #expect(settings[AVVideoHeightKey] as? Int == 480)
        }

        @Test("Video settings with frame rate")
        func videoSettingsFrameRate() {
            let preset = QualityPreset(
                name: "test",
                resolution: .p720,
                videoBitrate: 2_800_000,
                videoProfile: .high,
                frameRate: 30.0
            )
            let settings = EncodingSettings.videoSettings(
                preset: preset,
                config: TranscodingConfig(),
                sourceResolution: nil
            )
            let compression =
                settings[
                    AVVideoCompressionPropertiesKey
                ] as? [String: Any]
            let fps =
                compression?[
                    AVVideoExpectedSourceFrameRateKey
                ] as? Double
            #expect(fps == 30.0)
        }

        @Test("Video settings clamp bitrate to max")
        func videoSettingsMaxBitrate() {
            let settings = EncodingSettings.videoSettings(
                preset: .p720,
                config: TranscodingConfig(),
                sourceResolution: nil
            )
            let compression =
                settings[
                    AVVideoCompressionPropertiesKey
                ] as? [String: Any]
            let bitrate =
                compression?[AVVideoAverageBitRateKey]
                as? Int
            #expect(bitrate == 2_800_000)
        }

        // MARK: - Audio Settings

        @Test("Audio settings for AAC 128k stereo")
        func audioSettingsAAC() {
            let settings = EncodingSettings.audioSettings(
                preset: .p720,
                config: TranscodingConfig(audioPassthrough: false)
            )
            #expect(settings != nil)
            let formatID = settings?[AVFormatIDKey] as? AudioFormatID
            #expect(formatID == kAudioFormatMPEG4AAC)
            let sampleRate = settings?[AVSampleRateKey] as? Int
            #expect(sampleRate == 44_100)
            let channels = settings?[AVNumberOfChannelsKey] as? Int
            #expect(channels == 2)
            let bitrate = settings?[AVEncoderBitRateKey] as? Int
            #expect(bitrate == 128_000)
        }

        @Test("Audio settings nil for passthrough")
        func audioSettingsPassthrough() {
            let settings = EncodingSettings.audioSettings(
                preset: .p720,
                config: TranscodingConfig(audioPassthrough: true)
            )
            #expect(settings == nil)
        }

        // MARK: - Reader Settings

        @Test("Video reader settings decode to YCbCr")
        func videoReaderSettings() {
            let settings = EncodingSettings.videoReaderSettings()
            let format =
                settings[
                    kCVPixelBufferPixelFormatTypeKey as String
                ] as? OSType
            #expect(
                format
                    == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
            )
        }

        @Test("Audio reader settings decode to PCM")
        func audioReaderSettingsPCM() {
            let settings = EncodingSettings.audioReaderSettings(
                passthrough: false
            )
            #expect(settings != nil)
            let formatID = settings?[AVFormatIDKey] as? AudioFormatID
            #expect(formatID == kAudioFormatLinearPCM)
            let bitDepth = settings?[AVLinearPCMBitDepthKey] as? Int
            #expect(bitDepth == 16)
        }

        @Test("Audio reader settings nil for passthrough")
        func audioReaderSettingsPassthrough() {
            let settings = EncodingSettings.audioReaderSettings(
                passthrough: true
            )
            #expect(settings == nil)
        }

        // MARK: - Profile Level Mapping

        @Test("Profile level: H.264 baseline 3.0")
        func profileBaseline30() {
            let result = EncodingSettings.avProfileLevel(
                profile: .baseline, level: "3.0", codec: .h264
            )
            #expect(result == AVVideoProfileLevelH264Baseline30)
        }

        @Test("Profile level: H.264 baseline 3.1")
        func profileBaseline31() {
            let result = EncodingSettings.avProfileLevel(
                profile: .baseline, level: "3.1", codec: .h264
            )
            #expect(result == AVVideoProfileLevelH264Baseline31)
        }

        @Test("Profile level: H.264 baseline auto")
        func profileBaselineAuto() {
            let result = EncodingSettings.avProfileLevel(
                profile: .baseline, level: "4.0", codec: .h264
            )
            #expect(
                result == AVVideoProfileLevelH264BaselineAutoLevel
            )
        }

        @Test("Profile level: H.264 main 3.1")
        func profileMain31() {
            let result = EncodingSettings.avProfileLevel(
                profile: .main, level: "3.1", codec: .h264
            )
            #expect(result == AVVideoProfileLevelH264Main31)
        }

        @Test("Profile level: H.264 main auto")
        func profileMainAuto() {
            let result = EncodingSettings.avProfileLevel(
                profile: .main, level: nil, codec: .h264
            )
            #expect(
                result == AVVideoProfileLevelH264MainAutoLevel
            )
        }

        @Test("Profile level: H.264 high 4.0")
        func profileHigh40() {
            let result = EncodingSettings.avProfileLevel(
                profile: .high, level: "4.0", codec: .h264
            )
            #expect(result == AVVideoProfileLevelH264High40)
        }

        @Test("Profile level: H.264 high 4.1")
        func profileHigh41() {
            let result = EncodingSettings.avProfileLevel(
                profile: .high, level: "4.1", codec: .h264
            )
            #expect(result == AVVideoProfileLevelH264High41)
        }

        @Test("Profile level: H.264 high auto (default)")
        func profileHighAuto() {
            let result = EncodingSettings.avProfileLevel(
                profile: .high, level: "5.1", codec: .h264
            )
            #expect(
                result == AVVideoProfileLevelH264HighAutoLevel
            )
        }

        @Test("Profile level: nil profile defaults to high auto")
        func profileNilDefault() {
            let result = EncodingSettings.avProfileLevel(
                profile: nil, level: nil, codec: .h264
            )
            #expect(
                result == AVVideoProfileLevelH264HighAutoLevel
            )
        }

        @Test("Profile level: non-H.264 codec defaults to high auto")
        func profileNonH264() {
            let result = EncodingSettings.avProfileLevel(
                profile: .high, level: "4.0", codec: .h265
            )
            #expect(
                result == AVVideoProfileLevelH264HighAutoLevel
            )
        }

    }

#endif
