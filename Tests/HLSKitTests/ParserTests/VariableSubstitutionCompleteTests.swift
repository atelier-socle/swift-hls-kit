// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "Variable Substitution — Complete",
    .timeLimit(.minutes(1))
)
struct VariableSubstitutionCompleteTests {

    private let parser = ManifestParser()
    private let generator = ManifestGenerator()

    // MARK: - Parsing Forms

    @Test("Parse manifest with NAME+VALUE defines")
    func parseNameValueDefines() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$base}/360p/playlist.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions.count == 1)
        #expect(master.definitions[0].name == "base")
        #expect(
            master.definitions[0].value
                == "https://cdn.example.com"
        )
        #expect(master.definitions[0].type == .value)
        #expect(
            master.variants[0].uri
                == "https://cdn.example.com/360p/playlist.m3u8"
        )
    }

    @Test("Parse manifest with IMPORT defines")
    func parseImportDefines() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:IMPORT="token"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low/playlist.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions.count == 1)
        #expect(master.definitions[0].name == "token")
        #expect(master.definitions[0].type == .import)
    }

    @Test("Parse manifest with QUERYPARAM defines")
    func parseQueryParamDefines() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:QUERYPARAM="token"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low/playlist.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions.count == 1)
        #expect(master.definitions[0].name == "token")
        #expect(master.definitions[0].type == .queryParam)
    }

    @Test("Parse manifest with all 3 forms combined")
    func parseAllThreeForms() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="cdn",VALUE="https://cdn.example.com"
            #EXT-X-DEFINE:IMPORT="auth"
            #EXT-X-DEFINE:QUERYPARAM="token"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low/playlist.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions.count == 3)
        #expect(master.definitions[0].type == .value)
        #expect(master.definitions[1].type == .import)
        #expect(master.definitions[2].type == .queryParam)
    }

    // MARK: - Variable Resolution

    @Test("Variable resolution in variant URIs")
    func resolveVariantURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$base}/low.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=2000000
            {$base}/high.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(
            master.variants[0].uri
                == "https://cdn.example.com/low.m3u8"
        )
        #expect(
            master.variants[1].uri
                == "https://cdn.example.com/high.m3u8"
        )
    }

    @Test("Variable resolution in segment URIs")
    func resolveSegmentURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-TARGETDURATION:6
            #EXT-X-DEFINE:NAME="path",VALUE="/live/stream"
            #EXTINF:6.0,
            {$path}/seg1.ts
            #EXTINF:6.0,
            {$path}/seg2.ts
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.segments[0].uri == "/live/stream/seg1.ts")
        #expect(media.segments[1].uri == "/live/stream/seg2.ts")
    }

    @Test("Variable resolution in rendition URIs")
    func resolveRenditionURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",URI="{$base}/audio/en.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=800000,AUDIO="audio"
            low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(
            master.renditions[0].uri
                == "https://cdn.example.com/audio/en.m3u8"
        )
    }

    @Test("Variable resolution in map URIs")
    func resolveMapURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-TARGETDURATION:6
            #EXT-X-DEFINE:NAME="cdn",VALUE="https://cdn.example.com"
            #EXT-X-MAP:URI="{$cdn}/init.mp4"
            #EXTINF:6.0,
            seg1.ts
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(
            media.segments[0].map?.uri
                == "https://cdn.example.com/init.mp4"
        )
    }

    @Test("Undefined variables left as-is")
    func undefinedVariablesLeftAsIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            {$undefined}/seg1.ts
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.segments[0].uri == "{$undefined}/seg1.ts")
    }

    @Test("Empty variable definitions")
    func emptyVariableDefinitions() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="empty",VALUE=""
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$empty}playlist.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.variants[0].uri == "playlist.m3u8")
    }

    @Test("Parse-generate round-trip with variables")
    func roundTripWithVariables() throws {
        let original = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "{$base}/low.m3u8"
                )
            ],
            definitions: [
                VariableDefinition(
                    name: "base",
                    value: "https://cdn.example.com"
                )
            ]
        )
        let m3u8 = generator.generate(.master(original))
        let reparsed = try parser.parse(m3u8)
        guard case .master(let master) = reparsed else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.definitions.count == 1)
        #expect(master.definitions[0].name == "base")
        #expect(
            master.definitions[0].value
                == "https://cdn.example.com"
        )
    }

    @Test("Manifest without variables parses identically")
    func noVariablesRegression() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=2000000
            high.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.variants.count == 2)
        #expect(master.variants[0].uri == "low.m3u8")
        #expect(master.definitions.isEmpty)
    }

    @Test("Variable resolution in key URIs")
    func resolveKeyURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-TARGETDURATION:6
            #EXT-X-DEFINE:NAME="keyhost",VALUE="https://keys.example.com"
            #EXT-X-KEY:METHOD=AES-128,URI="{$keyhost}/key.bin"
            #EXTINF:6.0,
            seg1.ts
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(
            media.segments[0].key?.uri
                == "https://keys.example.com/key.bin"
        )
    }
}
