// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - AccessibilityRenditionGenerator — Captions

@Suite("AccessibilityRenditionGenerator — Captions")
struct AccessibilityRenditionCaptionTests {

    let generator = AccessibilityRenditionGenerator()

    @Test("Generate CEA-608 caption entries")
    func cea608Entries() {
        let entries = generator.generateCaptionEntries(config: .englishOnly608)
        #expect(entries.count == 1)
        #expect(entries[0].type == .closedCaptions)
        #expect(entries[0].tag.contains("INSTREAM-ID=\"CC1\""))
        #expect(entries[0].tag.contains("TYPE=CLOSED-CAPTIONS"))
    }

    @Test("Generate CEA-708 caption entries with multiple services")
    func cea708Entries() {
        let entries = generator.generateCaptionEntries(config: .englishSpanish708)
        #expect(entries.count == 2)
        #expect(entries[0].tag.contains("INSTREAM-ID=\"SERVICE1\""))
        #expect(entries[1].tag.contains("INSTREAM-ID=\"SERVICE2\""))
    }

    @Test("Caption entries include correct attributes")
    func captionAttributes() {
        let entries = generator.generateCaptionEntries(config: .englishSpanish708)
        let english = entries[0].tag
        #expect(english.contains("GROUP-ID=\"cc\""))
        #expect(english.contains("LANGUAGE=\"en\""))
        #expect(english.contains("NAME=\"English\""))
        #expect(english.contains("DEFAULT=YES"))
    }

    @Test("Non-default caption has DEFAULT=NO")
    func nonDefaultCaption() {
        let entries = generator.generateCaptionEntries(config: .englishSpanish708)
        let spanish = entries[1].tag
        #expect(spanish.contains("DEFAULT=NO"))
    }
}

// MARK: - AccessibilityRenditionGenerator — Subtitles

@Suite("AccessibilityRenditionGenerator — Subtitles")
struct AccessibilityRenditionSubtitleTests {

    let generator = AccessibilityRenditionGenerator()

    @Test("Generate subtitle entries from playlists")
    func subtitleEntries() {
        let en = LiveSubtitlePlaylist(language: "en", name: "English")
        let fr = LiveSubtitlePlaylist(language: "fr", name: "French")
        let entries = generator.generateSubtitleEntries(playlists: [
            (playlist: en, uri: "subs/en.m3u8"),
            (playlist: fr, uri: "subs/fr.m3u8")
        ])
        #expect(entries.count == 2)
        #expect(entries[0].type == .subtitles)
        #expect(entries[0].tag.contains("TYPE=SUBTITLES"))
        #expect(entries[0].tag.contains("LANGUAGE=\"en\""))
        #expect(entries[1].tag.contains("LANGUAGE=\"fr\""))
    }

    @Test("First subtitle is DEFAULT=YES")
    func firstSubtitleDefault() {
        let en = LiveSubtitlePlaylist(language: "en", name: "English")
        let entries = generator.generateSubtitleEntries(playlists: [
            (playlist: en, uri: "subs/en.m3u8")
        ])
        #expect(entries[0].tag.contains("DEFAULT=YES"))
    }

    @Test("Empty playlists returns empty entries")
    func emptyPlaylists() {
        let entries = generator.generateSubtitleEntries(
            playlists: [] as [(playlist: LiveSubtitlePlaylist, uri: String)]
        )
        #expect(entries.isEmpty)
    }
}

// MARK: - AccessibilityRenditionGenerator — Audio Descriptions

@Suite("AccessibilityRenditionGenerator — Audio Descriptions")
struct AccessibilityRenditionAudioDescTests {

    let generator = AccessibilityRenditionGenerator()

    @Test("Generate audio description entries")
    func audioDescEntries() {
        let entries = generator.generateAudioDescriptionEntries(configs: [
            (config: .english, uri: "audio/ad/en.m3u8"),
            (config: .french, uri: "audio/ad/fr.m3u8")
        ])
        #expect(entries.count == 2)
        #expect(entries[0].type == .audioDescription)
        #expect(entries[0].tag.contains("TYPE=AUDIO"))
        #expect(entries[0].tag.contains("CHARACTERISTICS="))
    }
}

// MARK: - AccessibilityRenditionGenerator — Combined

@Suite("AccessibilityRenditionGenerator — Combined")
struct AccessibilityRenditionCombinedTests {

    let generator = AccessibilityRenditionGenerator()

    @Test("generateAll combines all types")
    func generateAll() {
        let en = LiveSubtitlePlaylist(language: "en", name: "English")
        let entries = generator.generateAll(
            captions: .englishSpanish708,
            subtitles: [(playlist: en, uri: "subs/en.m3u8")],
            audioDescriptions: [(config: .english, uri: "ad/en.m3u8")]
        )
        let captionCount = entries.filter { $0.type == .closedCaptions }.count
        let subtitleCount = entries.filter { $0.type == .subtitles }.count
        let adCount = entries.filter { $0.type == .audioDescription }.count
        #expect(captionCount == 2)
        #expect(subtitleCount == 1)
        #expect(adCount == 1)
        #expect(entries.count == 4)
    }

    @Test("generateAll with only captions")
    func generateAllCaptionsOnly() {
        let entries = generator.generateAll(captions: .broadcast708)
        #expect(entries.count == 3)
        #expect(entries.allSatisfy { $0.type == .closedCaptions })
    }

    @Test("generateAll with no inputs returns empty")
    func generateAllEmpty() {
        let entries = generator.generateAll()
        #expect(entries.isEmpty)
    }
}

// MARK: - AccessibilityRenditionGenerator — Validation

@Suite("AccessibilityRenditionGenerator — Validation")
struct AccessibilityRenditionValidationTests {

    let generator = AccessibilityRenditionGenerator()

    @Test("validateVariantCaptions passes for matching config")
    func validateMatching() {
        let errors = generator.validateVariantCaptions(
            closedCaptionsAttr: "cc",
            config: .englishSpanish708
        )
        #expect(errors.isEmpty)
    }

    @Test("validateVariantCaptions errors on missing attribute")
    func validateMissingAttr() {
        let errors = generator.validateVariantCaptions(
            closedCaptionsAttr: nil,
            config: .englishSpanish708
        )
        #expect(errors.count == 1)
        #expect(errors[0].contains("no CLOSED-CAPTIONS attribute"))
    }

    @Test("validateVariantCaptions errors on missing config")
    func validateMissingConfig() {
        let errors = generator.validateVariantCaptions(
            closedCaptionsAttr: "cc",
            config: nil
        )
        #expect(errors.count == 1)
        #expect(errors[0].contains("no caption config"))
    }

    @Test("validateVariantCaptions errors on mismatch")
    func validateMismatch() {
        let errors = generator.validateVariantCaptions(
            closedCaptionsAttr: "wrong",
            config: .englishSpanish708
        )
        #expect(errors.count == 1)
        #expect(errors[0].contains("does not match"))
    }

    @Test("validateVariantCaptions passes when both nil")
    func validateBothNil() {
        let errors = generator.validateVariantCaptions(
            closedCaptionsAttr: nil,
            config: nil
        )
        #expect(errors.isEmpty)
    }
}

// MARK: - AccessibilityType

@Suite("AccessibilityType — Cases")
struct AccessibilityTypeTests {

    @Test("All accessibility types exist")
    func allCases() {
        let cases = AccessibilityRenditionGenerator.AccessibilityType.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.closedCaptions))
        #expect(cases.contains(.subtitles))
        #expect(cases.contains(.audioDescription))
    }
}
