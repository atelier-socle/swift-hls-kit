// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Muxed Track Input

/// Pairs a segment with its track analysis for muxed output.
public struct MuxedTrackInput: Sendable {

    /// Segment boundaries.
    public let segment: SegmentInfo

    /// Track analysis with sample table.
    public let analysis: MP4TrackAnalysis

    /// Creates a muxed track input.
    public init(segment: SegmentInfo, analysis: MP4TrackAnalysis) {
        self.segment = segment
        self.analysis = analysis
    }
}

// MARK: - Internal Types

extension MediaSegmentWriter {

    struct TrafData {
        let tfhd: Data
        let tfdt: Data
        let trun: TrunData
        let mdatSampleOffset: Int
    }

    struct TrunData {
        let flags: UInt32
        let payload: Data
        let dataOffsetPosition: Int
    }
}

// MARK: - Sample Flags

extension MediaSegmentWriter {

    enum SampleFlags {
        /// Sync sample (keyframe): depends_on=2, non_sync=0.
        static let syncSample: UInt32 = 0x0200_0000
        /// Non-sync sample: depends_on=1, non_sync=1.
        static let nonSyncSample: UInt32 = 0x0101_0000
    }
}
