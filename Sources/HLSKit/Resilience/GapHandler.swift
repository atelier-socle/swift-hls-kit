// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Helper for managing gap signaling in live playlists.
///
/// Wraps the existing `Segment.isGap` with higher-level logic for
/// detecting, inserting, and tracking gaps in live streams.
///
/// ```swift
/// var handler = GapHandler()
/// handler.markGap(at: segmentIndex)
/// print(handler.gapCount)          // 1
/// print(handler.isGap(at: 5))      // true
/// ```
public struct GapHandler: Sendable, Equatable {

    /// Set of segment indices marked as gaps.
    private var gapIndices: Set<Int> = []

    /// Maximum consecutive gaps before alerting.
    public var maxConsecutiveGaps: Int

    /// Creates a gap handler.
    ///
    /// - Parameter maxConsecutiveGaps: Maximum consecutive gaps before alerting.
    public init(maxConsecutiveGaps: Int = 3) {
        self.maxConsecutiveGaps = maxConsecutiveGaps
    }

    // MARK: - Gap Management

    /// Mark a segment index as a gap.
    ///
    /// - Parameter index: The segment index to mark.
    public mutating func markGap(at index: Int) {
        gapIndices.insert(index)
    }

    /// Check if a segment is a gap.
    ///
    /// - Parameter index: The segment index to check.
    /// - Returns: `true` if the segment is marked as a gap.
    public func isGap(at index: Int) -> Bool {
        gapIndices.contains(index)
    }

    /// Clear gap marking for a segment.
    ///
    /// - Parameter index: The segment index to clear.
    public mutating func clearGap(at index: Int) {
        gapIndices.remove(index)
    }

    /// Total number of gaps.
    public var gapCount: Int { gapIndices.count }

    // MARK: - Alert Detection

    /// Check for consecutive gap alert condition.
    ///
    /// Returns `true` if the last `maxConsecutiveGaps` segments ending at
    /// `currentIndex` are all gaps.
    ///
    /// - Parameter currentIndex: The current segment index.
    /// - Returns: `true` if the consecutive gap alert threshold is reached.
    public func hasConsecutiveGapAlert(currentIndex: Int) -> Bool {
        guard maxConsecutiveGaps > 0 else { return false }
        let startIndex = currentIndex - maxConsecutiveGaps + 1
        guard startIndex >= 0 else { return false }
        for i in startIndex...currentIndex where !gapIndices.contains(i) {
            return false
        }
        return true
    }

    // MARK: - Reset

    /// Clear all gaps.
    public mutating func reset() {
        gapIndices.removeAll()
    }

    // MARK: - Segment Application

    /// Apply gap markings to an array of segments.
    ///
    /// Sets `isGap = true` on segments whose indices are in the gap set.
    ///
    /// - Parameter segments: The segments to modify.
    public func applyToSegments(_ segments: inout [Segment]) {
        for index in gapIndices where index >= 0 && index < segments.count {
            segments[index].isGap = true
        }
    }
}
