// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Audio-Only Segmentation

@Suite("Audio-Only Segmentation")
struct AudioOnlySegmentationTests {

    @Test("audio-only MP4 segments within target duration")
    func audioOnlyRespectsDuration() throws {
        let targetDuration: Double = 6.0
        let config = SegmentationConfig(
            targetSegmentDuration: targetDuration
        )
        let data = TSTestDataBuilder.audioOnlyMP4WithEsds(
            config: .init(
                samples: 300,
                sampleDelta: 1024,
                timescale: 44100,
                sampleSize: 50
            )
        )
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 1)
        #expect(!result.initSegment.isEmpty)
        for (index, segment) in result.mediaSegments.dropLast()
            .enumerated()
        {
            #expect(
                segment.duration >= targetDuration - 1.0,
                "Segment \(index) too short: \(segment.duration)s"
            )
            #expect(
                segment.duration <= targetDuration + 1.0,
                "Segment \(index) too long: \(segment.duration)s"
            )
        }
    }

    @Test("audio-only segmentation generates playlist")
    func audioOnlyPlaylist() throws {
        let data = TSTestDataBuilder.audioOnlyMP4WithEsds()
        var config = SegmentationConfig()
        config.generatePlaylist = true
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-TARGETDURATION:"))
    }

    @Test("forceAllSync ignores stss for duration-based cuts")
    func forceAllSyncCutsDuration() {
        // 3000 samples × 1024 / 44100 ≈ 69.7s → ~11 segments
        let sampleCount = 3000
        let delta: UInt32 = 1024
        let timescale: UInt32 = 44100
        let entries = [
            TimeToSampleEntry(
                sampleCount: UInt32(sampleCount),
                sampleDelta: delta
            )
        ]
        let table = SampleTable(
            timeToSample: entries,
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(sampleCount),
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [UInt32](
                repeating: 50, count: sampleCount
            ),
            uniformSampleSize: 0,
            chunkOffsets: [0],
            syncSamples: [1, 150]
        )
        let locator = SampleLocator(
            sampleTable: table, timescale: timescale
        )
        let chaptered = locator.calculateSegments(
            targetDuration: 6.0
        )
        #expect(chaptered.count <= 2)
        let forced = locator.calculateSegments(
            targetDuration: 6.0, forceAllSync: true
        )
        #expect(forced.count > 2)
        for seg in forced.dropLast() {
            #expect(seg.duration >= 5.0)
            #expect(seg.duration <= 7.0)
        }
    }
}

// MARK: - TS Segmenter Track Filtering

@Suite("TS Segmenter Track Filtering")
struct TSSegmenterTrackFilteringTests {

    @Test("TS segmenter skips cover art video track")
    func skipsJpegCoverArt() throws {
        let data = CoverArtMP4Builder.buildWithEsds()
        let result = try TSSegmenter().segment(data: data)
        #expect(result.segmentCount > 0)
    }

    @Test("TS segmenter handles audio-only after filtering")
    func audioOnlyAfterFilter() throws {
        let data = TSTestDataBuilder.audioOnlyMP4WithEsds()
        let result = try TSSegmenter().segment(data: data)
        #expect(result.segmentCount > 0)
    }
}

// MARK: - Segmenter Cover Art Filtering

@Suite("Segmenter Cover Art Filtering")
struct SegmenterCoverArtFilteringTests {

    @Test("MP4Segmenter filters cover art from init segment")
    func initSegmentSkipsCoverArt() throws {
        let data = CoverArtMP4Builder.buildSimple()
        let result = try MP4Segmenter().segment(data: data)
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let moov = try #require(boxes.first { $0.type == "moov" })
        let traks = moov.children.filter { $0.type == "trak" }
        #expect(traks.count == 1)
    }

    @Test("MP4Segmenter handles audio + cover art without crash")
    func audioWithCoverArtSegments() throws {
        let data = CoverArtMP4Builder.buildSimple()
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.segmentCount > 0)
        #expect(!result.initSegment.isEmpty)
    }
}

// MARK: - Resolution Codable Formats

@Suite("Resolution Codable Formats")
struct ResolutionCodableFormatsTests {

    @Test("decode resolution from string WxH format")
    func decodeStringFormat() throws {
        let json = Data("\"1280x720\"".utf8)
        let r = try JSONDecoder().decode(
            Resolution.self, from: json
        )
        #expect(r.width == 1280)
        #expect(r.height == 720)
    }

    @Test("decode resolution from object format")
    func decodeObjectFormat() throws {
        let json = Data(
            "{\"width\":1920,\"height\":1080}".utf8
        )
        let r = try JSONDecoder().decode(
            Resolution.self, from: json
        )
        #expect(r.width == 1920)
        #expect(r.height == 1080)
    }

    @Test("decode resolution string in variant config")
    func decodeInVariantConfig() throws {
        let json = """
            {
                "bandwidth": 2800000,
                "resolution": "1280x720",
                "uri": "720p/playlist.m3u8",
                "codecs": "avc1.64001f,mp4a.40.2"
            }
            """
        let v = try JSONDecoder().decode(
            VariantJSON.self, from: Data(json.utf8)
        )
        #expect(v.resolution.width == 1280)
        #expect(v.resolution.height == 720)
    }

    @Test("encode resolution preserves object format")
    func encodePreservesObject() throws {
        let resolution = Resolution(width: 1280, height: 720)
        let data = try JSONEncoder().encode(resolution)
        let decoded = try JSONDecoder().decode(
            Resolution.self, from: data
        )
        #expect(decoded == resolution)
    }

    @Test("decode invalid string format throws")
    func invalidStringThrows() {
        let json = Data("\"not-a-resolution\"".utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(
                Resolution.self, from: json
            )
        }
    }

    @Test("decode resolution roundtrip string and object")
    func roundtripBothFormats() throws {
        let fromString = try JSONDecoder().decode(
            Resolution.self, from: Data("\"3840x2160\"".utf8)
        )
        let fromObject = try JSONDecoder().decode(
            Resolution.self,
            from: Data("{\"width\":3840,\"height\":2160}".utf8)
        )
        #expect(fromString == fromObject)
        #expect(fromString == Resolution.p2160)
    }

    private struct VariantJSON: Codable {
        let bandwidth: Int
        let resolution: Resolution
        let uri: String
        let codecs: String
    }
}
