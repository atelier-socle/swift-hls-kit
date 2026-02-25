// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol for platform-specific image extraction.
///
/// Implement with AVFoundation on Apple platforms or FFmpeg on Linux.
/// Tests use a mock returning synthetic data.
public protocol ThumbnailImageProvider: Sendable {

    /// Extract a JPEG thumbnail at the given timestamp.
    ///
    /// - Parameters:
    ///   - segmentData: Raw segment binary data.
    ///   - timestamp: Time offset within the segment.
    ///   - size: Target thumbnail size.
    /// - Returns: JPEG data for the thumbnail.
    func extractThumbnail(
        from segmentData: Data,
        at timestamp: TimeInterval,
        size: ThumbnailExtractor.ThumbnailSize
    ) async throws -> Data
}

/// Extracts thumbnail images from video segments for timeline preview.
///
/// Uses a protocol-based approach for actual image extraction (platform-dependent),
/// while providing pure-Swift logic for tile layout calculation and WebVTT generation.
///
/// ```swift
/// let extractor = ThumbnailExtractor(
///     imageProvider: MyAVFoundationProvider(),
///     configuration: .standard
/// )
/// let thumbnails = try await extractor.extractFromSegments(
///     segments, segmentDataProvider: { filename in loadData(filename) }
/// )
/// let tiles = extractor.calculateTileLayout(
///     thumbnailCount: thumbnails.count,
///     segmentDurations: segments.map(\.duration)
/// )
/// let vtt = extractor.generateWebVTT(tileSheets: tiles, baseURL: "thumbs/")
/// ```
public struct ThumbnailExtractor: Sendable {

    // MARK: - Types

    /// Thumbnail size.
    public struct ThumbnailSize: Sendable, Equatable {

        /// Width in pixels.
        public var width: Int

        /// Height in pixels.
        public var height: Int

        /// Creates a thumbnail size.
        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }

        /// Standard 16:9 thumbnail (160x90).
        public static let small = ThumbnailSize(width: 160, height: 90)

        /// Medium 16:9 thumbnail (320x180).
        public static let medium = ThumbnailSize(width: 320, height: 180)

        /// Large 16:9 thumbnail (480x270).
        public static let large = ThumbnailSize(width: 480, height: 270)
    }

    /// Configuration for thumbnail extraction.
    public struct Configuration: Sendable, Equatable {

        /// Thumbnail size.
        public var size: ThumbnailSize

        /// Tile grid columns (for sprite sheets).
        public var tileColumns: Int

        /// Tile grid rows (for sprite sheets).
        public var tileRows: Int

        /// Image format.
        public var format: ImageFormat

        /// JPEG quality (0.0-1.0).
        public var quality: Double

        /// Creates a configuration.
        public init(
            size: ThumbnailSize = .small,
            tileColumns: Int = 10,
            tileRows: Int = 10,
            format: ImageFormat = .jpeg,
            quality: Double = 0.7
        ) {
            self.size = size
            self.tileColumns = tileColumns
            self.tileRows = tileRows
            self.format = format
            self.quality = quality
        }

        /// Standard configuration (small, 10x10 grid, JPEG).
        public static let standard = Configuration()

        /// High quality (medium, 5x5 grid, JPEG 0.9).
        public static let highQuality = Configuration(
            size: .medium,
            tileColumns: 5,
            tileRows: 5,
            quality: 0.9
        )

        /// Image format.
        public enum ImageFormat: String, Sendable, Equatable {
            /// JPEG format.
            case jpeg
            /// WebP format.
            case webp
        }
    }

    /// A single extracted thumbnail.
    public struct Thumbnail: Sendable, Equatable {

        /// Time this thumbnail represents.
        public var time: TimeInterval

        /// Duration this thumbnail covers.
        public var duration: TimeInterval

        /// Image data (JPEG/WebP).
        public var imageData: Data

        /// Segment index this was extracted from.
        public var segmentIndex: Int
    }

    /// A tile sprite sheet (grid of thumbnails).
    public struct TileSheet: Sendable, Equatable {

        /// Filename for this tile sheet.
        public var filename: String

        /// Grid columns.
        public var columns: Int

        /// Grid rows.
        public var rows: Int

        /// Individual thumbnail size.
        public var thumbnailSize: ThumbnailSize

        /// Thumbnails in this sheet, with their grid positions.
        public var entries: [TileEntry]

        /// A single entry in a tile sheet.
        public struct TileEntry: Sendable, Equatable {

            /// Column in the grid (0-based).
            public var column: Int

            /// Row in the grid (0-based).
            public var row: Int

            /// Time this thumbnail represents.
            public var time: TimeInterval

            /// Duration this thumbnail covers.
            public var duration: TimeInterval
        }
    }

    // MARK: - Properties

    /// Image provider for platform-specific extraction.
    public let imageProvider: ThumbnailImageProvider

    /// Configuration.
    public let configuration: Configuration

    /// Creates a thumbnail extractor.
    ///
    /// - Parameters:
    ///   - imageProvider: Platform-specific image extraction provider.
    ///   - configuration: Extraction configuration.
    public init(
        imageProvider: ThumbnailImageProvider,
        configuration: Configuration = .standard
    ) {
        self.imageProvider = imageProvider
        self.configuration = configuration
    }

    // MARK: - Extraction

    /// Extract thumbnails from recorded segments.
    ///
    /// Returns one thumbnail per segment (at keyframe / start of segment).
    /// - Parameters:
    ///   - segments: Recorded segment metadata.
    ///   - segmentDataProvider: Closure to load segment data by filename.
    /// - Returns: Extracted thumbnails.
    public func extractFromSegments(
        _ segments: [SimultaneousRecorder.RecordedSegment],
        segmentDataProvider: @Sendable (String) async throws -> Data
    ) async throws -> [Thumbnail] {
        var thumbnails = [Thumbnail]()
        var accTime: TimeInterval = 0
        for (index, segment) in segments.enumerated() {
            let data = try await segmentDataProvider(segment.filename)
            let imgData = try await imageProvider.extractThumbnail(
                from: data, at: 0, size: configuration.size
            )
            thumbnails.append(
                Thumbnail(
                    time: accTime,
                    duration: segment.duration,
                    imageData: imgData,
                    segmentIndex: index
                )
            )
            accTime += segment.duration
        }
        return thumbnails
    }

    // MARK: - Tile Layout

    /// Calculate tile sheet layout from thumbnails.
    ///
    /// Groups thumbnails into sprite sheets based on configuration grid size.
    /// - Parameters:
    ///   - thumbnailCount: Total number of thumbnails.
    ///   - segmentDurations: Duration of each segment.
    /// - Returns: Tile sheets with grid positions.
    public func calculateTileLayout(
        thumbnailCount: Int,
        segmentDurations: [TimeInterval]
    ) -> [TileSheet] {
        let perSheet = configuration.tileColumns * configuration.tileRows
        guard thumbnailCount > 0 else { return [] }
        let sheetCount = (thumbnailCount + perSheet - 1) / perSheet
        var sheets = [TileSheet]()
        var accTime: TimeInterval = 0
        var thumbIndex = 0
        for sheetIndex in 0..<sheetCount {
            var entries = [TileSheet.TileEntry]()
            let remaining = min(perSheet, thumbnailCount - thumbIndex)
            for i in 0..<remaining {
                let col = i % configuration.tileColumns
                let row = i / configuration.tileColumns
                let dur =
                    thumbIndex < segmentDurations.count
                    ? segmentDurations[thumbIndex] : 6.0
                entries.append(
                    TileSheet.TileEntry(
                        column: col, row: row,
                        time: accTime, duration: dur
                    )
                )
                accTime += dur
                thumbIndex += 1
            }
            let ext = configuration.format == .jpeg ? "jpg" : "webp"
            sheets.append(
                TileSheet(
                    filename: "tile\(sheetIndex).\(ext)",
                    columns: configuration.tileColumns,
                    rows: configuration.tileRows,
                    thumbnailSize: configuration.size,
                    entries: entries
                )
            )
        }
        return sheets
    }

    // MARK: - WebVTT Generation

    /// Generate WebVTT thumbnail manifest with tile sprite sheet references.
    ///
    /// Uses `#xywh=x,y,w,h` fragment syntax for tile positions.
    /// - Parameters:
    ///   - tileSheets: Tile sheets from ``calculateTileLayout``.
    ///   - baseURL: Base URL prefix for tile filenames.
    /// - Returns: WebVTT string.
    public func generateWebVTT(
        tileSheets: [TileSheet],
        baseURL: String
    ) -> String {
        var lines = ["WEBVTT", ""]
        var cueIndex = 1
        let size = configuration.size
        for sheet in tileSheets {
            for entry in sheet.entries {
                lines.append(String(cueIndex))
                let start = Self.formatVTTTimestamp(entry.time)
                let end = Self.formatVTTTimestamp(entry.time + entry.duration)
                lines.append("\(start) --> \(end)")
                let x = entry.column * size.width
                let y = entry.row * size.height
                lines.append(
                    "\(baseURL)\(sheet.filename)#xywh=\(x),\(y),\(size.width),\(size.height)"
                )
                lines.append("")
                cueIndex += 1
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Generate WebVTT for individual thumbnails (no tiling).
    ///
    /// - Parameters:
    ///   - thumbnails: Individual thumbnails.
    ///   - baseURL: Base URL prefix for thumbnail filenames.
    /// - Returns: WebVTT string.
    public func generateSimpleWebVTT(
        thumbnails: [Thumbnail],
        baseURL: String
    ) -> String {
        var lines = ["WEBVTT", ""]
        let ext = configuration.format == .jpeg ? "jpg" : "webp"
        for (index, thumb) in thumbnails.enumerated() {
            lines.append(String(index + 1))
            let start = Self.formatVTTTimestamp(thumb.time)
            let end = Self.formatVTTTimestamp(thumb.time + thumb.duration)
            lines.append("\(start) --> \(end)")
            lines.append("\(baseURL)thumb\(index).\(ext)")
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Utilities

    /// Format a WebVTT timestamp (`HH:MM:SS.mmm`).
    ///
    /// - Parameter seconds: Time in seconds.
    /// - Returns: Formatted timestamp string.
    public static func formatVTTTimestamp(_ seconds: TimeInterval) -> String {
        let totalMs = Int(seconds * 1000)
        let hours = totalMs / 3_600_000
        let minutes = (totalMs % 3_600_000) / 60_000
        let secs = (totalMs % 60_000) / 1_000
        let ms = totalMs % 1_000
        return String(
            format: "%02d:%02d:%02d.%03d", hours, minutes, secs, ms
        )
    }
}
