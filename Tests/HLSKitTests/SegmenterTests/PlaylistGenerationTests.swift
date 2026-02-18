// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PlaylistGeneration")
struct PlaylistGenerationTests {

    // MARK: - Round-Trip

    @Test("playlist — parseable by ManifestParser")
    func playlistParseable() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        #expect(playlist.segments.count == result.segmentCount)
    }

    @Test("playlist — target duration is ceil of max segment")
    func targetDurationCeiling() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        let maxDuration =
            result.mediaSegments.map(\.duration)
            .max() ?? 0
        let expectedTarget = Int(maxDuration.rounded(.up))
        #expect(playlist.targetDuration == expectedTarget)
    }

    @Test("playlist — correct segment URIs in separate mode")
    func correctSegmentURIs() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        for (i, seg) in playlist.segments.enumerated() {
            #expect(seg.uri == "segment_\(i).m4s")
        }
    }

    @Test("playlist — VOD type has ENDLIST")
    func vodHasEndlist() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        #expect(playlist.hasEndList == true)
        #expect(playlist.playlistType == .vod)
    }

    // MARK: - Byte-Range Playlist

    @Test("byte-range — correct BYTERANGE values")
    func byteRangeValues() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        for (i, seg) in playlist.segments.enumerated() {
            let expected = result.mediaSegments[i]
            #expect(seg.byteRange != nil)
            if let br = seg.byteRange {
                #expect(
                    br.length
                        == Int(expected.byteRangeLength ?? 0)
                )
            }
        }
    }

    @Test("byte-range — all segments reference same file")
    func byteRangeSameFile() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        for seg in playlist.segments {
            #expect(seg.uri == "segments.m4s")
        }
    }

    // MARK: - Map Tag

    @Test("playlist — first segment has MAP tag")
    func firstSegmentHasMap() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        let first = try #require(playlist.segments.first)
        #expect(first.map?.uri == "init.mp4")
    }

    // MARK: - A/V Playlist

    @Test("A/V — playlist generated from muxed segments")
    func avPlaylistGenerated() throws {
        let data = MP4TestDataBuilder.avMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXTINF:"))
    }
}
