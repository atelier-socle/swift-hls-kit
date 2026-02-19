// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Quality Presets

@Suite("Transcoding Showcase — Quality Presets")
struct QualityPresetShowcase {

    @Test("QualityPreset — all standard presets: p360, p480, p720, p1080, p2160")
    func standardPresets() {
        let presets: [QualityPreset] = [.p360, .p480, .p720, .p1080, .p2160]
        #expect(presets.count == 5)
        for preset in presets {
            #expect(preset.resolution != nil)
            #expect(preset.videoBitrate != nil)
        }
    }

    @Test("QualityPreset.audioOnly — audio-only preset for podcast/radio")
    func audioOnlyPreset() {
        let preset = QualityPreset.audioOnly
        #expect(preset.isAudioOnly == true)
        #expect(preset.resolution == nil)
        #expect(preset.videoBitrate == nil)
        #expect(preset.audioBitrate > 0)
    }

    @Test("QualityPreset.standardLadder — [p360, p480, p720, p1080]")
    func standardLadder() {
        let ladder = QualityPreset.standardLadder
        #expect(ladder.count == 4)
        #expect(ladder[0].name == QualityPreset.p360.name)
        #expect(ladder[3].name == QualityPreset.p1080.name)
    }

    @Test("QualityPreset.fullLadder — includes p2160")
    func fullLadder() {
        let ladder = QualityPreset.fullLadder
        #expect(ladder.count == 5)
        #expect(ladder.last?.name == QualityPreset.p2160.name)
    }

    @Test("QualityPreset — resolution, bitrate, codec profile for each")
    func presetDetails() {
        let p720 = QualityPreset.p720
        #expect(p720.resolution == .p720)
        #expect(p720.videoBitrate == 2_800_000)
        #expect(p720.videoProfile == .high)
        #expect(p720.totalBandwidth > 0)
    }

    @Test("QualityPreset — codecsString generation")
    func codecsString() {
        let p720 = QualityPreset.p720
        let codecs = p720.codecsString()
        #expect(codecs.contains("avc1"))
        #expect(codecs.contains("mp4a"))
    }

    @Test("TranscodingConfig — codec, container, segment duration defaults")
    func transcodingConfigDefaults() {
        let config = TranscodingConfig()
        #expect(config.videoCodec == .h264)
        #expect(config.audioCodec == .aac)
        #expect(config.containerFormat == .fragmentedMP4)
        #expect(config.segmentDuration == 6.0)
        #expect(config.generatePlaylist == true)
        #expect(config.audioPassthrough == true)
        #expect(config.hardwareAcceleration == true)
    }

    @Test("TranscodingConfig — all video codecs")
    func videoCodecs() {
        #expect(VideoCodec.h264.rawValue == "h264")
        #expect(VideoCodec.h265.rawValue == "h265")
        #expect(VideoCodec.vp9.rawValue == "vp9")
        #expect(VideoCodec.av1.rawValue == "av1")
    }

    @Test("TranscodingConfig — all audio codecs")
    func audioCodecs() {
        #expect(AudioCodec.aac.rawValue == "aac")
        #expect(AudioCodec.heAAC.rawValue == "heAAC")
        #expect(AudioCodec.opus.rawValue == "opus")
    }

    @Test("TranscodingResult — output metadata with speed factor")
    func transcodingResult() {
        let result = TranscodingResult(
            preset: .p720,
            outputDirectory: URL(fileURLWithPath: "/tmp/out"),
            transcodingDuration: 5.0,
            sourceDuration: 10.0,
            outputSize: 1_000_000
        )
        #expect(result.speedFactor == 2.0)
        #expect(result.outputSize == 1_000_000)
        #expect(result.preset.name == QualityPreset.p720.name)
    }

    @Test("MultiVariantResult — aggregated output stats")
    func multiVariantResult() {
        let results = [
            TranscodingResult(
                preset: .p360,
                outputDirectory: URL(fileURLWithPath: "/tmp/out/360"),
                transcodingDuration: 3.0,
                sourceDuration: 10.0,
                outputSize: 500_000
            ),
            TranscodingResult(
                preset: .p720,
                outputDirectory: URL(fileURLWithPath: "/tmp/out/720"),
                transcodingDuration: 5.0,
                sourceDuration: 10.0,
                outputSize: 1_000_000
            )
        ]
        let multi = MultiVariantResult(
            variants: results,
            masterPlaylist: nil,
            outputDirectory: URL(fileURLWithPath: "/tmp/out")
        )
        #expect(multi.variants.count == 2)
        #expect(multi.totalTranscodingDuration == 8.0)
        #expect(multi.totalOutputSize == 1_500_000)
    }
}

// MARK: - Transcoder Protocol

@Suite("Transcoding Showcase — Protocol & Availability")
struct TranscoderProtocolShowcase {

    @Test("Transcoder.isAvailable — check if Apple transcoder is available")
    func appleAvailability() {
        #if canImport(AVFoundation)
            #expect(AppleTranscoder.isAvailable == true)
        #endif
    }

    @Test("Transcoder.name — human-readable transcoder name")
    func transcoderNames() {
        #if canImport(AVFoundation)
            #expect(AppleTranscoder.name == "Apple VideoToolbox")
        #endif
    }

    @Test("VariantPlaylistBuilder — master M3U8 from quality presets")
    func variantPlaylistBuilder() {
        let builder = VariantPlaylistBuilder()
        let presets: [QualityPreset] = [.p360, .p720, .p1080]
        let config = TranscodingConfig()
        let m3u8 = builder.buildMasterPlaylist(
            presets: presets,
            videoCodec: config.videoCodec,
            config: config
        )
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("BANDWIDTH="))
        #expect(m3u8.contains("RESOLUTION="))
    }
}

// MARK: - Video Profile

@Suite("Transcoding Showcase — VideoProfile")
struct VideoProfileShowcase {

    @Test("VideoProfile — baseline, main, high for H.264")
    func h264Profiles() {
        #expect(VideoProfile.baseline.rawValue == "baseline")
        #expect(VideoProfile.main.rawValue == "main")
        #expect(VideoProfile.high.rawValue == "high")
    }

    @Test("VideoProfile — main, main10 for H.265/HEVC")
    func hevcProfiles() {
        #expect(VideoProfile.mainHEVC.rawValue == "main-hevc")
        #expect(VideoProfile.main10HEVC.rawValue == "main10-hevc")
    }
}

// MARK: - Apple Transcoding (API surface only — no real transcoding)

#if canImport(AVFoundation)
    @Suite("Transcoding Showcase — Apple (VideoToolbox)")
    struct AppleTranscodingShowcase {

        @Test("AppleTranscoder — instantiation and availability")
        func instantiation() {
            let transcoder = AppleTranscoder()
            #expect(AppleTranscoder.isAvailable == true)
            _ = transcoder
        }

        @Test("AppleTranscoder — static name property")
        func staticName() {
            #expect(AppleTranscoder.name == "Apple VideoToolbox")
        }
    }
#endif

// MARK: - FFmpeg Transcoding (Phase 5)

@Suite("Transcoding Showcase — FFmpeg")
struct FFmpegTranscodingShowcase {

    @Test("FFmpegTranscoder — availability check")
    func ffmpegAvailability() throws {
        try #require(FFmpegTranscoder.isAvailable, "Skip: ffmpeg not installed")
        #expect(FFmpegTranscoder.isAvailable == true)
    }

    @Test("FFmpegTranscoder — name")
    func ffmpegName() {
        #expect(FFmpegTranscoder.name == "FFmpeg")
    }
}
