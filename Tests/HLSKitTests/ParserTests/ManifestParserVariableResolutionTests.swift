// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "ManifestParser — Variable Resolution in URIs",
    .timeLimit(.minutes(1))
)
struct ManifestParserVariableResolutionTests {

    private let parser = ManifestParser()

    @Test("Resolves variables in iFrame variant URIs")
    func resolveIFrameVariantURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="cdn",VALUE="https://cdn.example.com"
            #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=200000,URI="{$cdn}/iframe.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(
            master.iFrameVariants[0].uri
                == "https://cdn.example.com/iframe.m3u8"
        )
    }

    @Test("Resolves variables in session key URIs")
    func resolveSessionKeyURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="keyhost",VALUE="https://keys.example.com"
            #EXT-X-SESSION-KEY:METHOD=AES-128,URI="{$keyhost}/master.key"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(
            master.sessionKeys[0].uri
                == "https://keys.example.com/master.key"
        )
    }

    @Test("Resolves variables in session data URIs")
    func resolveSessionDataURIs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-SESSION-DATA:DATA-ID="com.example.data",URI="{$base}/data.json"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(
            master.sessionData[0].uri
                == "https://cdn.example.com/data.json"
        )
    }

    @Test("No resolution when no value definitions exist")
    func noResolutionWithoutValueDefs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:IMPORT="token"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$token}/low.m3u8
            """
        let manifest = try parser.parse(m3u8)
        guard case .master(let master) = manifest else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(master.variants[0].uri == "{$token}/low.m3u8")
    }
}
