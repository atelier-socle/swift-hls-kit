// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A partial segment for the Low-Latency HLS (LL-HLS) pipeline.
///
/// Represents a sub-segment chunk published before the full segment is
/// complete. Each partial is identified by its parent segment index and
/// partial index within that segment.
///
/// Unlike ``PartialSegment`` (manifest-level, parsed from M3U8),
/// this type carries pipeline metadata such as ``segmentIndex``,
/// ``partialIndex``, and ``timestamp`` needed by the LL-HLS orchestrator.
///
/// ## EXT-X-PART
/// In LL-HLS playlists, partial segments are advertised via the
/// `EXT-X-PART` tag (RFC 8216bis Section 4.4.4.9).
///
/// ```swift
/// let partial = LLPartialSegment(
///     duration: 0.33334,
///     uri: "seg0.0.mp4",
///     isIndependent: true,
///     segmentIndex: 0,
///     partialIndex: 0
/// )
/// ```
public struct LLPartialSegment: Sendable, Identifiable, Equatable {

    /// Unique identifier combining segment index and partial index.
    public let id: String

    /// Duration of this partial segment in seconds.
    public let duration: TimeInterval

    /// URI for this partial segment.
    public let uri: String

    /// Whether this partial starts with an independent frame (IDR/keyframe).
    ///
    /// The first partial of each segment MUST be independent
    /// (RFC 8216bis Section 4.4.4.9).
    public let isIndependent: Bool

    /// Whether this is a GAP partial (content unavailable).
    public let isGap: Bool

    /// Byte range if applicable (for byte-range addressed parts).
    public let byteRange: ByteRange?

    /// The parent segment index this partial belongs to.
    public let segmentIndex: Int

    /// The partial index within its parent segment (0-based).
    public let partialIndex: Int

    /// Timestamp when this partial was created.
    public let timestamp: Date

    /// Creates a partial segment for the LL-HLS pipeline.
    ///
    /// - Parameters:
    ///   - duration: Duration of this partial in seconds.
    ///   - uri: URI for this partial segment.
    ///   - isIndependent: Whether it starts with an independent frame.
    ///   - isGap: Whether this is a GAP partial. Defaults to `false`.
    ///   - byteRange: Optional byte range. Defaults to `nil`.
    ///   - segmentIndex: Parent segment index.
    ///   - partialIndex: Partial index within the parent segment.
    ///   - timestamp: Creation timestamp. Defaults to current date.
    public init(
        duration: TimeInterval,
        uri: String,
        isIndependent: Bool,
        isGap: Bool = false,
        byteRange: ByteRange? = nil,
        segmentIndex: Int,
        partialIndex: Int,
        timestamp: Date = Date()
    ) {
        self.id = "\(segmentIndex).\(partialIndex)"
        self.duration = duration
        self.uri = uri
        self.isIndependent = isIndependent
        self.isGap = isGap
        self.byteRange = byteRange
        self.segmentIndex = segmentIndex
        self.partialIndex = partialIndex
        self.timestamp = timestamp
    }
}
