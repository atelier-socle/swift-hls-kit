// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "Variable Substitution — End-to-End",
    .timeLimit(.minutes(1))
)
struct VariableEndToEndTests {

    private let parser = ManifestParser()
    private let generator = ManifestGenerator()
    private let validator = HLSValidator()

    @Test("Full CDN templating scenario")
    func cdnTemplating() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$base}/360p/playlist.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=2000000
            {$base}/720p/playlist.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=5000000
            {$base}/1080p/playlist.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(
            master.variants[0].uri
                == "https://cdn.example.com/360p/playlist.m3u8"
        )
        #expect(
            master.variants[1].uri
                == "https://cdn.example.com/720p/playlist.m3u8"
        )
        #expect(
            master.variants[2].uri
                == "https://cdn.example.com/1080p/playlist.m3u8"
        )
    }

    @Test("Multi-tenant scenario with IMPORT")
    func multiTenantImport() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:IMPORT="tenant_id"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions[0].type == .import)
        #expect(master.definitions[0].name == "tenant_id")

        let report = validator.validate(master, ruleSet: .rfc8216)
        let importErrors = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-import"
        }
        #expect(importErrors.isEmpty)
    }

    @Test("QUERYPARAM token extraction scenario")
    func queryParamExtraction() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:QUERYPARAM="token"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions[0].type == .queryParam)
        #expect(master.definitions[0].name == "token")
    }

    @Test("Multiple variables in single URI")
    func multipleVariablesInURI() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="host",VALUE="https://cdn.com"
            #EXT-X-DEFINE:NAME="path",VALUE="/live"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$host}{$path}/low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(
            master.variants[0].uri
                == "https://cdn.com/live/low.m3u8"
        )
    }

    @Test("Large manifest with many variables")
    func largeManifestManyVariables() throws {
        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:8"
        ]
        for i in 0..<10 {
            lines.append(
                "#EXT-X-DEFINE:NAME=\"v\(i)\",VALUE=\"val\(i)\""
            )
        }
        lines.append("#EXT-X-STREAM-INF:BANDWIDTH=800000")
        lines.append("low.m3u8")
        let m3u8 = lines.joined(separator: "\n")
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions.count == 10)
    }

    @Test("Edge case: partial variable syntax {$ without closing }")
    func partialVariableSyntax() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            {$incomplete
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.segments[0].uri == "{$incomplete")
    }

    @Test("Edge case: empty variable name {$}")
    func emptyVariableName() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            {$}/seg1.ts
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.segments[0].uri == "{$}/seg1.ts")
    }

    @Test("Variable in attribute value (not just URI)")
    func variableInAttributeValue() throws {
        let resolver = VariableResolver(
            definitions: ["name": "English"]
        )
        let result = resolver.resolve("Track: {$name}")
        #expect(result == "Track: English")
    }

    @Test("VariableResolver extractVariableNames")
    func extractVariableNames() {
        let names = VariableResolver.extractVariableNames(
            from: "{$host}/{$path}/file.ts"
        )
        #expect(names == ["host", "path"])
    }

    @Test("VariableResolver resolveStrict with undefined")
    func resolveStrictWithUndefined() {
        let resolver = VariableResolver(
            definitions: ["a": "1"]
        )
        let (resolved, undefined) = resolver.resolveStrict(
            "{$a}/{$b}"
        )
        #expect(resolved == "1/{$b}")
        #expect(undefined == ["b"])
    }

    @Test("VariableResolver defineFromQueryParam")
    func defineFromQueryParam() {
        var resolver = VariableResolver()
        let found = resolver.defineFromQueryParam(
            name: "token",
            url: "https://example.com/play?token=abc123&quality=high"
        )
        #expect(found)
        #expect(resolver.resolve("{$token}") == "abc123")
    }

    @Test("VariableResolver importVariable")
    func importVariable() {
        var parent = VariableResolver()
        parent.define(name: "base", value: "https://cdn.com")

        var child = VariableResolver()
        let imported = child.importVariable(
            name: "base", from: parent
        )
        #expect(imported)
        #expect(child.resolve("{$base}") == "https://cdn.com")
    }

    @Test("VariableDefinition type backward compat Codable")
    func variableDefinitionCodable() throws {
        let json = """
            {"name":"test","value":"val"}
            """
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(
            VariableDefinition.self, from: data
        )
        #expect(decoded.name == "test")
        #expect(decoded.value == "val")
        #expect(decoded.type == .value)
    }
}
