// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Tracks HLS media sequence and discontinuity sequence numbers.
///
/// Per HLS spec (RFC 8216):
/// - `EXT-X-MEDIA-SEQUENCE`: the sequence number of the FIRST segment
///   in the playlist. Increments when segments are evicted from the
///   beginning of a sliding window playlist.
/// - `EXT-X-DISCONTINUITY-SEQUENCE`: the discontinuity sequence number
///   of the FIRST segment in the playlist. Increments when a
///   discontinuity tag is evicted.
///
/// ## Usage
/// ```swift
/// var tracker = MediaSequenceTracker()
/// tracker.segmentAdded(index: 0)         // segments: [0]
/// tracker.segmentAdded(index: 1)         // segments: [0, 1]
/// tracker.segmentEvicted(index: 0)       // segments: [1], mediaSequence = 1
/// tracker.discontinuityInserted()        // next segment has discontinuity
/// tracker.segmentAdded(index: 2)         // segments: [1, 2] (disc before 2)
/// tracker.segmentEvicted(index: 1)       // segments: [2], mediaSequence = 2
/// // Segment 2 had a discontinuity before it → discontinuitySequence = 1
/// ```
struct MediaSequenceTracker: Sendable, Equatable {

    /// Current EXT-X-MEDIA-SEQUENCE value (sequence number of first segment).
    private(set) var mediaSequence: Int = 0

    /// Current EXT-X-DISCONTINUITY-SEQUENCE value.
    private(set) var discontinuitySequence: Int = 0

    /// Total segments ever added.
    private(set) var totalSegmentsAdded: Int = 0

    /// Total segments evicted from the playlist head.
    private(set) var totalSegmentsEvicted: Int = 0

    /// Whether the next segment should be preceded by a discontinuity.
    private(set) var pendingDiscontinuity: Bool = false

    /// Track segment indices that have a discontinuity before them.
    /// Used to know if evicting a segment should bump discontinuitySequence.
    private var discontinuityIndices: Set<Int> = []

    init() {}

    /// Record that a new segment was added to the playlist.
    ///
    /// - Parameter index: The index of the added segment.
    mutating func segmentAdded(index: Int) {
        totalSegmentsAdded += 1
        if pendingDiscontinuity {
            discontinuityIndices.insert(index)
            pendingDiscontinuity = false
        }
    }

    /// Record that the oldest segment was evicted (sliding window).
    ///
    /// - Parameter index: The index of the evicted segment.
    mutating func segmentEvicted(index: Int) {
        totalSegmentsEvicted += 1
        mediaSequence += 1
        if discontinuityIndices.contains(index) {
            discontinuitySequence += 1
            discontinuityIndices.remove(index)
        }
    }

    /// Mark that a discontinuity should precede the next segment.
    mutating func discontinuityInserted() {
        pendingDiscontinuity = true
    }

    /// Check if a given segment index has a discontinuity before it.
    ///
    /// - Parameter index: The segment index to check.
    /// - Returns: True if a discontinuity precedes this segment.
    func hasDiscontinuity(at index: Int) -> Bool {
        discontinuityIndices.contains(index)
    }
}
