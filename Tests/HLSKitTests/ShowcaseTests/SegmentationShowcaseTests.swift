// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - fMP4 Segmentation (API surface)

@Suite("Segmentation Showcase — fMP4")
struct FMP4SegmentationShowcase {

    /// Minimal synthetic MP4 (< 1s, 3 samples)
    private func tinyMP4() -> Data {
        MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 3,
            keyframeInterval: 1,
            sampleDelta: 3000,
            timescale: 90000
        )
    }

    @Test("Segment MP4 to fMP4 — creates init segment + media segments")
    func segmentToFMP4() throws {
        let config = SegmentationConfig(containerFormat: .fragmentedMP4)
        let result = try MP4Segmenter().segment(data: tinyMP4(), config: config)

        #expect(result.hasInitSegment == true)
        #expect(result.initSegment.isEmpty == false)
        #expect(result.segmentCount > 0)
        #expect(result.totalDuration > 0)
    }

    @Test("fMP4 segment config — target duration, format, playlist generation")
    func fmp4Config() throws {
        let config = SegmentationConfig(
            targetSegmentDuration: 4.0,
            containerFormat: .fragmentedMP4,
            generatePlaylist: true,
            playlistType: .vod
        )
        let result = try MP4Segmenter().segment(data: tinyMP4(), config: config)

        #expect(result.config.targetSegmentDuration == 4.0)
        #expect(result.config.containerFormat == .fragmentedMP4)
        #expect(result.playlist != nil)
    }

    @Test("fMP4 byte-range segments — single file with byte ranges")
    func fmp4ByteRange() throws {
        let config = SegmentationConfig(
            containerFormat: .fragmentedMP4,
            outputMode: .byteRange
        )
        let result = try MP4Segmenter().segment(data: tinyMP4(), config: config)

        #expect(result.segmentCount > 0)
        for segment in result.mediaSegments {
            #expect(segment.byteRangeLength != nil)
        }
    }

    @Test("fMP4 playlist auto-generated — valid M3U8 with EXT-X-MAP")
    func fmp4Playlist() throws {
        let config = SegmentationConfig(
            containerFormat: .fragmentedMP4,
            generatePlaylist: true
        )
        let result = try MP4Segmenter().segment(data: tinyMP4(), config: config)

        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-MAP"))
        #expect(playlist.contains("#EXTINF"))
        #expect(playlist.contains("#EXT-X-ENDLIST"))
    }
}

// MARK: - MPEG-TS Segmentation

@Suite("Segmentation Showcase — MPEG-TS")
struct TSSegmentationShowcase {

    @Test("TSSegmenter — instantiation and config acceptance")
    func tsSegmenterAPI() {
        let segmenter = TSSegmenter()
        let config = SegmentationConfig(containerFormat: .mpegTS)
        #expect(config.containerFormat == .mpegTS)
        _ = segmenter
    }

    @Test("MPEG-TS config — defaultHLSVersion and segment pattern")
    func tsConfigProperties() {
        let format = SegmentationConfig.ContainerFormat.mpegTS
        #expect(format.defaultHLSVersion == 3)
        #expect(format.defaultSegmentPattern.hasSuffix(".ts"))

        let config = SegmentationConfig(
            targetSegmentDuration: 8.0,
            containerFormat: .mpegTS,
            generatePlaylist: true,
            playlistType: .vod
        )
        #expect(config.targetSegmentDuration == 8.0)
        #expect(config.generatePlaylist == true)
        #expect(config.playlistType == .vod)
    }
}

// MARK: - Unified API (config/API surface — no heavy segmentation)

@Suite("Segmentation Showcase — Unified API")
struct UnifiedSegmentationShowcase {

    @Test("SegmentationConfig defaults — sensible out-of-the-box values")
    func configDefaults() {
        let config = SegmentationConfig()
        #expect(config.targetSegmentDuration == 6.0)
        #expect(config.containerFormat == .fragmentedMP4)
        #expect(config.outputMode == .separateFiles)
        #expect(config.generatePlaylist == true)
        #expect(config.playlistType == .vod)
        #expect(config.includeAudio == true)
        #expect(config.initSegmentName == "init.mp4")
        #expect(config.playlistName == "playlist.m3u8")
    }

    @Test("ContainerFormat — default segment patterns and HLS versions")
    func containerFormatProperties() {
        #expect(SegmentationConfig.ContainerFormat.fragmentedMP4.defaultHLSVersion == 7)
        #expect(SegmentationConfig.ContainerFormat.mpegTS.defaultHLSVersion == 3)
        #expect(
            SegmentationConfig.ContainerFormat.fragmentedMP4
                .defaultSegmentPattern.hasSuffix(".m4s")
        )
        #expect(
            SegmentationConfig.ContainerFormat.mpegTS
                .defaultSegmentPattern.hasSuffix(".ts")
        )
    }

    @Test("SegmentationConfig — custom config properties propagate")
    func customConfig() {
        let config = SegmentationConfig(
            targetSegmentDuration: 10.0,
            containerFormat: .mpegTS,
            outputMode: .byteRange,
            generatePlaylist: false,
            playlistType: .event,
            hlsVersion: 4
        )
        #expect(config.targetSegmentDuration == 10.0)
        #expect(config.containerFormat == .mpegTS)
        #expect(config.outputMode == .byteRange)
        #expect(config.generatePlaylist == false)
        #expect(config.playlistType == .event)
        #expect(config.hlsVersion == 4)
    }

    @Test("SegmentationResult — computed properties from MediaSegmentOutput")
    func segmentResultProperties() throws {
        let tinyMP4 = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 3,
            keyframeInterval: 1,
            sampleDelta: 3000,
            timescale: 90000
        )
        let result = try MP4Segmenter().segment(data: tinyMP4)

        #expect(result.segmentCount == result.mediaSegments.count)
        let sumDuration = result.mediaSegments.reduce(0.0) { $0 + $1.duration }
        #expect(sumDuration > 0)
        #expect(abs(sumDuration - result.totalDuration) < 0.001)
    }
}
