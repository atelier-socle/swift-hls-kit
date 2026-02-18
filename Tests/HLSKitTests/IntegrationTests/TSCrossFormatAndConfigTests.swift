// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TS Cross-Format and Configuration")
struct TSCrossFormatAndConfigTests {

    // MARK: - Cross-format comparison

    @Test("Same source, fMP4 vs TS: same segment count")
    func crossFormatSegmentCount() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let fmp4Config = SegmentationConfig(
            containerFormat: .fragmentedMP4
        )
        let tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let fmp4Result = try MP4Segmenter().segment(
            data: data, config: fmp4Config
        )
        let tsResult = try TSSegmenter().segment(
            data: data, config: tsConfig
        )
        #expect(
            fmp4Result.segmentCount == tsResult.segmentCount
        )
    }

    @Test("Same source, fMP4 vs TS: similar total duration")
    func crossFormatDuration() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let fmp4Config = SegmentationConfig(
            containerFormat: .fragmentedMP4
        )
        let tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let fmp4Result = try MP4Segmenter().segment(
            data: data, config: fmp4Config
        )
        let tsResult = try TSSegmenter().segment(
            data: data, config: tsConfig
        )
        let fmp4Total = fmp4Result.mediaSegments
            .map(\.duration).reduce(0, +)
        let tsTotal = tsResult.mediaSegments
            .map(\.duration).reduce(0, +)
        #expect(abs(fmp4Total - tsTotal) < 0.5)
    }

    @Test("Same source, fMP4 vs TS: both playlists parseable")
    func crossFormatPlaylistsParseable() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let fmp4Config = SegmentationConfig(
            containerFormat: .fragmentedMP4
        )
        let tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let fmp4Result = try MP4Segmenter().segment(
            data: data, config: fmp4Config
        )
        let tsResult = try TSSegmenter().segment(
            data: data, config: tsConfig
        )
        let fmp4M3u8 = try #require(fmp4Result.playlist)
        let tsM3u8 = try #require(tsResult.playlist)
        let parser = ManifestParser()
        let fmp4Manifest = try parser.parse(fmp4M3u8)
        let tsManifest = try parser.parse(tsM3u8)
        guard case .media = fmp4Manifest else {
            #expect(
                Bool(false), "Expected fMP4 media playlist"
            )
            return
        }
        guard case .media = tsManifest else {
            #expect(
                Bool(false), "Expected TS media playlist"
            )
            return
        }
    }

    // MARK: - TS configuration tests

    @Test("TS custom target duration: 2 seconds")
    func customTargetDuration() throws {
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
        config.targetSegmentDuration = 2.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 2)
        let maxDuration =
            result.mediaSegments
            .map(\.duration).max() ?? 0
        #expect(maxDuration <= 4.0)
    }

    @Test("TS custom segment naming: 'chunk_%d.ts'")
    func customSegmentNaming() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.segmentNamePattern = "chunk_%d.ts"
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        for seg in result.mediaSegments {
            #expect(seg.filename.hasPrefix("chunk_"))
            #expect(seg.filename.hasSuffix(".ts"))
        }
    }

    @Test("TS playlist generation disabled → nil")
    func playlistDisabled() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.generatePlaylist = false
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        #expect(result.playlist == nil)
    }

    @Test("TS includeAudio false → video-only from muxed")
    func includeAudioFalse() throws {
        let data = TSTestDataBuilder.avMP4WithAvcCAndEsds()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.includeAudio = false
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        for seg in result.mediaSegments {
            let packetCount = seg.data.count / 188
            for p in 0..<packetCount {
                let offset = p * 188
                let pid =
                    UInt16(seg.data[offset + 1] & 0x1F) << 8
                    | UInt16(seg.data[offset + 2])
                #expect(pid != TSPacket.PID.audio)
            }
        }
    }
}
