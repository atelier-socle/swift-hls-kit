// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - SessionDataConfig

@Suite("SessionDataConfig — Configuration")
struct SessionDataConfigTests {

    @Test("Default init has empty entries")
    func defaultInit() {
        let config = SessionDataConfig()
        #expect(config.entries.isEmpty)
    }

    @Test("Init with entries")
    func initWithEntries() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Live Concert")
        ])
        #expect(config.entries.count == 1)
    }

    @Test("generateTags produces correct format with VALUE")
    func generateTagsValue() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Live Concert")
        ])
        let tags = config.generateTags()
        #expect(tags.count == 1)
        #expect(tags[0].contains("#EXT-X-SESSION-DATA:"))
        #expect(tags[0].contains("DATA-ID=\"com.example.title\""))
        #expect(tags[0].contains("VALUE=\"Live Concert\""))
    }

    @Test("generateTags produces correct format with URI")
    func generateTagsURI() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.data", uri: "https://example.com/data.json")
        ])
        let tags = config.generateTags()
        #expect(tags[0].contains("URI=\"https://example.com/data.json\""))
        #expect(!tags[0].contains("VALUE"))
    }

    @Test("generateTags includes LANGUAGE attribute")
    func generateTagsLanguage() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Concert en direct", language: "fr")
        ])
        let tags = config.generateTags()
        #expect(tags[0].contains("LANGUAGE=\"fr\""))
    }

    @Test("Multiple entries generate multiple tags")
    func multipleEntries() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Title"),
            .init(dataID: "com.example.artist", value: "Artist"),
            .init(dataID: "com.example.data", uri: "data.json")
        ])
        let tags = config.generateTags()
        #expect(tags.count == 3)
    }
}

// MARK: - Validation

@Suite("SessionDataConfig — Validation")
struct SessionDataConfigValidationTests {

    @Test("Valid entry has no errors")
    func validEntry() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Title")
        ])
        #expect(config.validate().isEmpty)
    }

    @Test("Empty dataID is invalid")
    func emptyDataID() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "", value: "Value")
        ])
        let errors = config.validate()
        #expect(errors.contains { $0.contains("DATA-ID is empty") })
    }

    @Test("Both VALUE and URI is invalid")
    func bothValueAndURI() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.data", value: "Value", uri: "data.json")
        ])
        let errors = config.validate()
        #expect(errors.contains { $0.contains("mutually exclusive") })
    }

    @Test("Neither VALUE nor URI is invalid")
    func neitherValueNorURI() {
        let config = SessionDataConfig(entries: [
            .init(dataID: "com.example.data")
        ])
        let errors = config.validate()
        #expect(errors.contains { $0.contains("either VALUE or URI") })
    }
}

// MARK: - Mutation

@Suite("SessionDataConfig — Mutation")
struct SessionDataConfigMutationTests {

    @Test("addEntry appends entry")
    func addEntry() {
        var config = SessionDataConfig()
        config.addEntry(.init(dataID: "com.example.title", value: "Title"))
        #expect(config.entries.count == 1)
        #expect(config.entries[0].dataID == "com.example.title")
    }

    @Test("addEntry preserves existing entries")
    func addEntryPreservesExisting() {
        var config = SessionDataConfig(entries: [
            .init(dataID: "com.example.first", value: "First")
        ])
        config.addEntry(.init(dataID: "com.example.second", value: "Second"))
        #expect(config.entries.count == 2)
    }
}

// MARK: - Equatable

@Suite("SessionDataConfig — Equatable")
struct SessionDataConfigEquatableTests {

    @Test("Identical configs are equal")
    func identical() {
        let a = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Title")
        ])
        let b = SessionDataConfig(entries: [
            .init(dataID: "com.example.title", value: "Title")
        ])
        #expect(a == b)
    }

    @Test("Different configs are not equal")
    func different() {
        let a = SessionDataConfig(entries: [
            .init(dataID: "com.example.a", value: "A")
        ])
        let b = SessionDataConfig(entries: [
            .init(dataID: "com.example.b", value: "B")
        ])
        #expect(a != b)
    }
}
