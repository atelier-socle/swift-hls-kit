// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - AudioDescriptionConfig

@Suite("AudioDescriptionConfig — Configuration")
struct AudioDescriptionConfigTests {

    @Test("Default init has English defaults")
    func defaultInit() {
        let config = AudioDescriptionConfig()
        #expect(config.language == "en")
        #expect(config.name == "English Audio Description")
        #expect(config.groupID == "audio-ad")
        #expect(config.characteristics == "public.accessibility.describes-video")
    }

    @Test("Custom init sets all properties")
    func customInit() {
        let config = AudioDescriptionConfig(
            language: "de",
            name: "Deutsche Audiobeschreibung",
            groupID: "ad-audio",
            characteristics: "public.accessibility.describes-video,public.accessibility.transcribes-spoken-dialog"
        )
        #expect(config.language == "de")
        #expect(config.name == "Deutsche Audiobeschreibung")
        #expect(config.groupID == "ad-audio")
        #expect(config.characteristics.contains("describes-video"))
    }

    @Test("renditionEntry generates correct EXT-X-MEDIA tag")
    func renditionEntry() {
        let config = AudioDescriptionConfig()
        let entry = config.renditionEntry(uri: "audio/ad/en/main.m3u8")
        #expect(entry.hasPrefix("#EXT-X-MEDIA:"))
        #expect(entry.contains("TYPE=AUDIO"))
        #expect(entry.contains("GROUP-ID=\"audio-ad\""))
        #expect(entry.contains("LANGUAGE=\"en\""))
        #expect(entry.contains("NAME=\"English Audio Description\""))
        #expect(entry.contains("DEFAULT=NO"))
        #expect(entry.contains("AUTOSELECT=YES"))
        #expect(entry.contains("CHARACTERISTICS=\"public.accessibility.describes-video\""))
        #expect(entry.contains("URI=\"audio/ad/en/main.m3u8\""))
    }

    @Test("renditionEntry with isDefault true")
    func renditionEntryDefault() {
        let config = AudioDescriptionConfig()
        let entry = config.renditionEntry(uri: "ad.m3u8", isDefault: true)
        #expect(entry.contains("DEFAULT=YES"))
    }

    @Test("renditionEntry with isDefault false")
    func renditionEntryNotDefault() {
        let config = AudioDescriptionConfig()
        let entry = config.renditionEntry(uri: "ad.m3u8")
        #expect(entry.contains("DEFAULT=NO"))
    }
}

// MARK: - Presets

@Suite("AudioDescriptionConfig — Presets")
struct AudioDescriptionConfigPresetTests {

    @Test("English preset")
    func englishPreset() {
        let config = AudioDescriptionConfig.english
        #expect(config.language == "en")
        #expect(config.name == "English Audio Description")
    }

    @Test("French preset")
    func frenchPreset() {
        let config = AudioDescriptionConfig.french
        #expect(config.language == "fr")
        #expect(config.name == "Audiodescription français")
    }

    @Test("Spanish preset")
    func spanishPreset() {
        let config = AudioDescriptionConfig.spanish
        #expect(config.language == "es")
        #expect(config.name == "Audiodescripción en español")
    }
}

// MARK: - Equatable

@Suite("AudioDescriptionConfig — Equatable")
struct AudioDescriptionConfigEquatableTests {

    @Test("Identical configs are equal")
    func identical() {
        let a = AudioDescriptionConfig.english
        let b = AudioDescriptionConfig.english
        #expect(a == b)
    }

    @Test("Different configs are not equal")
    func different() {
        let a = AudioDescriptionConfig.english
        let b = AudioDescriptionConfig.french
        #expect(a != b)
    }
}
