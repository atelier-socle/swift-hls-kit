// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Time-based segment buffer for DVR (Digital Video Recorder) functionality.
///
/// Maintains a temporal window of segments, enabling rewind/seek
/// within the configured DVR window. Segments older than the window
/// are evicted automatically.
///
/// ## Difference from SegmentRingBuffer
/// - ``SegmentRingBuffer``: evicts by **count** (keep last N segments)
/// - ``DVRBuffer``: evicts by **time** (keep last N seconds/minutes/hours)
///
/// ## Thread safety
/// This type is a struct and is NOT thread-safe on its own.
/// It is designed to be used within an actor.
///
/// ## Usage
/// ```swift
/// var dvr = DVRBuffer(windowDuration: 7200) // 2 hours
/// dvr.append(segment)
/// dvr.evictExpired() // Remove segments outside the window
/// let playlist = dvr.segmentsFromOffset(-60, maxCount: 10)
/// ```
public struct DVRBuffer: Sendable, Equatable {

    /// Maximum temporal window in seconds.
    ///
    /// Segments whose end time (timestamp + duration) falls outside
    /// this window from the latest segment are eligible for eviction.
    public let windowDuration: TimeInterval

    /// All segments currently in the buffer.
    private var segments: [LiveSegment] = []

    /// Index map for O(1) lookup by segment index.
    private var indexMap: [Int: Int] = [:]

    /// Creates a DVR buffer with the given window duration.
    ///
    /// - Parameter windowDuration: Maximum temporal window in seconds.
    public init(windowDuration: TimeInterval) {
        self.windowDuration = windowDuration
    }

    // MARK: - Mutation

    /// Append a segment to the buffer.
    ///
    /// - Parameter segment: The segment to append.
    public mutating func append(_ segment: LiveSegment) {
        segments.append(segment)
        indexMap[segment.index] = segments.count - 1
    }

    /// Evict segments outside the DVR window.
    ///
    /// Removes segments whose end time is older than
    /// (latest segment timestamp - windowDuration).
    /// - Returns: The evicted segments (for sequence tracking).
    @discardableResult
    public mutating func evictExpired() -> [LiveSegment] {
        guard let latest = segments.last else { return [] }
        let cutoff = latest.timestamp.seconds - windowDuration

        var evicted: [LiveSegment] = []
        while let first = segments.first,
            (first.timestamp.seconds + first.duration) < cutoff
        {
            evicted.append(segments.removeFirst())
        }

        if !evicted.isEmpty {
            rebuildIndexMap()
        }

        return evicted
    }

    /// Remove all segments from the buffer.
    public mutating func clear() {
        segments.removeAll()
        indexMap.removeAll()
    }

    // MARK: - Lookup

    /// Retrieve a segment by its index.
    ///
    /// - Parameter index: The segment index.
    /// - Returns: The segment, or `nil` if not in the buffer.
    public func segment(at index: Int) -> LiveSegment? {
        guard let pos = indexMap[index], pos < segments.count else {
            return nil
        }
        return segments[pos]
    }

    /// All segments in the buffer, ordered by index.
    public var allSegments: [LiveSegment] {
        segments
    }

    /// Number of segments in the buffer.
    public var count: Int {
        segments.count
    }

    /// Whether the buffer is empty.
    public var isEmpty: Bool {
        segments.isEmpty
    }

    /// Total duration of all buffered segments.
    public var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    /// Total data size of all buffered segments (bytes).
    public var totalDataSize: Int {
        segments.reduce(0) { $0 + $1.data.count }
    }

    /// The oldest segment in the buffer.
    public var oldest: LiveSegment? {
        segments.first
    }

    /// The newest segment in the buffer.
    public var newest: LiveSegment? {
        segments.last
    }

    // MARK: - Range Queries

    /// Retrieve segments starting from a temporal offset.
    ///
    /// Used to serve a DVR playlist starting from a specific rewind point.
    /// - Parameters:
    ///   - offset: Seconds from the live edge (negative = rewind).
    ///   - maxCount: Maximum number of segments to return.
    /// - Returns: Segments starting from the offset point.
    public func segmentsFromOffset(
        _ offset: TimeInterval,
        maxCount: Int = .max
    ) -> [LiveSegment] {
        guard let latest = segments.last else { return [] }
        let targetTime = latest.timestamp.seconds + offset
        let startIdx =
            segments.firstIndex { segment in
                segment.timestamp.seconds >= targetTime
            } ?? 0
        let remaining = segments.count - startIdx
        let endIdx = startIdx + min(remaining, maxCount)
        return Array(segments[startIdx..<endIdx])
    }

    /// Retrieve segments within a PROGRAM-DATE-TIME range.
    ///
    /// Used for time-based DVR seeking when segments have
    /// programDateTime set.
    /// - Parameters:
    ///   - from: Start date.
    ///   - to: End date.
    /// - Returns: Segments whose programDateTime falls within the range.
    public func segmentsInDateRange(
        from: Date, to: Date
    ) -> [LiveSegment] {
        segments.filter { segment in
            guard let date = segment.programDateTime else {
                return false
            }
            return date >= from && date <= to
        }
    }

    // MARK: - Private

    private mutating func rebuildIndexMap() {
        indexMap.removeAll()
        for (pos, seg) in segments.enumerated() {
            indexMap[seg.index] = pos
        }
    }
}
