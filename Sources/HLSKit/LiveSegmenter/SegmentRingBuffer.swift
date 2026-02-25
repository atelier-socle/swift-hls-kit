// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Fixed-capacity ring buffer for recent ``LiveSegment`` storage.
///
/// Keeps the N most recent segments in memory for DVR (rewind)
/// support. When the buffer is full, the oldest segment is evicted
/// to make room.
///
/// ## Thread Safety
/// This type is not an actor and is NOT thread-safe on its own.
/// It is designed to be used exclusively within an actor
/// (e.g., ``IncrementalSegmenter``).
///
/// ## Capacity
/// - `capacity = 0`: no segments are stored (live-edge only)
/// - `capacity = 5`: last 5 segments (~30s at 6s segments)
/// - `capacity = .max`: unlimited storage (event recording)
struct SegmentRingBuffer: Sendable {

    /// Maximum number of segments to retain.
    let capacity: Int

    /// Internal storage.
    private var buffer: [LiveSegment] = []

    /// Index map for O(1) lookup by segment index.
    private var indexMap: [Int: Int] = [:]

    /// Creates a ring buffer with the given capacity.
    ///
    /// - Parameter capacity: Maximum number of segments to retain.
    init(capacity: Int) {
        self.capacity = capacity
    }

    /// Append a segment, evicting the oldest if at capacity.
    ///
    /// - Parameter segment: The segment to append.
    mutating func append(_ segment: LiveSegment) {
        guard capacity > 0 else { return }

        if buffer.count >= capacity && capacity != .max {
            let evicted = buffer.removeFirst()
            indexMap.removeValue(forKey: evicted.index)
            // Rebuild index map (positions shifted)
            indexMap.removeAll()
            for (pos, seg) in buffer.enumerated() {
                indexMap[seg.index] = pos
            }
        }
        buffer.append(segment)
        indexMap[segment.index] = buffer.count - 1
    }

    /// Retrieve a segment by its index.
    ///
    /// - Parameter index: The segment index.
    /// - Returns: The segment, or nil if not in the buffer.
    func segment(at index: Int) -> LiveSegment? {
        guard let pos = indexMap[index],
            pos < buffer.count
        else { return nil }
        return buffer[pos]
    }

    /// All segments currently in the buffer, ordered by index.
    var allSegments: [LiveSegment] {
        buffer
    }

    /// Number of segments in the buffer.
    var count: Int {
        buffer.count
    }

    /// Whether the buffer is empty.
    var isEmpty: Bool {
        buffer.isEmpty
    }

    /// The oldest segment in the buffer.
    var oldest: LiveSegment? {
        buffer.first
    }

    /// The newest segment in the buffer.
    var newest: LiveSegment? {
        buffer.last
    }

    /// The range of segment indices currently in the buffer.
    var indexRange: ClosedRange<Int>? {
        guard let first = buffer.first,
            let last = buffer.last
        else { return nil }
        return first.index...last.index
    }

    /// Remove all segments from the buffer.
    mutating func clear() {
        buffer.removeAll()
        indexMap.removeAll()
    }

    /// Total data size of all segments in the buffer (bytes).
    var totalDataSize: Int {
        buffer.reduce(0) { $0 + $1.data.count }
    }

    /// Total duration of all segments in the buffer (seconds).
    var totalDuration: TimeInterval {
        buffer.reduce(0) { $0 + $1.duration }
    }
}
