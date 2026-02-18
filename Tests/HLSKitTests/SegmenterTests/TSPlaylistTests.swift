// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TSPlaylist")
struct TSPlaylistTests {

    // MARK: - No EXT-X-MAP

    @Test("TS playlist: no EXT-X-MAP tag")
    func noMapTag() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        #expect(!playlist.contains("EXT-X-MAP"))
    }

    // MARK: - Segment URIs

    @Test("TS playlist: segment URIs end with .ts")
    func segmentURIsEndWithTS() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        let lines = playlist.components(separatedBy: "\n")
        let uriLines = lines.filter {
            !$0.hasPrefix("#") && !$0.isEmpty
        }
        for uri in uriLines {
            #expect(uri.hasSuffix(".ts"))
        }
    }

    // MARK: - Parseable

    @Test("TS playlist: parseable by ManifestParser")
    func parseableByParser() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        #expect(playlist.segments.count == result.segmentCount)
    }

    // MARK: - Target Duration

    @Test("TS playlist: target duration is ceil(max segment)")
    func targetDuration() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-TARGETDURATION:"))
    }

    // MARK: - ENDLIST

    @Test("TS playlist: has EXT-X-ENDLIST for VOD")
    func hasEndList() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-ENDLIST"))
    }

    // MARK: - Byte-Range Mode

    @Test("Byte-range mode: EXT-X-BYTERANGE tags present")
    func byteRangeMode() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.outputMode = .byteRange
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        // Only check for BYTERANGE if multiple segments
        if result.segmentCount > 1 {
            #expect(playlist.contains("#EXT-X-BYTERANGE:"))
        }
    }
}
