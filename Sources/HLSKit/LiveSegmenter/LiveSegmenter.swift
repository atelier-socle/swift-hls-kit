// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Protocol for real-time segmentation of encoded media frames.
///
/// Implementations consume ``EncodedFrame`` objects from a ``LiveEncoder``
/// and produce ``LiveSegment`` objects suitable for HLS playlist generation.
///
/// The segmentation workflow:
/// 1. Configure with ``LiveSegmenterConfiguration``
/// 2. Feed frames via ``ingest(_:)`` during the live session
/// 3. Consume completed segments from ``segments`` AsyncStream
/// 4. Optionally force a segment boundary with ``forceSegmentBoundary()``
/// 5. Call ``finish()`` to finalize the last segment when the session ends
///
/// ## Implementations
/// - ``IncrementalSegmenter`` — general-purpose keyframe-aligned segmenter
public protocol LiveSegmenter: Sendable {

    /// Ingest an encoded frame into the segmenter.
    ///
    /// The frame is accumulated into the current segment. When the target
    /// duration is reached AND a keyframe boundary is found (for video),
    /// the completed segment is emitted via ``segments``.
    ///
    /// - Parameter frame: An encoded frame from a ``LiveEncoder``.
    /// - Throws: ``LiveSegmenterError`` on failure.
    func ingest(_ frame: EncodedFrame) async throws

    /// Stream of completed segments.
    ///
    /// Each completed segment is emitted here as soon as it reaches
    /// the target duration and a keyframe boundary (for video).
    /// Consumers should iterate this stream to receive segments
    /// in real-time.
    var segments: AsyncStream<LiveSegment> { get }

    /// Force the current segment to close immediately.
    ///
    /// Used for ad insertion points, program boundaries, or other
    /// events that require an immediate segment break regardless
    /// of target duration. The next segment starts at the next frame.
    ///
    /// - Throws: ``LiveSegmenterError`` if no frames have been ingested.
    func forceSegmentBoundary() async throws

    /// Finalize the last segment and stop the segmenter.
    ///
    /// Called when the live session ends. Returns the final segment
    /// (which may be shorter than target duration).
    ///
    /// - Returns: The final segment, or nil if no frames are pending.
    func finish() async throws -> LiveSegment?
}
