// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - Spatial Audio Showcase

@Suite("Spatial Audio — Showcase Scenarios")
struct SpatialAudioShowcaseTests {

    let generator = SpatialRenditionGenerator()

    @Test("Podcast with Atmos spatial audio and stereo fallback")
    func podcastAtmos() {
        let config = SpatialAudioConfig.atmos5_1
        let renditions = generator.generateRenditions(
            config: config,
            language: "en",
            name: "English (Atmos)",
            uri: "audio/atmos/podcast.m3u8"
        )
        #expect(renditions.count == 2)
        #expect(renditions[0].codecs == "ec+3")
        #expect(renditions[1].codecs == "mp4a.40.2")
    }

    @Test("Multi-language live stream with 5.1 surround per language")
    func multiLanguageSurround() {
        let tracks: [SpatialRenditionGenerator.AudioTrackDescriptor] = [
            .init(language: "en", name: "English (5.1)", config: .surround5_1_ac3, uri: "audio/en/51.m3u8"),
            .init(language: "fr", name: "French (5.1)", config: .surround5_1_ac3, uri: "audio/fr/51.m3u8"),
            .init(language: "es", name: "Spanish (5.1)", config: .surround5_1_ac3, uri: "audio/es/51.m3u8")
        ]
        let renditions = generator.generateMultiLanguageRenditions(
            tracks: tracks
        )
        #expect(renditions.count == 6)
        #expect(renditions[0].isDefault == true)
        #expect(renditions[2].isDefault == false)
    }

    @Test("Cinema-grade Atmos 7.1.4 with Hi-Res lossless")
    func cinemaAtmos() {
        let spatial = SpatialAudioConfig.atmos7_1_4
        let hiRes = HiResAudioConfig.masterHiRes
        #expect(spatial.hlsChannelsAttribute == "16/JOC")
        #expect(hiRes.hlsCodecString == "fLaC")
        #expect(hiRes.sampleRate == .rate192kHz)
    }

    @Test("Budget AC-3 5.1 for broad compatibility")
    func budgetAC3() {
        let config = SpatialAudioConfig.surround5_1_ac3
        #expect(config.format == .dolbyDigital)
        #expect(config.hlsCodecString == "ac-3")
        #expect(config.channelLayout.channelCount == 6)
    }

    @Test("E-AC-3 7.1 for streaming service")
    func streamingEAC3() {
        let config = SpatialAudioConfig.surround7_1
        #expect(config.format == .dolbyDigitalPlus)
        #expect(config.hlsCodecString == "ec-3")
        #expect(config.channelLayout.channelCount == 8)
    }

    @Test("Hi-Res FLAC studio master")
    func studioMaster() {
        let hiRes = HiResAudioConfig.audiophile
        #expect(hiRes.sampleRate == .rate192kHz)
        #expect(hiRes.bitDepth == .depth32)
        #expect(hiRes.codec == .flac)
        #expect(hiRes.isHiRes == true)
        #expect(hiRes.estimatedBitrate > 0)
    }

    @Test("CD quality ALAC with AAC fallback")
    func cdQualityWithFallback() {
        let config = HiResAudioConfig.cdQuality
        #expect(config.sampleRate == .rate44_1kHz)
        #expect(config.bitDepth == .depth16)
        #expect(config.codec == .alac)
        #expect(config.generateAACFallback == true)
        #expect(config.isHiRes == false)
    }

    @Test("Complete rendition set: Atmos + 5.1 + stereo per language")
    func completeRenditionSet() {
        let atmosRenditions = generator.generateRenditions(
            config: .atmos7_1_4,
            language: "en",
            name: "English (Atmos)",
            uri: "audio/en/atmos.m3u8"
        )
        var ac3Config = SpatialAudioConfig.surround5_1_ac3
        ac3Config.generateStereoFallback = false
        let ac3Renditions = generator.generateRenditions(
            config: ac3Config,
            language: "en",
            name: "English (5.1)",
            uri: "audio/en/51.m3u8",
            isDefault: false
        )
        let total = atmosRenditions + ac3Renditions
        #expect(total.count == 3)
        #expect(total[0].channels == "16/JOC")
        #expect(total[1].channels == "2")
        #expect(total[2].channels == "6")
    }

    @Test("Spatial config to rendition tag produces valid EXT-X-MEDIA")
    func configToTag() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            language: "en",
            name: "English (Atmos)",
            uri: "audio/atmos.m3u8"
        )
        let tag = renditions[0].formatAsTag()
        #expect(tag.hasPrefix("#EXT-X-MEDIA:"))
        #expect(tag.contains("TYPE=AUDIO"))
        #expect(tag.contains("CHANNELS=\"16/JOC\""))
        #expect(tag.contains("LANGUAGE=\"en\""))
        #expect(tag.contains("URI=\"audio/atmos.m3u8\""))
        #expect(tag.contains("NAME=\"English (Atmos)\""))
        #expect(tag.contains("DEFAULT=YES"))
    }

    @Test("Round-trip: config attributes match rendition attributes")
    func roundTrip() {
        let config = SpatialAudioConfig.surround5_1_eac3
        let renditions = generator.generateRenditions(
            config: config,
            name: "5.1 Surround"
        )
        #expect(renditions[0].channels == config.hlsChannelsAttribute)
        #expect(renditions[0].codecs == config.hlsCodecString)
        #expect(renditions[0].groupID == config.groupID)
    }
}
