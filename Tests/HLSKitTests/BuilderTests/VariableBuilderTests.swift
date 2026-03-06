// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "Variable Builder DSL",
    .timeLimit(.minutes(1))
)
struct VariableBuilderTests {

    private let generator = ManifestGenerator()

    @Test("Define(name:value:) in master playlist")
    func defineNameValueInMaster() {
        let playlist = MasterPlaylist {
            Define(name: "base", value: "https://cdn.example.com")
            Variant(bandwidth: 800_000, uri: "{$base}/low.m3u8")
        }
        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "base")
        #expect(
            playlist.definitions[0].value
                == "https://cdn.example.com"
        )
        #expect(playlist.definitions[0].type == .value)
    }

    @Test("Define(import:) in master playlist")
    func defineImportInMaster() {
        let playlist = MasterPlaylist {
            Define(import: "token")
            Variant(bandwidth: 800_000, uri: "low.m3u8")
        }
        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "token")
        #expect(playlist.definitions[0].type == .import)
    }

    @Test("Define(name:value:) in media playlist")
    func defineNameValueInMedia() {
        let playlist = MediaPlaylist(targetDuration: 6) {
            Define(name: "path", value: "/live/stream")
            Segment(duration: 6.0, uri: "{$path}/seg1.ts")
        }
        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "path")
        #expect(playlist.definitions[0].value == "/live/stream")
    }

    @Test("Define with variable references in Variant URIs")
    func defineWithVariantRefs() {
        let playlist = MasterPlaylist {
            Define(name: "cdn", value: "https://cdn.com")
            Variant(bandwidth: 800_000, uri: "{$cdn}/low.m3u8")
            Variant(bandwidth: 2_000_000, uri: "{$cdn}/high.m3u8")
        }
        #expect(playlist.variants[0].uri == "{$cdn}/low.m3u8")
        #expect(playlist.variants[1].uri == "{$cdn}/high.m3u8")
        #expect(playlist.definitions.count == 1)
    }

    @Test("Define with variable references in Segment URIs")
    func defineWithSegmentRefs() {
        let playlist = MediaPlaylist(targetDuration: 6) {
            Define(name: "host", value: "https://cdn.com")
            Segment(duration: 6.0, uri: "{$host}/seg1.ts")
            Segment(duration: 6.0, uri: "{$host}/seg2.ts")
        }
        #expect(playlist.segments[0].uri == "{$host}/seg1.ts")
        #expect(playlist.segments[1].uri == "{$host}/seg2.ts")
    }

    @Test("Multiple defines in same playlist")
    func multipleDefines() {
        let playlist = MasterPlaylist {
            Define(name: "cdn", value: "https://cdn.com")
            Define(name: "path", value: "/live")
            Define(import: "auth")
            Variant(bandwidth: 800_000, uri: "low.m3u8")
        }
        #expect(playlist.definitions.count == 3)
        #expect(playlist.definitions[0].type == .value)
        #expect(playlist.definitions[1].type == .value)
        #expect(playlist.definitions[2].type == .import)
    }

    @Test("Builder output generates valid M3U8")
    func builderOutputValid() {
        let playlist = MasterPlaylist {
            Define(name: "base", value: "https://cdn.example.com")
            Variant(bandwidth: 800_000, uri: "{$base}/low.m3u8")
        }
        let m3u8 = generator.generate(.master(playlist))
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXT-X-DEFINE:"))
        #expect(m3u8.contains("NAME=\"base\""))
        #expect(m3u8.contains("#EXT-X-STREAM-INF:"))
    }

    @Test("Define(queryParam:) in master playlist")
    func defineQueryParamInMaster() {
        let playlist = MasterPlaylist {
            Define(queryParam: "token")
            Variant(bandwidth: 800_000, uri: "low.m3u8")
        }
        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "token")
        #expect(playlist.definitions[0].type == .queryParam)
    }

    @Test("Media playlist builder with Define generates M3U8")
    func mediaBuilderGeneratesM3U8() {
        let playlist = MediaPlaylist(targetDuration: 6) {
            Define(name: "p", value: "/stream")
            Segment(duration: 6.0, uri: "{$p}/seg1.ts")
        }
        let m3u8 = generator.generate(.media(playlist))
        #expect(m3u8.contains("#EXT-X-DEFINE:NAME=\"p\""))
        #expect(m3u8.contains("{$p}/seg1.ts"))
    }
}
