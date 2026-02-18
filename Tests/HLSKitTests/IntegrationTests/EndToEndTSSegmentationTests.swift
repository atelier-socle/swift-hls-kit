// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("End-to-End TS Segmentation")
struct EndToEndTSSegmentationTests {

    // MARK: - Video-only TS scenarios

    @Test("TS segment short video (3 seconds)")
    func shortVideo() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        for seg in result.mediaSegments {
            // PAT starts with 0x47
            #expect(seg.data[0] == 0x47)
            // Second packet is PMT
            #expect(seg.data[188] == 0x47)
        }
    }

    @Test("TS segment long video (30s, 5 segments at 6s target)")
    func longVideo() throws {
        let videoConfig = TSTestDataBuilder.VideoConfig(
            samples: 900,
            keyframeInterval: 90,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: videoConfig
        )
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.targetSegmentDuration = 6.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount == 5)
        let total = result.mediaSegments.map(\.duration)
            .reduce(0, +)
        #expect(abs(total - 30.0) < 0.5)
    }

    @Test("TS segment with non-uniform GOPs")
    func nonUniformGops() throws {
        let videoConfig = TSTestDataBuilder.VideoConfig(
            samples: 120,
            keyframeInterval: 40,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: videoConfig
        )
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.targetSegmentDuration = 2.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 2)
    }

    @Test("TS single-GOP video → single segment")
    func singleGop() throws {
        let videoConfig = TSTestDataBuilder.VideoConfig(
            samples: 30,
            keyframeInterval: 30,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: videoConfig
        )
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount == 1)
    }

    // MARK: - Muxed TS scenarios

    @Test("TS muxed video + audio: both PIDs present")
    func muxedBothPIDs() throws {
        let data = TSTestDataBuilder.avMP4WithAvcCAndEsds()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        for seg in result.mediaSegments {
            var hasVideo = false
            var hasAudio = false
            let packetCount = seg.data.count / 188
            for p in 0..<packetCount {
                let offset = p * 188
                let pid =
                    UInt16(seg.data[offset + 1] & 0x1F) << 8
                    | UInt16(seg.data[offset + 2])
                if pid == TSPacket.PID.video { hasVideo = true }
                if pid == TSPacket.PID.audio { hasAudio = true }
            }
            #expect(hasVideo)
            #expect(hasAudio)
        }
    }

    @Test("TS audio-only segmentation")
    func audioOnly() throws {
        let data = TSTestDataBuilder.audioOnlyMP4WithEsds()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        for seg in result.mediaSegments {
            #expect(seg.data[0] == 0x47)
            let packetCount = seg.data.count / 188
            var hasAudio = false
            for p in 0..<packetCount {
                let offset = p * 188
                let pid =
                    UInt16(seg.data[offset + 1] & 0x1F) << 8
                    | UInt16(seg.data[offset + 2])
                if pid == TSPacket.PID.audio {
                    hasAudio = true
                }
                #expect(pid != TSPacket.PID.video)
            }
            #expect(hasAudio)
        }
    }

    // MARK: - TS byte-range mode

    @Test("TS byte-range: offsets contiguous")
    func byteRangeContiguous() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.outputMode = .byteRange
        config.targetSegmentDuration = 1.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        var expectedOffset: UInt64 = 0
        for seg in result.mediaSegments {
            #expect(seg.byteRangeOffset == expectedOffset)
            #expect(
                seg.byteRangeLength == UInt64(seg.data.count)
            )
            expectedOffset += UInt64(seg.data.count)
        }
    }

    @Test("TS byte-range: playlist has BYTERANGE tags")
    func byteRangePlaylist() throws {
        let videoConfig = TSTestDataBuilder.VideoConfig(
            samples: 90,
            keyframeInterval: 30,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: videoConfig
        )
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.outputMode = .byteRange
        config.targetSegmentDuration = 1.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let playlist = try #require(result.playlist)
        if result.segmentCount > 1 {
            #expect(playlist.contains("#EXT-X-BYTERANGE:"))
        }
    }

    // MARK: - TS playlist validation

    @Test("TS playlist round-trip: generate → parse → verify")
    func playlistRoundTrip() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        #expect(playlist.segments.count == result.segmentCount)
    }

    @Test("TS playlist validates with HLSValidator")
    func playlistValidates() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        let validator = HLSValidator()
        let report = try validator.validateString(m3u8)
        #expect(report.errors.isEmpty)
    }

    @Test("TS playlist: NO EXT-X-MAP tag")
    func noMapTag() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        #expect(!m3u8.contains("EXT-X-MAP"))
    }

    @Test("TS playlist: correct target duration")
    func targetDuration() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:"))
    }

    @Test("TS playlist: segment URIs end with .ts")
    func segmentURIs() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        let lines = m3u8.components(separatedBy: "\n")
        let uris = lines.filter {
            !$0.hasPrefix("#") && !$0.isEmpty
        }
        for uri in uris {
            #expect(uri.hasSuffix(".ts"))
        }
    }

}
