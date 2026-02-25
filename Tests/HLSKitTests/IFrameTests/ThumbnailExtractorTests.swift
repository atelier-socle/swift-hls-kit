// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

/// Mock image provider returning deterministic JPEG-like data.
struct MockImageProvider: ThumbnailImageProvider {

    func extractThumbnail(
        from segmentData: Data,
        at timestamp: TimeInterval,
        size: ThumbnailExtractor.ThumbnailSize
    ) async throws -> Data {
        // Return data whose size encodes the segment size for verification.
        Data(repeating: 0xFF, count: segmentData.count / 10)
    }
}

@Suite("ThumbnailExtractor", .timeLimit(.minutes(1)))
struct ThumbnailExtractorTests {

    let provider = MockImageProvider()

    // MARK: - Configuration

    @Test("Standard configuration defaults")
    func standardConfig() {
        let config = ThumbnailExtractor.Configuration.standard
        #expect(config.size == .small)
        #expect(config.tileColumns == 10)
        #expect(config.tileRows == 10)
        #expect(config.format == .jpeg)
        #expect(config.quality == 0.7)
    }

    @Test("High quality configuration")
    func highQualityConfig() {
        let config = ThumbnailExtractor.Configuration.highQuality
        #expect(config.size == .medium)
        #expect(config.tileColumns == 5)
        #expect(config.tileRows == 5)
        #expect(config.quality == 0.9)
    }

    @Test("ThumbnailSize presets")
    func sizePresets() {
        #expect(ThumbnailExtractor.ThumbnailSize.small == .init(width: 160, height: 90))
        #expect(ThumbnailExtractor.ThumbnailSize.medium == .init(width: 320, height: 180))
        #expect(ThumbnailExtractor.ThumbnailSize.large == .init(width: 480, height: 270))
    }

    // MARK: - Extraction

    @Test("Extract from segments returns correct count and times")
    func extractFromSegments() async throws {
        let extractor = ThumbnailExtractor(
            imageProvider: provider, configuration: .standard
        )
        let segments = [
            SimultaneousRecorder.RecordedSegment(
                filename: "seg0.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 10000
            ),
            SimultaneousRecorder.RecordedSegment(
                filename: "seg1.ts", duration: 6.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 20000
            ),
            SimultaneousRecorder.RecordedSegment(
                filename: "seg2.ts", duration: 4.0,
                isDiscontinuity: false, programDateTime: nil, byteSize: 15000
            )
        ]
        let thumbnails = try await extractor.extractFromSegments(segments) { filename in
            let size = segments.first { $0.filename == filename }?.byteSize ?? 1000
            return Data(repeating: 0x00, count: size)
        }
        #expect(thumbnails.count == 3)
        #expect(thumbnails[0].time == 0.0)
        #expect(thumbnails[1].time == 6.0)
        #expect(thumbnails[2].time == 12.0)
        #expect(thumbnails[0].duration == 6.0)
        #expect(thumbnails[2].duration == 4.0)
        #expect(thumbnails[0].segmentIndex == 0)
        #expect(thumbnails[2].segmentIndex == 2)
    }

    @Test("Extract from empty segments returns empty")
    func extractEmpty() async throws {
        let extractor = ThumbnailExtractor(
            imageProvider: provider, configuration: .standard
        )
        let thumbnails = try await extractor.extractFromSegments([]) { _ in Data() }
        #expect(thumbnails.isEmpty)
    }

    // MARK: - Tile Layout

    @Test("Tile layout with fewer thumbnails than grid")
    func tileLayoutSmall() {
        let extractor = ThumbnailExtractor(
            imageProvider: provider,
            configuration: .init(tileColumns: 5, tileRows: 5)
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 3,
            segmentDurations: [6.0, 6.0, 4.0]
        )
        #expect(sheets.count == 1)
        #expect(sheets[0].entries.count == 3)
        #expect(sheets[0].entries[0].column == 0)
        #expect(sheets[0].entries[0].row == 0)
        #expect(sheets[0].entries[1].column == 1)
        #expect(sheets[0].entries[1].row == 0)
        #expect(sheets[0].entries[2].column == 2)
        #expect(sheets[0].entries[2].row == 0)
        #expect(sheets[0].filename == "tile0.jpg")
    }

    @Test("Tile layout spanning multiple sheets")
    func tileLayoutMultipleSheets() {
        let extractor = ThumbnailExtractor(
            imageProvider: provider,
            configuration: .init(tileColumns: 2, tileRows: 2)
        )
        let durations = Array(repeating: 6.0, count: 6)
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 6,
            segmentDurations: durations
        )
        #expect(sheets.count == 2)
        #expect(sheets[0].entries.count == 4)
        #expect(sheets[1].entries.count == 2)
        #expect(sheets[0].filename == "tile0.jpg")
        #expect(sheets[1].filename == "tile1.jpg")
    }

    @Test("Tile layout empty returns empty")
    func tileLayoutEmpty() {
        let extractor = ThumbnailExtractor(
            imageProvider: provider, configuration: .standard
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 0, segmentDurations: []
        )
        #expect(sheets.isEmpty)
    }

    @Test("Tile layout WebP format uses correct extension")
    func tileLayoutWebP() {
        let extractor = ThumbnailExtractor(
            imageProvider: provider,
            configuration: .init(format: .webp)
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 1, segmentDurations: [6.0]
        )
        #expect(sheets[0].filename == "tile0.webp")
    }

    @Test("Tile layout grid positions wrap correctly")
    func tileLayoutGridWrap() {
        let extractor = ThumbnailExtractor(
            imageProvider: provider,
            configuration: .init(tileColumns: 3, tileRows: 3)
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 7,
            segmentDurations: Array(repeating: 6.0, count: 7)
        )
        #expect(sheets[0].entries.count == 7)
        // Row 0: cols 0,1,2
        #expect(sheets[0].entries[2].column == 2)
        #expect(sheets[0].entries[2].row == 0)
        // Row 1: cols 0,1,2
        #expect(sheets[0].entries[3].column == 0)
        #expect(sheets[0].entries[3].row == 1)
        #expect(sheets[0].entries[5].column == 2)
        #expect(sheets[0].entries[5].row == 1)
        // Row 2: col 0
        #expect(sheets[0].entries[6].column == 0)
        #expect(sheets[0].entries[6].row == 2)
    }

    // MARK: - WebVTT

    @Test("Generate WebVTT with tile sheets")
    func generateWebVTT() {
        let extractor = ThumbnailExtractor(
            imageProvider: provider,
            configuration: .init(size: .init(width: 160, height: 90), tileColumns: 2, tileRows: 2)
        )
        let sheets = extractor.calculateTileLayout(
            thumbnailCount: 3,
            segmentDurations: [6.0, 6.0, 4.0]
        )
        let vtt = extractor.generateWebVTT(tileSheets: sheets, baseURL: "thumbs/")
        #expect(vtt.hasPrefix("WEBVTT"))
        #expect(vtt.contains("00:00:00.000 --> 00:00:06.000"))
        #expect(vtt.contains("thumbs/tile0.jpg#xywh=0,0,160,90"))
        #expect(vtt.contains("thumbs/tile0.jpg#xywh=160,0,160,90"))
        #expect(vtt.contains("thumbs/tile0.jpg#xywh=0,90,160,90"))
    }

    @Test("Generate simple WebVTT without tiling")
    func generateSimpleWebVTT() {
        let extractor = ThumbnailExtractor(
            imageProvider: provider, configuration: .standard
        )
        let thumbnails = [
            ThumbnailExtractor.Thumbnail(
                time: 0, duration: 6.0, imageData: Data(), segmentIndex: 0
            ),
            ThumbnailExtractor.Thumbnail(
                time: 6.0, duration: 6.0, imageData: Data(), segmentIndex: 1
            )
        ]
        let vtt = extractor.generateSimpleWebVTT(
            thumbnails: thumbnails, baseURL: "img/"
        )
        #expect(vtt.hasPrefix("WEBVTT"))
        #expect(vtt.contains("img/thumb0.jpg"))
        #expect(vtt.contains("img/thumb1.jpg"))
        #expect(vtt.contains("00:00:00.000 --> 00:00:06.000"))
        #expect(vtt.contains("00:00:06.000 --> 00:00:12.000"))
    }

    // MARK: - VTT Timestamp

    @Test("formatVTTTimestamp produces correct format")
    func formatVTTTimestamp() {
        #expect(ThumbnailExtractor.formatVTTTimestamp(0) == "00:00:00.000")
        #expect(ThumbnailExtractor.formatVTTTimestamp(6.006) == "00:00:06.006")
        #expect(ThumbnailExtractor.formatVTTTimestamp(61.5) == "00:01:01.500")
        #expect(ThumbnailExtractor.formatVTTTimestamp(3661.123) == "01:01:01.123")
    }
}
