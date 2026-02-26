// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - SpatialAudioConfig

@Suite("SpatialAudioConfig — Properties")
struct SpatialAudioConfigTests {

    @Test("Init with dolbyAtmos format")
    func initAtmos() {
        let config = SpatialAudioConfig(
            format: .dolbyAtmos,
            channelLayout: .atmos7_1_4
        )
        #expect(config.format == .dolbyAtmos)
        #expect(config.channelLayout == .atmos7_1_4)
        #expect(config.generateStereoFallback == true)
    }

    @Test("Init with dolbyDigital format")
    func initAC3() {
        let config = SpatialAudioConfig(
            format: .dolbyDigital,
            channelLayout: .surround5_1
        )
        #expect(config.format == .dolbyDigital)
    }

    @Test("Init with dolbyDigitalPlus format")
    func initEAC3() {
        let config = SpatialAudioConfig(
            format: .dolbyDigitalPlus,
            channelLayout: .surround7_1
        )
        #expect(config.format == .dolbyDigitalPlus)
    }

    @Test("Init with multichannel format")
    func initMultichannel() {
        let config = SpatialAudioConfig(
            format: .multichannel,
            channelLayout: .surround5_1
        )
        #expect(config.format == .multichannel)
    }

    @Test("Default bitrate for Atmos is 768k")
    func defaultBitrateAtmos() {
        let config = SpatialAudioConfig(
            format: .dolbyAtmos,
            channelLayout: .atmos7_1_4
        )
        #expect(config.bitrate == 768_000)
    }

    @Test("Default bitrate for AC-3 is 448k")
    func defaultBitrateAC3() {
        let config = SpatialAudioConfig(
            format: .dolbyDigital,
            channelLayout: .surround5_1
        )
        #expect(config.bitrate == 448_000)
    }

    @Test("Default bitrate for E-AC-3 is 384k")
    func defaultBitrateEAC3() {
        let config = SpatialAudioConfig(
            format: .dolbyDigitalPlus,
            channelLayout: .surround5_1
        )
        #expect(config.bitrate == 384_000)
    }

    @Test("Default bitrate for multichannel is 256k")
    func defaultBitrateMultichannel() {
        let config = SpatialAudioConfig(
            format: .multichannel,
            channelLayout: .surround5_1
        )
        #expect(config.bitrate == 256_000)
    }

    @Test("Custom bitrate overrides default")
    func customBitrate() {
        let config = SpatialAudioConfig(
            format: .dolbyAtmos,
            channelLayout: .atmos7_1_4,
            bitrate: 1_000_000
        )
        #expect(config.bitrate == 1_000_000)
    }

    @Test("HLS codec string for Atmos is ec+3")
    func codecAtmos() {
        let config = SpatialAudioConfig.atmos7_1_4
        #expect(config.hlsCodecString == "ec+3")
    }

    @Test("HLS codec string for AC-3 is ac-3")
    func codecAC3() {
        let config = SpatialAudioConfig.surround5_1_ac3
        #expect(config.hlsCodecString == "ac-3")
    }

    @Test("HLS codec string for E-AC-3 is ec-3")
    func codecEAC3() {
        let config = SpatialAudioConfig.surround5_1_eac3
        #expect(config.hlsCodecString == "ec-3")
    }

    @Test("HLS codec string for multichannel is mp4a.40.2")
    func codecMultichannel() {
        let config = SpatialAudioConfig(
            format: .multichannel,
            channelLayout: .surround5_1
        )
        #expect(config.hlsCodecString == "mp4a.40.2")
    }

    @Test("HLS channels attribute delegates to layout")
    func channelsAttribute() {
        let config = SpatialAudioConfig.atmos7_1_4
        #expect(config.hlsChannelsAttribute == "16/JOC")
    }

    @Test("Bitrate range for Atmos")
    func bitrateRangeAtmos() {
        let config = SpatialAudioConfig.atmos7_1_4
        #expect(config.bitrateRange == 384_000...1_536_000)
    }

    @Test("Bitrate range for AC-3")
    func bitrateRangeAC3() {
        let config = SpatialAudioConfig.surround5_1_ac3
        #expect(config.bitrateRange == 192_000...640_000)
    }

    @Test("Bitrate range for E-AC-3")
    func bitrateRangeEAC3() {
        let config = SpatialAudioConfig.surround5_1_eac3
        #expect(config.bitrateRange == 96_000...6_144_000)
    }

    @Test("Bitrate range for multichannel")
    func bitrateRangeMultichannel() {
        let config = SpatialAudioConfig(
            format: .multichannel,
            channelLayout: .surround5_1
        )
        #expect(config.bitrateRange == 128_000...512_000)
    }

    @Test("Preset atmos5_1")
    func presetAtmos51() {
        let config = SpatialAudioConfig.atmos5_1
        #expect(config.format == .dolbyAtmos)
        #expect(config.channelLayout == .surround5_1)
        #expect(config.bitrate == 768_000)
    }

    @Test("Preset atmos7_1_4")
    func presetAtmos714() {
        let config = SpatialAudioConfig.atmos7_1_4
        #expect(config.format == .dolbyAtmos)
        #expect(config.channelLayout == .atmos7_1_4)
    }

    @Test("Preset surround5_1_ac3")
    func presetSurround51AC3() {
        let config = SpatialAudioConfig.surround5_1_ac3
        #expect(config.format == .dolbyDigital)
        #expect(config.bitrate == 448_000)
    }

    @Test("Preset surround5_1_eac3")
    func presetSurround51EAC3() {
        let config = SpatialAudioConfig.surround5_1_eac3
        #expect(config.format == .dolbyDigitalPlus)
        #expect(config.bitrate == 384_000)
    }

    @Test("Preset surround7_1")
    func presetSurround71() {
        let config = SpatialAudioConfig.surround7_1
        #expect(config.channelLayout == .surround7_1)
        #expect(config.bitrate == 512_000)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = SpatialAudioConfig.atmos7_1_4
        let b = SpatialAudioConfig.atmos7_1_4
        #expect(a == b)
    }

    @Test("Hashable conformance")
    func hashable() {
        let a = SpatialAudioConfig.atmos7_1_4
        let b = SpatialAudioConfig.surround5_1_ac3
        let set: Set<SpatialAudioConfig> = [a, b]
        #expect(set.count == 2)
    }

    @Test("SpatialFormat is CaseIterable with 4 cases")
    func formatCaseIterable() {
        let cases = SpatialAudioConfig.SpatialFormat.allCases
        #expect(cases.count == 4)
    }

    @Test("Default groupID is audio-spatial")
    func defaultGroupID() {
        let config = SpatialAudioConfig(
            format: .dolbyAtmos,
            channelLayout: .atmos7_1_4
        )
        #expect(config.groupID == "audio-spatial")
    }

    @Test("Custom groupID")
    func customGroupID() {
        let config = SpatialAudioConfig(
            format: .dolbyAtmos,
            channelLayout: .atmos7_1_4,
            groupID: "custom-group"
        )
        #expect(config.groupID == "custom-group")
    }
}
