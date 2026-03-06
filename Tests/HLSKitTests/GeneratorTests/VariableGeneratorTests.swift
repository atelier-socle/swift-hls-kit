// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "Variable Generator — EXT-X-DEFINE",
    .timeLimit(.minutes(1))
)
struct VariableGeneratorTests {

    private let generator = ManifestGenerator()
    private let parser = ManifestParser()

    @Test("Generate NAME+VALUE define")
    func generateNameValueDefine() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(
                    name: "base",
                    value: "https://cdn.example.com"
                )
            ]
        )
        let m3u8 = generator.generateMaster(playlist)
        #expect(
            m3u8.contains(
                "#EXT-X-DEFINE:NAME=\"base\",VALUE=\"https://cdn.example.com\""
            )
        )
    }

    @Test("Generate IMPORT define")
    func generateImportDefine() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(name: "token", type: .import)
            ]
        )
        let m3u8 = generator.generateMaster(playlist)
        #expect(
            m3u8.contains("#EXT-X-DEFINE:IMPORT=\"token\"")
        )
    }

    @Test("Generate QUERYPARAM define")
    func generateQueryParamDefine() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(
                    name: "auth", type: .queryParam
                )
            ]
        )
        let m3u8 = generator.generateMaster(playlist)
        #expect(
            m3u8.contains("#EXT-X-DEFINE:QUERYPARAM=\"auth\"")
        )
    }

    @Test("Generate multiple defines")
    func generateMultipleDefines() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(
                    name: "cdn", value: "https://cdn.com"
                ),
                VariableDefinition(name: "token", type: .import),
                VariableDefinition(
                    name: "auth", type: .queryParam
                )
            ]
        )
        let m3u8 = generator.generateMaster(playlist)
        #expect(m3u8.contains("NAME=\"cdn\""))
        #expect(m3u8.contains("IMPORT=\"token\""))
        #expect(m3u8.contains("QUERYPARAM=\"auth\""))
    }

    @Test("Defines emitted before variants")
    func definesBeforeContent() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(
                    name: "base", value: "https://cdn.com"
                )
            ]
        )
        let m3u8 = generator.generateMaster(playlist)
        let lines = m3u8.components(separatedBy: "\n")
        let defineLine = lines.firstIndex {
            $0.contains("EXT-X-DEFINE")
        }
        let variantLine = lines.firstIndex {
            $0.contains("EXT-X-STREAM-INF")
        }
        #expect(defineLine != nil)
        #expect(variantLine != nil)
        if let d = defineLine, let v = variantLine {
            #expect(d < v)
        }
    }

    @Test("Round-trip: generated output re-parseable")
    func roundTripReparseable() throws {
        let original = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(
                    name: "cdn", value: "https://cdn.com"
                ),
                VariableDefinition(name: "token", type: .import)
            ]
        )
        let m3u8 = generator.generateMaster(original)
        let reparsed = try parser.parse(m3u8)
        guard case .master(let master) = reparsed else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions.count == 2)
        #expect(master.definitions[0].type == .value)
        #expect(master.definitions[1].type == .import)
    }

    @Test("Version auto-calculation with defines is >= v8")
    func versionAutoCalcWithDefines() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(
                    name: "x", value: "y"
                )
            ]
        )
        let m3u8 = generator.generateMaster(playlist)
        #expect(m3u8.contains("#EXT-X-VERSION:8"))
    }

    @Test("Media playlist with defines generates correctly")
    func mediaPlaylistWithDefines() {
        let playlist = MediaPlaylist(
            version: .v8,
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "{$path}/seg1.ts")
            ],
            definitions: [
                VariableDefinition(
                    name: "path", value: "/live"
                )
            ]
        )
        let m3u8 = generator.generateMedia(playlist)
        #expect(
            m3u8.contains(
                "#EXT-X-DEFINE:NAME=\"path\",VALUE=\"/live\""
            )
        )
    }

    @Test("Generate define in media playlist with IMPORT form")
    func mediaPlaylistImportDefine() {
        let playlist = MediaPlaylist(
            version: .v8,
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg1.ts")
            ],
            definitions: [
                VariableDefinition(name: "base", type: .import)
            ]
        )
        let m3u8 = generator.generateMedia(playlist)
        #expect(m3u8.contains("#EXT-X-DEFINE:IMPORT=\"base\""))
    }
}
