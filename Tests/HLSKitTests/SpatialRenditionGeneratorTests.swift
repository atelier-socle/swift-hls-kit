// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - SpatialRenditionGenerator

@Suite("SpatialRenditionGenerator — Single Renditions")
struct SpatialRenditionSingleTests {

    let generator = SpatialRenditionGenerator()

    @Test("Atmos config produces 2 renditions (spatial + stereo)")
    func atmosWithFallback() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            language: "en",
            name: "English (Atmos)"
        )
        #expect(renditions.count == 2)
        #expect(renditions[0].channels == "16/JOC")
        #expect(renditions[1].channels == "2")
    }

    @Test("Config without fallback produces 1 rendition")
    func noFallback() {
        var config = SpatialAudioConfig.surround5_1_ac3
        config.generateStereoFallback = false
        let renditions = generator.generateRenditions(
            config: config,
            name: "Surround 5.1"
        )
        #expect(renditions.count == 1)
    }

    @Test("Stereo fallback has CHANNELS=2 and CODECS=mp4a.40.2")
    func stereoFallbackAttributes() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "English (Atmos)"
        )
        let fallback = renditions[1]
        #expect(fallback.channels == "2")
        #expect(fallback.codecs == "mp4a.40.2")
        #expect(fallback.name == "Stereo")
    }

    @Test("AC-3 rendition has correct CODECS ac-3")
    func ac3Codecs() {
        let renditions = generator.generateRenditions(
            config: .surround5_1_ac3,
            name: "Surround AC-3"
        )
        #expect(renditions[0].codecs == "ac-3")
    }

    @Test("E-AC-3 rendition has correct CODECS ec-3")
    func eac3Codecs() {
        let renditions = generator.generateRenditions(
            config: .surround5_1_eac3,
            name: "Surround E-AC-3"
        )
        #expect(renditions[0].codecs == "ec-3")
    }

    @Test("Rendition includes language")
    func renditionLanguage() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            language: "fr",
            name: "French (Atmos)"
        )
        #expect(renditions[0].language == "fr")
    }

    @Test("Rendition includes groupID from config")
    func renditionGroupID() {
        let config = SpatialAudioConfig(
            format: .dolbyAtmos,
            channelLayout: .atmos7_1_4,
            groupID: "my-group"
        )
        let renditions = generator.generateRenditions(
            config: config,
            name: "Test"
        )
        #expect(renditions[0].groupID == "my-group")
    }

    @Test("Default rendition is isDefault=true")
    func defaultRendition() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test",
            isDefault: true
        )
        #expect(renditions[0].isDefault == true)
    }

    @Test("Non-default rendition is isDefault=false")
    func nonDefaultRendition() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test",
            isDefault: false
        )
        #expect(renditions[0].isDefault == false)
    }

    @Test("All renditions have autoSelect=true")
    func autoSelect() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test"
        )
        for rendition in renditions {
            #expect(rendition.autoSelect == true)
        }
    }

    @Test("Rendition with URI")
    func renditionURI() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test",
            uri: "audio/atmos/main.m3u8"
        )
        #expect(renditions[0].uri == "audio/atmos/main.m3u8")
    }

    @Test("Rendition without URI has nil uri")
    func renditionNoURI() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test"
        )
        #expect(renditions[0].uri == nil)
    }
}

// MARK: - formatAsTag

@Suite("SpatialRenditionGenerator — formatAsTag")
struct SpatialRenditionTagTests {

    let generator = SpatialRenditionGenerator()

    @Test("Tag contains EXT-X-MEDIA prefix")
    func tagPrefix() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test"
        )
        let tag = renditions[0].formatAsTag()
        #expect(tag.hasPrefix("#EXT-X-MEDIA:"))
    }

    @Test("Tag contains TYPE=AUDIO")
    func tagTypeAudio() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test"
        )
        #expect(renditions[0].formatAsTag().contains("TYPE=AUDIO"))
    }

    @Test("Tag contains GROUP-ID")
    func tagGroupID() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test"
        )
        let tag = renditions[0].formatAsTag()
        #expect(tag.contains("GROUP-ID=\"audio-spatial\""))
    }

    @Test("Tag contains CHANNELS")
    func tagChannels() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test"
        )
        let tag = renditions[0].formatAsTag()
        #expect(tag.contains("CHANNELS=\"16/JOC\""))
    }

    @Test("Tag contains LANGUAGE when set")
    func tagLanguage() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            language: "en",
            name: "English"
        )
        #expect(renditions[0].formatAsTag().contains("LANGUAGE=\"en\""))
    }

    @Test("Tag omits URI when nil")
    func tagNoURI() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test"
        )
        #expect(!renditions[0].formatAsTag().contains("URI="))
    }

    @Test("Tag includes URI when set")
    func tagWithURI() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test",
            uri: "audio/main.m3u8"
        )
        #expect(renditions[0].formatAsTag().contains("URI=\"audio/main.m3u8\""))
    }

    @Test("Tag contains NAME")
    func tagName() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "English (Atmos)"
        )
        #expect(renditions[0].formatAsTag().contains("NAME=\"English (Atmos)\""))
    }

    @Test("Tag contains DEFAULT=YES for default rendition")
    func tagDefaultYes() {
        let renditions = generator.generateRenditions(
            config: .atmos7_1_4,
            name: "Test",
            isDefault: true
        )
        #expect(renditions[0].formatAsTag().contains("DEFAULT=YES"))
    }
}

// MARK: - Multi-Language

@Suite("SpatialRenditionGenerator — Multi-Language")
struct SpatialRenditionMultiLangTests {

    let generator = SpatialRenditionGenerator()

    @Test("3 languages produce correct number of renditions")
    func threeLanguages() {
        let tracks: [SpatialRenditionGenerator.AudioTrackDescriptor] = [
            .init(language: "fr", name: "French (Atmos)", config: .atmos7_1_4, uri: "audio/fr/atmos.m3u8"),
            .init(language: "en", name: "English (Atmos)", config: .atmos7_1_4, uri: "audio/en/atmos.m3u8"),
            .init(language: "es", name: "Spanish (Atmos)", config: .atmos7_1_4, uri: "audio/es/atmos.m3u8")
        ]
        let renditions = generator.generateMultiLanguageRenditions(
            tracks: tracks
        )
        // Each track: 1 spatial + 1 stereo fallback = 2 per language
        #expect(renditions.count == 6)
    }

    @Test("First language is DEFAULT=YES")
    func firstIsDefault() {
        let tracks: [SpatialRenditionGenerator.AudioTrackDescriptor] = [
            .init(language: "fr", name: "French", config: .surround5_1_ac3, uri: "audio/fr.m3u8"),
            .init(language: "en", name: "English", config: .surround5_1_ac3, uri: "audio/en.m3u8")
        ]
        let renditions = generator.generateMultiLanguageRenditions(
            tracks: tracks
        )
        #expect(renditions[0].isDefault == true)
    }

    @Test("Non-first languages are DEFAULT=NO")
    func othersNotDefault() {
        let tracks: [SpatialRenditionGenerator.AudioTrackDescriptor] = [
            .init(language: "fr", name: "French", config: .surround5_1_ac3, uri: "audio/fr.m3u8"),
            .init(language: "en", name: "English", config: .surround5_1_ac3, uri: "audio/en.m3u8")
        ]
        let renditions = generator.generateMultiLanguageRenditions(
            tracks: tracks
        )
        // Second track's spatial rendition (index 2)
        #expect(renditions[2].isDefault == false)
    }

    @Test("Each language has correct language attribute")
    func languageAttributes() {
        let tracks: [SpatialRenditionGenerator.AudioTrackDescriptor] = [
            .init(language: "fr", name: "French", config: .atmos7_1_4, uri: "audio/fr/atmos.m3u8"),
            .init(language: "en", name: "English", config: .atmos7_1_4, uri: "audio/en/atmos.m3u8")
        ]
        let renditions = generator.generateMultiLanguageRenditions(
            tracks: tracks
        )
        #expect(renditions[0].language == "fr")
        #expect(renditions[2].language == "en")
    }
}

// MARK: - Standalone Stereo Fallback

@Suite("SpatialRenditionGenerator — Stereo Fallback")
struct SpatialRenditionFallbackTests {

    let generator = SpatialRenditionGenerator()

    @Test("generateStereoFallback produces correct rendition")
    func standaloneFallback() {
        let fallback = generator.generateStereoFallback(
            language: "en",
            groupID: "audio-main",
            uri: "audio/stereo.m3u8",
            isDefault: true
        )
        #expect(fallback.name == "Stereo")
        #expect(fallback.channels == "2")
        #expect(fallback.codecs == "mp4a.40.2")
        #expect(fallback.language == "en")
        #expect(fallback.groupID == "audio-main")
        #expect(fallback.isDefault == true)
    }

    @Test("Stereo fallback without language")
    func fallbackNoLanguage() {
        let fallback = generator.generateStereoFallback(
            language: nil,
            groupID: "audio",
            uri: nil,
            isDefault: false
        )
        #expect(fallback.language == nil)
        #expect(fallback.uri == nil)
    }
}
