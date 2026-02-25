// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Orchestrates timed metadata injection into a live HLS stream.
///
/// Coordinates ID3 metadata, date ranges, and program date-time
/// insertion across segments as they are produced by the live pipeline.
///
/// ```swift
/// let injector = LiveMetadataInjector(
///     dateTimeSync: ProgramDateTimeSync(interval: .everySegment),
///     dateRangeManager: DateRangeManager()
/// )
/// // When a new segment is ready:
/// let metadata = await injector.metadataForSegment(
///     index: 42, duration: 6.0, isDiscontinuity: false
/// )
/// // metadata.programDateTime → optional tag string
/// // metadata.dateRanges → active ranges M3U8 lines
/// // metadata.id3Data → optional ID3 data for segment injection
/// ```
public actor LiveMetadataInjector {

    // MARK: - Types

    /// Aggregated metadata for a single segment.
    public struct SegmentMetadata: Sendable, Equatable {

        /// EXT-X-PROGRAM-DATE-TIME tag (nil if not needed).
        public var programDateTime: String?

        /// EXT-X-DATERANGE tags for active ranges.
        public var dateRanges: String

        /// Interstitial DATERANGE tags (separate from regular dateRanges).
        public var interstitials: String

        /// ID3 timed metadata to inject into the segment.
        public var id3Data: Data?

        /// Whether any metadata is present.
        public var hasMetadata: Bool {
            programDateTime != nil || !dateRanges.isEmpty
                || !interstitials.isEmpty || id3Data != nil
        }
    }

    // MARK: - Properties

    /// Program date-time synchronizer.
    public var dateTimeSync: ProgramDateTimeSync

    /// Date range lifecycle manager.
    public let dateRangeManager: DateRangeManager

    /// Pending ID3 metadata to inject into the next segment.
    public var pendingID3: [ID3TimedMetadata]

    /// Interstitial manager (optional, set if interstitials are needed).
    public let interstitialManager: InterstitialManager?

    /// Creates a live metadata injector.
    ///
    /// - Parameters:
    ///   - dateTimeSync: Program date-time synchronizer.
    ///   - dateRangeManager: Date range lifecycle manager.
    ///   - interstitialManager: Optional interstitial manager.
    public init(
        dateTimeSync: ProgramDateTimeSync = ProgramDateTimeSync(),
        dateRangeManager: DateRangeManager = DateRangeManager(),
        interstitialManager: InterstitialManager? = nil
    ) {
        self.dateTimeSync = dateTimeSync
        self.dateRangeManager = dateRangeManager
        self.interstitialManager = interstitialManager
        self.pendingID3 = []
    }

    // MARK: - Segment Processing

    /// Generate all metadata for the next segment.
    ///
    /// Consumes any pending ID3 metadata and generates program date-time
    /// and date range tags as configured.
    ///
    /// - Parameters:
    ///   - index: Segment index (0-based).
    ///   - duration: Duration of the previous segment (for clock advance).
    ///   - isDiscontinuity: Whether this segment follows a discontinuity.
    /// - Returns: Aggregated metadata for the segment.
    public func metadataForSegment(
        index: Int,
        duration: TimeInterval,
        isDiscontinuity: Bool = false
    ) async -> SegmentMetadata {
        // Program date-time
        let pdtTag = dateTimeSync.tagForSegment(
            index: index,
            segmentDuration: duration,
            isDiscontinuity: isDiscontinuity
        )

        // Date ranges
        let dateRangeLines = await dateRangeManager.renderDateRanges()

        // Interstitials
        let interstitialLines: String
        if let mgr = interstitialManager {
            interstitialLines = await mgr.renderInterstitials()
        } else {
            interstitialLines = ""
        }

        // ID3 metadata
        let id3Data: Data?
        if !pendingID3.isEmpty {
            var combined = Data()
            for metadata in pendingID3 {
                combined.append(metadata.serialize())
            }
            id3Data = combined
            pendingID3.removeAll()
        } else {
            id3Data = nil
        }

        return SegmentMetadata(
            programDateTime: pdtTag,
            dateRanges: dateRangeLines,
            interstitials: interstitialLines,
            id3Data: id3Data
        )
    }

    // MARK: - ID3 Queueing

    /// Queue ID3 metadata for injection into the next segment.
    ///
    /// - Parameter metadata: The ID3 metadata to queue.
    public func queueID3(_ metadata: ID3TimedMetadata) {
        pendingID3.append(metadata)
    }

    /// Queue a text-only ID3 tag with track info (convenience).
    ///
    /// - Parameters:
    ///   - title: Track title (TIT2).
    ///   - artist: Artist/performer (TPE1).
    ///   - album: Album name (TALB).
    public func queueTrackInfo(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil
    ) {
        var metadata = ID3TimedMetadata()
        if let title {
            metadata.addTextFrame(.title, value: title)
        }
        if let artist {
            metadata.addTextFrame(.artist, value: artist)
        }
        if let album {
            metadata.addTextFrame(.album, value: album)
        }
        guard !metadata.frames.isEmpty else { return }
        pendingID3.append(metadata)
    }

    // MARK: - Date Range Shortcuts

    /// Open a date range (delegates to ``DateRangeManager``).
    ///
    /// - Parameters:
    ///   - id: Unique identifier for the range.
    ///   - class: Optional CLASS attribute.
    ///   - plannedDuration: Optional planned duration.
    ///   - customAttributes: Optional X-* custom attributes.
    public func openDateRange(
        id: String,
        class classAttribute: String? = nil,
        plannedDuration: TimeInterval? = nil,
        customAttributes: [String: String] = [:]
    ) async {
        await dateRangeManager.open(
            id: id,
            startDate: Date(),
            class: classAttribute,
            plannedDuration: plannedDuration,
            customAttributes: customAttributes
        )
    }

    /// Close a date range (delegates to ``DateRangeManager``).
    ///
    /// - Parameter id: Identifier of the range to close.
    public func closeDateRange(id: String) async {
        await dateRangeManager.close(id: id, endDate: Date())
    }

    // MARK: - Reset

    /// Reset all metadata state.
    public func reset() async {
        dateTimeSync.reset()
        await dateRangeManager.reset()
        if let mgr = interstitialManager {
            await mgr.reset()
        }
        pendingID3.removeAll()
    }
}
