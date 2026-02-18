// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import AVFoundation
    import Testing

    @testable import HLSKit

    @Suite("EncodingSettings — Codec Mapping")
    struct EncodingSettingsMappingTests {

        // MARK: - Codec Type Mapping

        @Test("Codec type: h264 → .h264")
        func codecTypeH264() {
            #expect(
                EncodingSettings.avCodecType(for: .h264) == .h264
            )
        }

        @Test("Codec type: h265 → .hevc")
        func codecTypeH265() {
            #expect(
                EncodingSettings.avCodecType(for: .h265) == .hevc
            )
        }

        @Test("Codec type: vp9 falls back to .h264")
        func codecTypeVP9() {
            #expect(
                EncodingSettings.avCodecType(for: .vp9) == .h264
            )
        }

        @Test("Codec type: av1 falls back to .h264")
        func codecTypeAV1() {
            #expect(
                EncodingSettings.avCodecType(for: .av1) == .h264
            )
        }

        // MARK: - Audio Format Mapping

        @Test("Audio format: aac → MPEG4AAC")
        func audioFormatAAC() {
            #expect(
                EncodingSettings.audioFormatID(for: .aac)
                    == kAudioFormatMPEG4AAC
            )
        }

        @Test("Audio format: heAAC → MPEG4AAC_HE")
        func audioFormatHEAAC() {
            #expect(
                EncodingSettings.audioFormatID(for: .heAAC)
                    == kAudioFormatMPEG4AAC_HE
            )
        }

        @Test("Audio format: heAACv2 → MPEG4AAC_HE_V2")
        func audioFormatHEAACv2() {
            #expect(
                EncodingSettings.audioFormatID(for: .heAACv2)
                    == kAudioFormatMPEG4AAC_HE_V2
            )
        }

        @Test("Audio format: flac → FLAC")
        func audioFormatFLAC() {
            #expect(
                EncodingSettings.audioFormatID(for: .flac)
                    == kAudioFormatFLAC
            )
        }

        @Test("Audio format: opus → Opus")
        func audioFormatOpus() {
            #expect(
                EncodingSettings.audioFormatID(for: .opus)
                    == kAudioFormatOpus
            )
        }
    }

#endif
