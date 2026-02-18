// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TSSegmenter Coverage")
struct TSSegmenterCoverageTests {

    // MARK: - URL-based segmentation

    @Test("segment(url:) loads and segments from file")
    func segmentFromURL() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(
            "test_\(UUID().uuidString).mp4"
        )
        try data.write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            url: fileURL, config: config
        )
        #expect(result.segmentCount > 0)
    }

    @Test("segment(url:) with invalid URL throws ioError")
    func segmentInvalidURL() {
        let badURL = URL(fileURLWithPath: "/nonexistent.mp4")
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        #expect(throws: MP4Error.self) {
            try TSSegmenter().segment(
                url: badURL, config: config
            )
        }
    }

    // MARK: - segmentToDirectory

    @Test("segmentToDirectory writes separate .ts files")
    func segmentToDirectorySeparate() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segmentToDirectory(
            data: data, outputDirectory: tempDir,
            config: config
        )
        #expect(result.segmentCount > 0)
        for seg in result.mediaSegments {
            let fileURL = tempDir.appendingPathComponent(
                seg.filename
            )
            #expect(
                FileManager.default.fileExists(
                    atPath: fileURL.path
                )
            )
        }
        let playlistURL = tempDir.appendingPathComponent(
            config.playlistName
        )
        #expect(
            FileManager.default.fileExists(
                atPath: playlistURL.path
            )
        )
    }

    @Test("segmentToDirectory writes byte-range file")
    func segmentToDirectoryByteRange() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.outputMode = .byteRange
        config.targetSegmentDuration = 1.0
        let result = try TSSegmenter().segmentToDirectory(
            data: data, outputDirectory: tempDir,
            config: config
        )
        #expect(result.segmentCount > 0)
        let segURL = tempDir.appendingPathComponent(
            "segments.ts"
        )
        #expect(
            FileManager.default.fileExists(
                atPath: segURL.path
            )
        )
    }

    @Test("segmentToDirectory with no playlist")
    func segmentToDirectoryNoPlaylist() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.generatePlaylist = false
        let result = try TSSegmenter().segmentToDirectory(
            data: data, outputDirectory: tempDir,
            config: config
        )
        #expect(result.segmentCount > 0)
        #expect(result.playlist == nil)
        let playlistURL = tempDir.appendingPathComponent(
            config.playlistName
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: playlistURL.path
            )
        )
    }

    // MARK: - segmentFilename edge case

    @Test("segmentFilename without %d returns pattern as-is")
    func segmentFilenameNoPlaceholder() {
        let segmenter = TSSegmenter()
        let name = segmenter.segmentFilename(
            pattern: "fixed.ts", index: 5
        )
        #expect(name == "fixed.ts")
    }

    // MARK: - Audio-only segmentation

    @Test("Audio-only MP4 → audio-only TS segments")
    func audioOnlySegmentation() throws {
        let data = TSTestDataBuilder.audioOnlyMP4WithEsds()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        let m3u8 = try #require(result.playlist)
        #expect(m3u8.contains("#EXTM3U"))
    }

    // MARK: - ContainerFormat defaults

    @Test("SegmentationConfig mpegTS defaults")
    func mpegTSDefaults() {
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        #expect(config.segmentNamePattern == "segment_%d.ts")
        #expect(config.hlsVersion == 3)
    }

    @Test("SegmentationConfig fMP4 defaults")
    func fmp4Defaults() {
        let config = SegmentationConfig(
            containerFormat: .fragmentedMP4
        )
        #expect(
            config.segmentNamePattern == "segment_%d.m4s"
        )
        #expect(config.hlsVersion == 7)
    }

    @Test("ContainerFormat defaultSegmentPattern")
    func containerFormatPatterns() {
        let ts = SegmentationConfig.ContainerFormat.mpegTS
        let fmp4 =
            SegmentationConfig.ContainerFormat.fragmentedMP4
        #expect(ts.defaultSegmentPattern == "segment_%d.ts")
        #expect(
            fmp4.defaultSegmentPattern == "segment_%d.m4s"
        )
        #expect(ts.defaultHLSVersion == 3)
        #expect(fmp4.defaultHLSVersion == 7)
    }

    @Test("SegmentationConfig Hashable")
    func configHashable() {
        let c1 = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let c2 = SegmentationConfig(
            containerFormat: .mpegTS
        )
        #expect(c1 == c2)
        #expect(c1.hashValue == c2.hashValue)
    }
}
