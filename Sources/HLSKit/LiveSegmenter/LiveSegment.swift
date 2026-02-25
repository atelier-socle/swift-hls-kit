// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A completed segment produced by a ``LiveSegmenter``.
///
/// Contains the encoded data for one HLS segment, along with
/// timing metadata needed for playlist generation.
///
/// ## Lifecycle
/// A segment starts when the previous segment closes (or at stream
/// start). Frames are accumulated until the target duration is
/// reached AND a keyframe boundary is found (for video). Then the
/// segment is emitted via the segmenter's ``LiveSegmenter/segments``
/// stream.
public struct LiveSegment: Sendable, Equatable, Identifiable {

    /// Unique segment index (0-based, monotonically increasing).
    public let index: Int

    /// Identifier for Identifiable conformance.
    public var id: Int { index }

    /// Concatenated encoded frame data for this segment.
    ///
    /// For fMP4: this will be wrapped in moof+mdat boxes by
    /// CMAFWriter (future session). For now: raw concatenated
    /// encoded frames.
    public let data: Data

    /// Actual segment duration in seconds.
    public let duration: TimeInterval

    /// Presentation timestamp of the first frame in this segment.
    public let timestamp: MediaTimestamp

    /// Whether this segment starts with a keyframe (IDR).
    ///
    /// Should always be true for video segments in well-configured
    /// streams. Always true for audio-only segments (every AAC
    /// frame is independent).
    public let isIndependent: Bool

    /// Byte range within a single output file (for byte-range
    /// addressing). Nil for separate-file segments.
    public let byteRange: Range<Int>?

    /// Whether an EXT-X-DISCONTINUITY tag should precede
    /// this segment.
    public let discontinuity: Bool

    /// Whether this is a gap segment (EXT-X-GAP — no actual
    /// media data).
    public let isGap: Bool

    /// Wall-clock time for EXT-X-PROGRAM-DATE-TIME.
    /// Nil if not tracked.
    public let programDateTime: Date?

    /// Segment filename derived from the naming pattern.
    public let filename: String

    /// Number of encoded frames in this segment.
    public let frameCount: Int

    /// Codecs present in this segment
    /// (e.g., [.aac] or [.h264, .aac]).
    public let codecs: Set<EncodedCodec>

    /// Creates a live segment.
    ///
    /// - Parameters:
    ///   - index: Unique segment index.
    ///   - data: Concatenated encoded frame data.
    ///   - duration: Actual segment duration in seconds.
    ///   - timestamp: Presentation timestamp of the first frame.
    ///   - isIndependent: Whether the segment starts with a
    ///     keyframe.
    ///   - byteRange: Optional byte range for byte-range
    ///     addressing.
    ///   - discontinuity: Whether a discontinuity precedes this
    ///     segment.
    ///   - isGap: Whether this is a gap segment.
    ///   - programDateTime: Optional wall-clock time.
    ///   - filename: Segment filename.
    ///   - frameCount: Number of encoded frames.
    ///   - codecs: Set of codecs present.
    public init(
        index: Int,
        data: Data,
        duration: TimeInterval,
        timestamp: MediaTimestamp,
        isIndependent: Bool,
        byteRange: Range<Int>? = nil,
        discontinuity: Bool = false,
        isGap: Bool = false,
        programDateTime: Date? = nil,
        filename: String,
        frameCount: Int,
        codecs: Set<EncodedCodec>
    ) {
        self.index = index
        self.data = data
        self.duration = duration
        self.timestamp = timestamp
        self.isIndependent = isIndependent
        self.byteRange = byteRange
        self.discontinuity = discontinuity
        self.isGap = isGap
        self.programDateTime = programDateTime
        self.filename = filename
        self.frameCount = frameCount
        self.codecs = codecs
    }
}
