// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TSSegmenter")
struct TSSegmenterTests {

    // MARK: - Video-Only

    @Test("Segment video-only MP4 → .ts segments")
    func videoOnlySegmentation() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let segmenter = TSSegmenter()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try segmenter.segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
    }

    @Test("Each segment starts with PAT/PMT")
    func eachSegmentStartsWithPATPMT() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        for segment in result.mediaSegments {
            #expect(segment.data.count >= 188 * 2)
            // First byte is sync
            #expect(segment.data[0] == 0x47)
            // First packet PID = PAT (0x0000)
            let patPID =
                UInt16(segment.data[1] & 0x1F) << 8
                | UInt16(segment.data[2])
            #expect(patPID == 0x0000)
            // Second packet PID = PMT (0x0100)
            let pmtPID =
                UInt16(segment.data[189] & 0x1F) << 8
                | UInt16(segment.data[190])
            #expect(pmtPID == 0x0100)
        }
    }

    @Test("No init segment (empty Data)")
    func noInitSegment() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.initSegment.isEmpty)
        #expect(!result.hasInitSegment)
    }

    @Test("Segment count matches expected")
    func segmentCount() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.targetSegmentDuration = 6.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        // 90 samples * 3000 / 90000 = 3s total
        // With 6s target and keyframes every 30 samples (1s),
        // expect ~1 segment
        #expect(result.segmentCount >= 1)
    }

    @Test("Total duration ≈ source duration")
    func totalDuration() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let expected = 3.0  // 90 * 3000 / 90000
        let tolerance = 0.1
        #expect(abs(result.totalDuration - expected) < tolerance)
    }

    @Test("Custom target duration works")
    func customTargetDuration() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.targetSegmentDuration = 1.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 2)
    }

    // MARK: - Muxed Segmentation

    @Test("Segment video + audio → muxed .ts segments")
    func muxedSegmentation() throws {
        let data = TSTestDataBuilder.avMP4WithAvcCAndEsds()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        // Each segment should be valid TS
        for seg in result.mediaSegments {
            #expect(seg.data.count % 188 == 0)
        }
    }

    // MARK: - Playlist

    @Test("Generated playlist has no EXT-X-MAP")
    func playlistNoMap() throws {
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

    @Test("Generated playlist version >= 3")
    func playlistVersion() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-VERSION:3"))
    }

    // MARK: - Segment Filenames

    @Test("Segment filenames use .ts extension")
    func segmentFilenames() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        for seg in result.mediaSegments {
            #expect(seg.filename.hasSuffix(".ts"))
        }
    }

    // MARK: - Config Preserved

    @Test("Config preserved in result")
    func configPreserved() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.config.containerFormat == .mpegTS)
    }
}
