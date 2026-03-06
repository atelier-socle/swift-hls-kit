// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Variable Substitution Showcase

@Suite("Variable Substitution Showcase — EXT-X-DEFINE & Resolution")
struct VariableSubstitutionShowcaseTests {

    // MARK: - Parsing NAME/VALUE

    @Test("Parse manifest with NAME/VALUE definition extracts definitions array")
    func parseNameValueDefinition() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e"
            {$base}/360p/playlist.m3u8
            """

        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }

        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "base")
        #expect(playlist.definitions[0].value == "https://cdn.example.com")
        #expect(playlist.definitions[0].type == .value)

        // The parser resolves variables in variant URIs.
        #expect(
            playlist.variants[0].uri
                == "https://cdn.example.com/360p/playlist.m3u8"
        )
    }

    // MARK: - Parsing IMPORT

    @Test("Parse manifest with IMPORT definition produces import type")
    func parseImportDefinition() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-DEFINE:IMPORT="token"
            #EXT-X-STREAM-INF:BANDWIDTH=1500000
            low/playlist.m3u8
            """

        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }

        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "token")
        #expect(playlist.definitions[0].type == .import)
    }

    // MARK: - Parsing QUERYPARAM

    @Test("Parse manifest with QUERYPARAM definition produces queryParam type")
    func parseQueryParamDefinition() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-DEFINE:QUERYPARAM="session"
            #EXT-X-STREAM-INF:BANDWIDTH=2000000
            main/playlist.m3u8
            """

        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }

        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "session")
        #expect(playlist.definitions[0].type == .queryParam)
    }

    // MARK: - Builder DSL

    @Test("Build MasterPlaylist with definitions using result builder DSL")
    func buildMasterPlaylistWithDefinitions() {
        let playlist = MasterPlaylist {
            Define(name: "base", value: "https://cdn.example.com")
            Define(import: "authToken")
            Variant(
                bandwidth: 800_000,
                resolution: Resolution(width: 640, height: 360),
                uri: "360p/playlist.m3u8",
                codecs: "avc1.4d401e"
            )
            Variant(
                bandwidth: 2_800_000,
                resolution: Resolution(width: 1280, height: 720),
                uri: "720p/playlist.m3u8",
                codecs: "avc1.4d401f"
            )
        }

        #expect(playlist.definitions.count == 2)
        #expect(playlist.definitions[0].name == "base")
        #expect(playlist.definitions[0].type == .value)
        #expect(playlist.definitions[1].name == "authToken")
        #expect(playlist.definitions[1].type == .import)
        #expect(playlist.variants.count == 2)
    }

    // MARK: - Generation

    @Test("Generate M3U8 from MasterPlaylist with definitions outputs EXT-X-DEFINE tags")
    func generateManifestWithDefinitions() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: Resolution(width: 640, height: 360),
                    uri: "360p/playlist.m3u8",
                    codecs: "avc1.4d401e"
                )
            ],
            definitions: [
                VariableDefinition(name: "base", value: "https://cdn.example.com"),
                VariableDefinition(import: "token"),
                VariableDefinition(queryParam: "session")
            ]
        )

        let output = ManifestGenerator().generateMaster(playlist)

        #expect(output.contains("#EXTM3U"))
        #expect(output.contains("#EXT-X-VERSION:8"))
        #expect(output.contains("EXT-X-DEFINE:"))
        #expect(output.contains("NAME=\"base\""))
        #expect(output.contains("VALUE=\"https://cdn.example.com\""))
        #expect(output.contains("IMPORT=\"token\""))
        #expect(output.contains("QUERYPARAM=\"session\""))
        #expect(output.contains("BANDWIDTH=800000"))
    }

    // MARK: - Convenience Initializers

    @Test("VariableDefinition convenience initializers set correct types")
    func variableDefinitionConvenienceForms() {
        let nameValue = VariableDefinition(name: "cdn", value: "https://cdn.co")
        #expect(nameValue.name == "cdn")
        #expect(nameValue.value == "https://cdn.co")
        #expect(nameValue.type == .value)

        let importDef = VariableDefinition(import: "parentVar")
        #expect(importDef.name == "parentVar")
        #expect(importDef.value == "")
        #expect(importDef.type == .import)

        let queryDef = VariableDefinition(queryParam: "sid")
        #expect(queryDef.name == "sid")
        #expect(queryDef.value == "")
        #expect(queryDef.type == .queryParam)

        // DefinitionType has exactly 3 cases.
        #expect(VariableDefinition.DefinitionType.allCases.count == 3)
    }

    // MARK: - Validation: Undefined Variable

    @Test("Validate manifest with undefined variable reference produces error")
    func validateUndefinedVariableReference() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$undefined_var}/360p/playlist.m3u8
            """

        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }

        let validator = HLSValidator()
        let report = validator.validate(playlist, ruleSet: .rfc8216)

        let undefinedErrors = report.errors.filter {
            $0.message.contains("Undefined variable reference")
        }
        #expect(!undefinedErrors.isEmpty)
        #expect(!report.isValid)
    }

    // MARK: - CDN Path Templating Pattern

    @Test("CDN path templating: definitions with variable URIs for multi-CDN setup")
    func cdnPathTemplatingPattern() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn-east.example.com/live"
            #EXT-X-DEFINE:NAME="suffix",VALUE=".m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360,CODECS="avc1.4d401e"
            {$base}/360p/playlist{$suffix}
            #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720,CODECS="avc1.4d401f"
            {$base}/720p/playlist{$suffix}
            #EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080,CODECS="avc1.640028"
            {$base}/1080p/playlist{$suffix}
            """

        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }

        // Definitions are preserved.
        #expect(playlist.definitions.count == 2)
        #expect(playlist.definitions[0].name == "base")
        #expect(playlist.definitions[1].name == "suffix")

        // Variables are resolved in variant URIs.
        #expect(playlist.variants.count == 3)
        #expect(
            playlist.variants[0].uri
                == "https://cdn-east.example.com/live/360p/playlist.m3u8"
        )
        #expect(
            playlist.variants[1].uri
                == "https://cdn-east.example.com/live/720p/playlist.m3u8"
        )
        #expect(
            playlist.variants[2].uri
                == "https://cdn-east.example.com/live/1080p/playlist.m3u8"
        )

        // Validate passes with all variables defined.
        let validator = HLSValidator()
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let variableErrors = report.errors.filter {
            $0.message.contains("Undefined variable")
        }
        #expect(variableErrors.isEmpty)
    }
}
