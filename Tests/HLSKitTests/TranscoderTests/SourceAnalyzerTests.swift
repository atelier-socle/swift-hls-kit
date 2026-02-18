// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("SourceAnalyzer")
    struct SourceAnalyzerTests {

        // MARK: - Analyze Error Paths

        @Test("Analyze non-existent file throws sourceNotFound")
        func analyzeNonExistent() async {
            await #expect(throws: TranscodingError.self) {
                _ = try await SourceAnalyzer.analyze(
                    URL(fileURLWithPath: "/nonexistent/file.mp4")
                )
            }
        }

        // MARK: - Effective Preset

        @Test("Don't upscale: source 720p, preset 1080p → 720p")
        func effectivePresetNoUpscale() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: .p720,
                videoFrameRate: 30.0,
                videoBitrate: 2_800_000,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .p1080, source: source
            )
            #expect(effective.resolution == .p720)
            #expect(effective.name == "1080p")
        }

        @Test("Downscale when preset is smaller than source")
        func effectivePresetDownscale() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: .p1080,
                videoFrameRate: 30.0,
                videoBitrate: 5_000_000,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .p480, source: source
            )
            #expect(effective.resolution == .p480)
        }

        @Test("Audio-only preset unchanged")
        func effectivePresetAudioOnly() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 120.0,
                hasVideo: false,
                hasAudio: true,
                videoResolution: nil,
                videoFrameRate: nil,
                videoBitrate: nil,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .audioOnly, source: source
            )
            #expect(effective.isAudioOnly)
            #expect(effective.resolution == nil)
        }

        @Test("Nil source resolution keeps preset")
        func effectivePresetNilSourceResolution() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: nil,
                videoFrameRate: nil,
                videoBitrate: nil,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .p1080, source: source
            )
            #expect(effective.resolution == .p1080)
        }

        @Test("No-upscale uses min bitrate from source and preset")
        func effectivePresetMinBitrate() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: .p720,
                videoFrameRate: 30.0,
                videoBitrate: 2_000_000,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .p1080, source: source
            )
            #expect(effective.videoBitrate == 2_000_000)
        }

        @Test("No-upscale with nil source bitrate keeps preset bitrate")
        func effectivePresetNilSourceBitrate() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: .p720,
                videoFrameRate: 30.0,
                videoBitrate: nil,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .p1080, source: source
            )
            #expect(effective.videoBitrate == 5_000_000)
        }

        @Test("Same resolution preset unchanged")
        func effectivePresetSameResolution() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: .p720,
                videoFrameRate: 30.0,
                videoBitrate: 2_800_000,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .p720, source: source
            )
            #expect(effective.resolution == .p720)
            #expect(effective.videoBitrate == 2_800_000)
        }

        @Test("No-upscale preserves non-resolution preset fields")
        func effectivePresetPreservesFields() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: .p720,
                videoFrameRate: 30.0,
                videoBitrate: 2_000_000,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .p1080, source: source
            )
            #expect(effective.audioBitrate == 128_000)
            #expect(effective.audioSampleRate == 44_100)
            #expect(effective.audioChannels == 2)
        }

        @Test("Nil preset resolution returns preset unchanged")
        func effectivePresetNilPresetResolution() {
            let source = SourceAnalyzer.SourceInfo(
                duration: 30.0,
                hasVideo: true,
                hasAudio: true,
                videoResolution: .p1080,
                videoFrameRate: 30.0,
                videoBitrate: 5_000_000,
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = SourceAnalyzer.effectivePreset(
                .audioOnly, source: source
            )
            #expect(effective.isAudioOnly)
        }
    }

#endif
