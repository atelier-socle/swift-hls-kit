// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HLSEngineSegment")
struct HLSEngineSegmentTests {

    // MARK: - HLSEngine.segment(data:)

    @Test("HLSEngine.segment(data:) — works")
    func segmentData() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let engine = HLSEngine()
        let result = try engine.segment(data: data)
        #expect(!result.initSegment.isEmpty)
        #expect(result.segmentCount > 0)
        #expect(result.playlist != nil)
    }

    @Test("HLSEngine.segment(data:config:) — custom config")
    func segmentDataWithConfig() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let engine = HLSEngine()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        let result = try engine.segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 2)
    }

    // MARK: - HLSEngine.segment(url:)

    @Test("HLSEngine.segment(url:) — works with temp file")
    func segmentURL() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(
            "test_\(UUID().uuidString).mp4"
        )
        try data.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        let engine = HLSEngine()
        let result = try engine.segment(url: tempFile)
        #expect(!result.initSegment.isEmpty)
        #expect(result.segmentCount > 0)
    }

    // MARK: - End-to-End

    @Test("end-to-end — segment then parse playlist")
    func endToEnd() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let engine = HLSEngine()
        let result = try engine.segment(data: data)
        let m3u8 = try #require(result.playlist)

        // Parse the generated playlist
        let manifest = try engine.parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }

        // Verify structure
        #expect(playlist.segments.count == result.segmentCount)
        #expect(playlist.hasEndList == true)
        #expect(playlist.playlistType == .vod)

        // Verify each segment has valid data
        for segment in result.mediaSegments {
            let moof = try MP4SegmentTestHelper.findBox(
                type: "moof", in: segment.data
            )
            #expect(moof != nil)
        }
    }

    @Test("end-to-end — A/V muxed segment then parse playlist")
    func endToEndAV() throws {
        let data = MP4TestDataBuilder.avMP4WithData()
        let engine = HLSEngine()
        let result = try engine.segment(data: data)
        let m3u8 = try #require(result.playlist)

        let manifest = try engine.parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        #expect(playlist.segments.count == result.segmentCount)
    }

    @Test("end-to-end — byte-range mode round-trip")
    func endToEndByteRange() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let engine = HLSEngine()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try engine.segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)

        let manifest = try engine.parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        #expect(playlist.segments.count == result.segmentCount)
        for seg in playlist.segments {
            #expect(seg.byteRange != nil)
        }
    }
}
