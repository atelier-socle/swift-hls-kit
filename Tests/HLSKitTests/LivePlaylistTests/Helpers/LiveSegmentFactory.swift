// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Factory for creating test ``LiveSegment`` objects.
enum LiveSegmentFactory {

    /// Create a single test segment.
    ///
    /// - Parameters:
    ///   - index: Segment index.
    ///   - duration: Duration in seconds. Default: 6.0.
    ///   - filename: Segment filename. Default: segment_{index}.m4s.
    ///   - isGap: Whether this is a gap segment.
    ///   - discontinuity: Whether a discontinuity precedes this.
    ///   - programDateTime: Optional wall-clock time.
    static func makeSegment(
        index: Int = 0,
        duration: TimeInterval = 6.0,
        filename: String? = nil,
        isGap: Bool = false,
        discontinuity: Bool = false,
        programDateTime: Date? = nil
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: 0xAA, count: 64),
            duration: duration,
            timestamp: MediaTimestamp(
                seconds: Double(index) * duration
            ),
            isIndependent: true,
            discontinuity: discontinuity,
            isGap: isGap,
            programDateTime: programDateTime,
            filename: filename ?? "segment_\(index).m4s",
            frameCount: 10,
            codecs: [.aac]
        )
    }

    /// Create multiple sequential test segments.
    ///
    /// - Parameters:
    ///   - count: Number of segments to create.
    ///   - duration: Duration per segment. Default: 6.0.
    ///   - startIndex: Starting index. Default: 0.
    static func makeSegments(
        count: Int,
        duration: TimeInterval = 6.0,
        startIndex: Int = 0
    ) -> [LiveSegment] {
        (0..<count).map { i in
            makeSegment(
                index: startIndex + i,
                duration: duration
            )
        }
    }
}
