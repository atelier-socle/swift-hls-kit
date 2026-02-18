// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SegmenterCoverage")
struct SegmenterCoverageTests {

    // MARK: - segmentToDirectory (separate files)

    @Test("segmentToDirectory — writes init, segments, and playlist")
    func segmentToDirectorySeparate() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "hls-test-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let segmenter = MP4Segmenter()
        let result = try segmenter.segmentToDirectory(
            data: data, outputDirectory: tempDir
        )

        // Verify init segment written
        let initURL = tempDir.appendingPathComponent("init.mp4")
        #expect(
            FileManager.default.fileExists(atPath: initURL.path)
        )

        // Verify media segments written
        for seg in result.mediaSegments {
            let segURL = tempDir.appendingPathComponent(
                seg.filename
            )
            #expect(
                FileManager.default.fileExists(
                    atPath: segURL.path
                )
            )
        }

        // Verify playlist written
        let playlistURL = tempDir.appendingPathComponent(
            "playlist.m3u8"
        )
        #expect(
            FileManager.default.fileExists(
                atPath: playlistURL.path
            )
        )
    }

    // MARK: - segmentToDirectory (byte-range)

    @Test(
        "segmentToDirectory — byte-range writes combined file"
    )
    func segmentToDirectoryByteRange() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "hls-test-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let segmenter = MP4Segmenter()
        let result = try segmenter.segmentToDirectory(
            data: data, outputDirectory: tempDir,
            config: config
        )

        // Verify combined segments file
        let segFile = tempDir.appendingPathComponent(
            "segments.m4s"
        )
        #expect(
            FileManager.default.fileExists(atPath: segFile.path)
        )

        // Verify init segment
        let initURL = tempDir.appendingPathComponent("init.mp4")
        #expect(
            FileManager.default.fileExists(atPath: initURL.path)
        )

        // Verify playlist
        let playlistURL = tempDir.appendingPathComponent(
            "playlist.m3u8"
        )
        #expect(
            FileManager.default.fileExists(
                atPath: playlistURL.path
            )
        )

        #expect(result.segmentCount > 0)
    }

    // MARK: - segmentToDirectory (no playlist)

    @Test(
        "segmentToDirectory — no playlist when disabled"
    )
    func segmentToDirectoryNoPlaylist() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "hls-test-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var config = SegmentationConfig()
        config.generatePlaylist = false
        let segmenter = MP4Segmenter()
        let result = try segmenter.segmentToDirectory(
            data: data, outputDirectory: tempDir,
            config: config
        )

        let playlistURL = tempDir.appendingPathComponent(
            "playlist.m3u8"
        )
        #expect(
            !FileManager.default.fileExists(
                atPath: playlistURL.path
            )
        )
        #expect(result.playlist == nil)
    }

    // MARK: - segment(url:) error paths

    @Test("segment(url:) — invalid URL throws ioError")
    func segmentURLInvalidThrows() {
        let invalidURL = URL(
            fileURLWithPath: "/nonexistent/path/file.mp4"
        )
        let segmenter = MP4Segmenter()
        #expect(throws: MP4Error.self) {
            try segmenter.segment(url: invalidURL)
        }
    }

    // MARK: - No video track

    @Test("segment — audio-only MP4 throws invalidMP4")
    func audioOnlyThrows() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let audioTrack = MP4TestDataBuilder.audioTrack(
            trackId: 1, duration: 44100
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 44100, duration: 44100
                ),
                audioTrack
            ]
        )
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat",
            payload: Data(repeating: 0, count: 16)
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        data.append(mdatBox)

        let segmenter = MP4Segmenter()
        #expect(throws: MP4Error.self) {
            try segmenter.segment(data: data)
        }
    }

    // MARK: - HLSEngine.segmentToDirectory

    @Test("HLSEngine.segmentToDirectory — works")
    func engineSegmentToDirectory() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "hls-test-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: tempDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let engine = HLSEngine()
        let result = try engine.segmentToDirectory(
            data: data, outputDirectory: tempDir
        )
        #expect(result.segmentCount > 0)
    }
}
