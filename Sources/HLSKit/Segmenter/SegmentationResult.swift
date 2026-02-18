// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// The result of segmenting an MP4 file into HLS fMP4 fragments.
///
/// Contains the initialization segment, all media segments, and
/// optionally a generated HLS playlist string.
///
/// ```swift
/// let result = try segmenter.segment(data: mp4Data)
/// print("Segments: \(result.segmentCount)")
/// print("Duration: \(result.totalDuration)s")
/// ```
public struct SegmentationResult: Sendable {

    /// The initialization segment data (init.mp4).
    public let initSegment: Data

    /// The media segments.
    public let mediaSegments: [MediaSegmentOutput]

    /// The generated HLS media playlist (if `generatePlaylist` was true).
    public let playlist: String?

    /// Source file information.
    public let fileInfo: MP4FileInfo

    /// Configuration used for segmentation.
    public let config: SegmentationConfig

    /// Total duration of all segments in seconds.
    public var totalDuration: Double {
        mediaSegments.reduce(0) { $0 + $1.duration }
    }

    /// Number of segments.
    public var segmentCount: Int { mediaSegments.count }

    /// Whether this result has an initialization segment.
    ///
    /// Returns `true` for fMP4 results (which require init.mp4)
    /// and `false` for MPEG-TS results (self-contained segments).
    public var hasInitSegment: Bool { !initSegment.isEmpty }
}

/// A single output media segment.
///
/// Contains the segment binary data and metadata including duration,
/// filename, and optional byte-range information.
public struct MediaSegmentOutput: Sendable, Hashable {

    /// 0-based segment index.
    public let index: Int

    /// Segment data (styp + moof + mdat).
    public let data: Data

    /// Segment duration in seconds.
    public let duration: Double

    /// Filename (from pattern, e.g., `"segment_0.m4s"`).
    public let filename: String

    /// For byte-range mode: offset in the combined file.
    public let byteRangeOffset: UInt64?

    /// For byte-range mode: length.
    public let byteRangeLength: UInt64?
}
