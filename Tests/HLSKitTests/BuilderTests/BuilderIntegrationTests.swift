// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Builder — Generate → Parse Round-Trip")
struct BuilderIntegrationTests {

    let generator = ManifestGenerator()
    let parser = ManifestParser()

    @Test("Master builder → generate → parse")
    func masterBuilderRoundTrip() throws {
        let playlist = MasterPlaylist {
            Variant(
                bandwidth: 800_000,
                resolution: .p480,
                uri: "480p/playlist.m3u8"
            )
            Variant(
                bandwidth: 2_800_000,
                resolution: .p720,
                uri: "720p/playlist.m3u8"
            )
        }
        let m3u8 = generator.generateMaster(playlist)
        let parsed = try parser.parse(m3u8)
        guard case .master(let result) = parsed else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(result.variants.count == 2)
        #expect(result.variants[0].bandwidth == 800_000)
        #expect(result.variants[1].bandwidth == 2_800_000)
    }

    @Test("Master builder with renditions → generate → parse")
    func masterBuilderWithRenditions() throws {
        let playlist = MasterPlaylist {
            Rendition(
                type: .audio, groupId: "audio-aac",
                name: "English",
                uri: "audio/en/playlist.m3u8",
                language: "en",
                isDefault: true, autoselect: true
            )
            Variant(
                bandwidth: 2_800_000,
                resolution: .p720,
                uri: "720p/playlist.m3u8",
                codecs: "avc1.4d401f,mp4a.40.2",
                audio: "audio-aac"
            )
        }
        let m3u8 = generator.generateMaster(playlist)
        let parsed = try parser.parse(m3u8)
        guard case .master(let result) = parsed else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(result.renditions.count == 1)
        #expect(result.variants.count == 1)
        #expect(result.renditions[0].type == .audio)
    }

    @Test("Media builder → generate → parse")
    func mediaBuilderRoundTrip() throws {
        let playlist = MediaPlaylist(
            targetDuration: 6, playlistType: .vod
        ) {
            Segment(
                duration: 6.006, uri: "segment001.ts",
                title: "Episode 1"
            )
            Segment(duration: 5.839, uri: "segment002.ts")
            Segment(duration: 6.006, uri: "segment003.ts")
        }
        var vodPlaylist = playlist
        vodPlaylist.hasEndList = true
        let m3u8 = generator.generateMedia(vodPlaylist)
        let parsed = try parser.parse(m3u8)
        guard case .media(let result) = parsed else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(result.segments.count == 3)
        #expect(result.segments[0].title == "Episode 1")
        #expect(result.playlistType == .vod)
        #expect(result.hasEndList == true)
    }

    @Test("Media builder with dateranges → generate → parse")
    func mediaBuilderDateRange() throws {
        let date = Date(timeIntervalSince1970: 1_771_322_430)
        let playlist = MediaPlaylist(targetDuration: 6) {
            Segment(duration: 6.006, uri: "segment001.ts")
            DateRange(
                id: "ad-break", startDate: date,
                duration: 30.0
            )
        }
        let m3u8 = generator.generateMedia(playlist)
        let parsed = try parser.parse(m3u8)
        guard case .media(let result) = parsed else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(result.dateRanges.count == 1)
        #expect(result.dateRanges[0].id == "ad-break")
    }

    @Test("HLSEngine generate convenience")
    func engineGenerate() throws {
        let engine = HLSEngine()
        let playlist = MasterPlaylist {
            Variant(
                bandwidth: 800_000, uri: "480p/playlist.m3u8"
            )
        }
        let m3u8 = engine.generate(playlist)
        let parsed = try engine.parse(m3u8)
        guard case .master(let result) = parsed else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(result.variants.count == 1)
    }

    @Test("HLSEngine regenerate round-trip")
    func engineRegenerate() throws {
        let engine = HLSEngine()
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            #EXT-X-ENDLIST
            """
        let regenerated = try engine.regenerate(m3u8)
        #expect(regenerated.contains("#EXTM3U"))
        #expect(regenerated.contains("segment001.ts"))
        #expect(regenerated.contains("#EXT-X-ENDLIST"))
    }
}
