// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A live partial segment for Low-Latency HLS (LL-HLS).
///
/// Partial segments are sub-segment units that allow clients to begin
/// playback before the full segment is available. Each partial segment
/// contains a portion of the parent segment's encoded media data.
///
/// Unlike ``PartialSegment`` (manifest-level, URI-based), this type
/// holds the actual encoded data produced by a ``LiveSegmenter``.
///
/// ## EXT-X-PART
/// In LL-HLS playlists, partial segments are advertised via the
/// `EXT-X-PART` tag, enabling ultra-low latency streaming.
public struct LivePartialSegment: Sendable, Equatable, Identifiable {

    /// Partial segment index within the parent segment.
    public let index: Int

    /// Identifier for `Identifiable` conformance.
    public var id: Int { index }

    /// Encoded media data for this partial segment.
    ///
    /// For fMP4: contains moof + mdat boxes (no styp prefix).
    public let data: Data

    /// Duration of this partial segment in seconds.
    public let duration: TimeInterval

    /// Whether this partial segment starts with an independent frame.
    ///
    /// True if the first frame is a keyframe (IDR for video, always
    /// true for audio).
    public let isIndependent: Bool

    /// Whether this is a gap partial (no actual media data).
    public let isGap: Bool

    /// Creates a partial segment.
    ///
    /// - Parameters:
    ///   - index: Partial segment index within the parent segment.
    ///   - data: Encoded media data.
    ///   - duration: Duration in seconds.
    ///   - isIndependent: Whether it starts with a keyframe.
    ///   - isGap: Whether this is a gap partial. Defaults to false.
    public init(
        index: Int,
        data: Data,
        duration: TimeInterval,
        isIndependent: Bool,
        isGap: Bool = false
    ) {
        self.index = index
        self.data = data
        self.duration = duration
        self.isIndependent = isIndependent
        self.isGap = isGap
    }
}
