// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Maintains EXT-X-PROGRAM-DATE-TIME synchronization with wall clock.
///
/// Inserts the tag at configurable intervals (per segment or every N segments).
/// Tracks drift between media timeline and wall clock.
///
/// ```swift
/// var sync = ProgramDateTimeSync(
///     streamStartDate: Date(),
///     interval: .everySegment
/// )
/// let tag = sync.tagForSegment(index: 0, segmentDuration: 6.0)
/// // "#EXT-X-PROGRAM-DATE-TIME:2026-02-25T19:30:00.000Z"
/// ```
public struct ProgramDateTimeSync: Sendable, Equatable {

    // MARK: - Types

    /// How often to insert EXT-X-PROGRAM-DATE-TIME.
    public enum InsertionInterval: Sendable, Equatable {
        /// On every segment.
        case everySegment
        /// Every N segments.
        case everyNSegments(Int)
        /// Only on the first segment and after discontinuities.
        case onDiscontinuity
    }

    // MARK: - Properties

    /// When the stream started (wall clock).
    public var streamStartDate: Date

    /// Insertion interval.
    public var interval: InsertionInterval

    /// Current accumulated media time (seconds since stream start).
    public private(set) var accumulatedMediaTime: TimeInterval

    /// Number of segments processed.
    public private(set) var segmentCount: Int

    /// Date when this struct was created, for drift calculation.
    private let creationDate: Date

    /// Creates a program date-time synchronizer.
    ///
    /// - Parameters:
    ///   - streamStartDate: Wall clock start of the stream.
    ///   - interval: How often to insert the tag.
    public init(
        streamStartDate: Date = Date(),
        interval: InsertionInterval = .everySegment
    ) {
        self.streamStartDate = streamStartDate
        self.interval = interval
        self.accumulatedMediaTime = 0
        self.segmentCount = 0
        self.creationDate = Date()
    }

    // MARK: - Tag Generation

    /// Check if a PROGRAM-DATE-TIME tag should be inserted for this segment.
    ///
    /// - Parameters:
    ///   - index: Segment index (0-based).
    ///   - isDiscontinuity: Whether this segment follows a discontinuity.
    /// - Returns: `true` if the tag should be inserted.
    public func shouldInsert(
        forSegmentIndex index: Int,
        isDiscontinuity: Bool = false
    ) -> Bool {
        switch interval {
        case .everySegment:
            return true
        case .everyNSegments(let n):
            guard n > 0 else { return true }
            return index % n == 0
        case .onDiscontinuity:
            return index == 0 || isDiscontinuity
        }
    }

    /// Advance the media clock and return the date for the current segment.
    ///
    /// - Parameter segmentDuration: Duration of the previous segment.
    /// - Returns: The wall clock date for the current segment.
    public mutating func advanceAndGetDate(
        segmentDuration: TimeInterval
    ) -> Date {
        let date = streamStartDate.addingTimeInterval(accumulatedMediaTime)
        accumulatedMediaTime += segmentDuration
        segmentCount += 1
        return date
    }

    /// Generate the full EXT-X-PROGRAM-DATE-TIME tag string.
    ///
    /// - Parameters:
    ///   - index: Segment index.
    ///   - segmentDuration: Duration of the previous segment.
    ///   - isDiscontinuity: Whether this follows a discontinuity.
    /// - Returns: The tag string, or nil if not needed at this position.
    public mutating func tagForSegment(
        index: Int,
        segmentDuration: TimeInterval,
        isDiscontinuity: Bool = false
    ) -> String? {
        let date = advanceAndGetDate(segmentDuration: segmentDuration)
        guard
            shouldInsert(
                forSegmentIndex: index,
                isDiscontinuity: isDiscontinuity
            )
        else {
            return nil
        }
        return "#EXT-X-PROGRAM-DATE-TIME:\(Self.formatDate(date))"
    }

    /// Format a date as ISO 8601 with millisecond precision for HLS.
    ///
    /// Output format: `2026-02-25T19:30:00.000Z`
    ///
    /// - Parameter date: The date to format.
    /// - Returns: ISO 8601 formatted string.
    public static func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds
        ]
        return formatter.string(from: date)
    }

    /// Reset state (e.g., after a discontinuity reset).
    ///
    /// - Parameter newStartDate: Optional new start date; uses current
    ///   if nil.
    public mutating func reset(newStartDate: Date? = nil) {
        if let date = newStartDate {
            streamStartDate = date
        }
        accumulatedMediaTime = 0
        segmentCount = 0
    }

    /// The drift between expected and actual wall clock time.
    ///
    /// Positive drift means wall clock is ahead of media time.
    public var clockDrift: TimeInterval {
        let elapsed = Date().timeIntervalSince(creationDate)
        return elapsed - accumulatedMediaTime
    }
}
