// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - HiResAudioConfig

@Suite("HiResAudioConfig — Sample Rate Tiers")
struct HiResSampleRateTests {

    @Test(
        "All sample rate tiers have correct raw values",
        arguments: zip(
            HiResAudioConfig.SampleRateTier.allCases,
            [44100.0, 48000.0, 88200.0, 96000.0, 176400.0, 192000.0]
        )
    )
    func sampleRateValues(tier: HiResAudioConfig.SampleRateTier, expected: Double) {
        #expect(tier.rawValue == expected)
    }

    @Test("Rates > 48kHz are Hi-Res")
    func hiResRates() {
        #expect(HiResAudioConfig.SampleRateTier.rate88_2kHz.isHiRes == true)
        #expect(HiResAudioConfig.SampleRateTier.rate96kHz.isHiRes == true)
        #expect(HiResAudioConfig.SampleRateTier.rate192kHz.isHiRes == true)
    }

    @Test("Rates <= 48kHz are not Hi-Res")
    func nonHiResRates() {
        #expect(HiResAudioConfig.SampleRateTier.rate44_1kHz.isHiRes == false)
        #expect(HiResAudioConfig.SampleRateTier.rate48kHz.isHiRes == false)
    }

    @Test("SampleRateTier is Comparable")
    func comparable() {
        #expect(
            HiResAudioConfig.SampleRateTier.rate44_1kHz
                < HiResAudioConfig.SampleRateTier.rate96kHz
        )
        #expect(
            HiResAudioConfig.SampleRateTier.rate192kHz
                > HiResAudioConfig.SampleRateTier.rate48kHz
        )
    }
}

@Suite("HiResAudioConfig — Bit Depth")
struct HiResBitDepthTests {

    @Test("All bit depths have correct raw values")
    func bitDepthValues() {
        #expect(HiResAudioConfig.BitDepth.depth16.rawValue == 16)
        #expect(HiResAudioConfig.BitDepth.depth24.rawValue == 24)
        #expect(HiResAudioConfig.BitDepth.depth32.rawValue == 32)
    }

    @Test("Depths > 16 are Hi-Res")
    func hiResDepths() {
        #expect(HiResAudioConfig.BitDepth.depth24.isHiRes == true)
        #expect(HiResAudioConfig.BitDepth.depth32.isHiRes == true)
    }

    @Test("16-bit is not Hi-Res")
    func depth16NotHiRes() {
        #expect(HiResAudioConfig.BitDepth.depth16.isHiRes == false)
    }

    @Test("BitDepth is Comparable")
    func comparable() {
        #expect(
            HiResAudioConfig.BitDepth.depth16
                < HiResAudioConfig.BitDepth.depth24
        )
    }
}

@Suite("HiResAudioConfig — Codecs")
struct HiResCodecTests {

    @Test("ALAC codec string")
    func alacCodec() {
        let config = HiResAudioConfig(codec: .alac)
        #expect(config.hlsCodecString == "alac")
    }

    @Test("FLAC codec string")
    func flacCodec() {
        let config = HiResAudioConfig(codec: .flac)
        #expect(config.hlsCodecString == "fLaC")
    }

    @Test("HE-AAC codec string")
    func aacHECodec() {
        let config = HiResAudioConfig(codec: .aacHE)
        #expect(config.hlsCodecString == "mp4a.40.5")
    }

    @Test("AAC-LC codec string")
    func aacLCCodec() {
        let config = HiResAudioConfig(codec: .aacLC)
        #expect(config.hlsCodecString == "mp4a.40.2")
    }

    @Test("HiResCodec is CaseIterable with 4 cases")
    func caseIterable() {
        #expect(HiResAudioConfig.HiResCodec.allCases.count == 4)
    }
}

@Suite("HiResAudioConfig — Properties")
struct HiResConfigPropertyTests {

    @Test("isHiRes true for rate > 48kHz")
    func isHiResRate() {
        let config = HiResAudioConfig(
            sampleRate: .rate96kHz,
            bitDepth: .depth16,
            codec: .alac
        )
        #expect(config.isHiRes == true)
    }

    @Test("isHiRes true for depth > 16")
    func isHiResDepth() {
        let config = HiResAudioConfig(
            sampleRate: .rate44_1kHz,
            bitDepth: .depth24,
            codec: .alac
        )
        #expect(config.isHiRes == true)
    }

    @Test("isHiRes false for CD quality")
    func isNotHiRes() {
        let config = HiResAudioConfig(
            sampleRate: .rate44_1kHz,
            bitDepth: .depth16,
            codec: .alac
        )
        #expect(config.isHiRes == false)
    }

    @Test("Estimated bitrate for lossless is positive")
    func estimatedBitrateLossless() {
        let config = HiResAudioConfig.studioHiRes
        #expect(config.estimatedBitrate > 0)
    }

    @Test("Estimated bitrate for lossy AAC-LC")
    func estimatedBitrateAAC() {
        let config = HiResAudioConfig(codec: .aacLC)
        #expect(config.estimatedBitrate > 0)
    }

    @Test("Estimated bitrate for HE-AAC at Hi-Res rate")
    func estimatedBitrateHEAAC() {
        let config = HiResAudioConfig(
            sampleRate: .rate96kHz,
            codec: .aacHE
        )
        #expect(config.estimatedBitrate == 128_000)
    }

    @Test("Estimated bitrate for HE-AAC at standard rate")
    func estimatedBitrateHEAACStandard() {
        let config = HiResAudioConfig(
            sampleRate: .rate48kHz,
            codec: .aacHE
        )
        #expect(config.estimatedBitrate == 64_000)
    }

    @Test("Default generateAACFallback is true")
    func defaultFallback() {
        let config = HiResAudioConfig()
        #expect(config.generateAACFallback == true)
    }

    @Test("Default aacFallbackBitrate is 256k")
    func defaultFallbackBitrate() {
        let config = HiResAudioConfig()
        #expect(config.aacFallbackBitrate == 256_000)
    }
}

@Suite("HiResAudioConfig — Presets")
struct HiResPresetTests {

    @Test("cdQuality preset")
    func cdQuality() {
        let config = HiResAudioConfig.cdQuality
        #expect(config.sampleRate == .rate44_1kHz)
        #expect(config.bitDepth == .depth16)
        #expect(config.codec == .alac)
        #expect(config.isHiRes == false)
    }

    @Test("studioHiRes preset")
    func studioHiRes() {
        let config = HiResAudioConfig.studioHiRes
        #expect(config.sampleRate == .rate96kHz)
        #expect(config.bitDepth == .depth24)
        #expect(config.codec == .alac)
        #expect(config.isHiRes == true)
    }

    @Test("masterHiRes preset")
    func masterHiRes() {
        let config = HiResAudioConfig.masterHiRes
        #expect(config.sampleRate == .rate192kHz)
        #expect(config.bitDepth == .depth24)
        #expect(config.codec == .flac)
    }

    @Test("audiophile preset")
    func audiophile() {
        let config = HiResAudioConfig.audiophile
        #expect(config.sampleRate == .rate192kHz)
        #expect(config.bitDepth == .depth32)
        #expect(config.codec == .flac)
    }
}

@Suite("HiResAudioConfig — Conformances")
struct HiResConformanceTests {

    @Test("Equatable conformance")
    func equatable() {
        #expect(HiResAudioConfig.studioHiRes == HiResAudioConfig.studioHiRes)
        #expect(HiResAudioConfig.cdQuality != HiResAudioConfig.audiophile)
    }

    @Test("Hashable conformance")
    func hashable() {
        let set: Set<HiResAudioConfig> = [.cdQuality, .studioHiRes, .audiophile]
        #expect(set.count == 3)
    }
}
