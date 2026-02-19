// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("FFmpeg Coverage — Command Builder")
    struct FFmpegCodecCoverageTests {

        private let builder = FFmpegCommandBuilder()

        // MARK: - All Built-in Presets

        @Test("Command builder: all standard presets produce args")
        func allPresets() {
            let presets: [QualityPreset] = [
                .p360, .p480, .p720, .p1080, .p2160, .audioOnly
            ]
            for preset in presets {
                let args = builder.buildTranscodeArguments(
                    input: "/in.mp4",
                    output: "/out.mp4",
                    preset: preset,
                    config: TranscodingConfig(
                        audioPassthrough: false
                    )
                )
                #expect(!args.isEmpty)
                #expect(args.first == "-i")
                #expect(args.last == "/out.mp4")
            }
        }

        // MARK: - Video Codec Variants

        @Test("VP9 codec generates libvpx-vp9")
        func vp9Codec() {
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: .p720,
                config: TranscodingConfig(videoCodec: .vp9)
            )
            #expect(args.contains("libvpx-vp9"))
        }

        @Test("AV1 codec generates libsvtav1")
        func av1Codec() {
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: .p720,
                config: TranscodingConfig(videoCodec: .av1)
            )
            #expect(args.contains("libsvtav1"))
        }

        // MARK: - Video Profile Variants

        @Test("Baseline profile maps to ffmpeg baseline")
        func baselineProfile() {
            let preset = QualityPreset(
                name: "test",
                resolution: .p360,
                videoBitrate: 800_000,
                videoProfile: .baseline
            )
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: preset,
                config: TranscodingConfig()
            )
            #expect(args.contains("baseline"))
        }

        @Test("Main profile maps to ffmpeg main")
        func mainProfile() {
            let preset = QualityPreset(
                name: "test",
                resolution: .p480,
                videoBitrate: 1_400_000,
                videoProfile: .main
            )
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: preset,
                config: TranscodingConfig()
            )
            let profileIdx = args.firstIndex(of: "-profile:v")
            #expect(profileIdx != nil)
        }

        @Test("HEVC main profile maps correctly")
        func hevcMainProfile() {
            let preset = QualityPreset(
                name: "test",
                resolution: .p720,
                videoBitrate: 2_800_000,
                videoProfile: .mainHEVC
            )
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: preset,
                config: TranscodingConfig(videoCodec: .h265)
            )
            #expect(args.contains("-profile:v"))
        }

        @Test("HEVC main10 profile maps correctly")
        func hevcMain10Profile() {
            let preset = QualityPreset(
                name: "test",
                resolution: .p720,
                videoBitrate: 2_800_000,
                videoProfile: .main10HEVC
            )
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: preset,
                config: TranscodingConfig(videoCodec: .h265)
            )
            #expect(args.contains("main10"))
        }

        // MARK: - Audio Codec Variants

        @Test("HE-AAC codec generates libfdk_aac with aac_he")
        func heAACCodec() {
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: .audioOnly,
                config: TranscodingConfig(
                    audioCodec: .heAAC,
                    audioPassthrough: false
                )
            )
            #expect(args.contains("libfdk_aac"))
            #expect(args.contains("aac_he"))
        }

        @Test("HE-AACv2 codec generates correct args")
        func heAACv2Codec() {
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: .audioOnly,
                config: TranscodingConfig(
                    audioCodec: .heAACv2,
                    audioPassthrough: false
                )
            )
            #expect(args.contains("libfdk_aac"))
            #expect(args.contains("aac_he_v2"))
        }

        @Test("FLAC codec generates correct arg")
        func flacCodec() {
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: .audioOnly,
                config: TranscodingConfig(
                    audioCodec: .flac,
                    audioPassthrough: false
                )
            )
            #expect(args.contains("flac"))
        }

        @Test("Opus codec generates libopus")
        func opusCodec() {
            let args = builder.buildTranscodeArguments(
                input: "/in.mp4",
                output: "/out.mp4",
                preset: .audioOnly,
                config: TranscodingConfig(
                    audioCodec: .opus,
                    audioPassthrough: false
                )
            )
            #expect(args.contains("libopus"))
        }
    }

#endif
