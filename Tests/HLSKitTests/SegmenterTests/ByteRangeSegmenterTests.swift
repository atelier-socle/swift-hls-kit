// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ByteRangeSegmenter")
struct ByteRangeSegmenterTests {

    // MARK: - Byte-Range Offsets

    @Test("byte-range — segments have offset and length")
    func segmentsHaveByteRange() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        for segment in result.mediaSegments {
            #expect(segment.byteRangeOffset != nil)
            #expect(segment.byteRangeLength != nil)
        }
    }

    @Test("byte-range — offsets are contiguous")
    func offsetsContiguous() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        var expectedOffset: UInt64 = 0
        for segment in result.mediaSegments {
            let offset = try #require(segment.byteRangeOffset)
            let length = try #require(segment.byteRangeLength)
            #expect(offset == expectedOffset)
            expectedOffset = offset + length
        }
    }

    @Test("byte-range — first segment starts at 0")
    func firstSegmentOffset() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let first = try #require(result.mediaSegments.first)
        #expect(first.byteRangeOffset == 0)
    }

    @Test("byte-range — length matches data size")
    func lengthMatchesData() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        for segment in result.mediaSegments {
            let length = try #require(segment.byteRangeLength)
            #expect(length == UInt64(segment.data.count))
        }
    }

    // MARK: - Byte-Range Playlist

    @Test("byte-range — playlist has BYTERANGE tags")
    func playlistHasByteRange() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-BYTERANGE:"))
    }

    @Test("byte-range — all segments reference same URI")
    func allSegmentsSameURI() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        let lines = playlist.components(separatedBy: "\n")
        let segmentURIs = lines.filter {
            $0.hasSuffix(".m4s") && !$0.hasPrefix("#")
        }
        for uri in segmentURIs {
            #expect(uri == "segments.m4s")
        }
    }

    // MARK: - Separate Files Mode

    @Test("separate files — no byte-range fields")
    func separateFilesNoByteRange() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let config = SegmentationConfig()
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        for segment in result.mediaSegments {
            #expect(segment.byteRangeOffset == nil)
            #expect(segment.byteRangeLength == nil)
        }
    }

    @Test("separate files — no BYTERANGE in playlist")
    func separateFilesNoByteRangePlaylist() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let playlist = try #require(result.playlist)
        #expect(!playlist.contains("#EXT-X-BYTERANGE:"))
    }
}
