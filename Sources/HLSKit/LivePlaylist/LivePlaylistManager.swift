// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol for managing live HLS playlists.
///
/// Implementations maintain playlist state (segments, sequence numbers,
/// discontinuities) and render valid M3U8 output on demand.
///
/// The playlist management workflow:
/// 1. Create a manager (``SlidingWindowPlaylist`` or ``EventPlaylist``)
/// 2. Add completed segments via ``addSegment(_:)``
/// 3. Optionally insert discontinuities or update metadata
/// 4. Call ``renderPlaylist()`` whenever a client requests the M3U8
/// 5. Call ``endStream()`` when the live session ends
///
/// ## Implementations
/// - ``SlidingWindowPlaylist`` — live playlist with rolling window eviction
/// - ``EventPlaylist`` — event playlist that keeps all segments
public protocol LivePlaylistManager: Sendable {

    /// Add a completed segment to the playlist.
    ///
    /// The segment is appended to the playlist. For sliding window playlists,
    /// old segments beyond the window are evicted automatically.
    /// - Parameter segment: A completed segment from a ``LiveSegmenter``.
    func addSegment(_ segment: LiveSegment) async throws

    /// Add a partial segment for LL-HLS (Phase 11 prep).
    ///
    /// Associates a partial segment with its parent segment index.
    /// - Parameters:
    ///   - partial: The partial segment data.
    ///   - index: The parent segment index.
    func addPartialSegment(
        _ partial: LivePartialSegment,
        forSegment index: Int
    ) async throws

    /// Insert a discontinuity marker.
    ///
    /// The next segment added will be preceded by `EXT-X-DISCONTINUITY`.
    /// Updates the discontinuity sequence counter.
    func insertDiscontinuity() async

    /// Update live playlist metadata.
    ///
    /// Sets metadata like PROGRAM-DATE-TIME tracking, custom tags, etc.
    /// - Parameter metadata: The metadata to apply.
    func updateMetadata(_ metadata: LivePlaylistMetadata) async

    /// Render the current playlist as an M3U8 string.
    ///
    /// Produces a valid HLS media playlist reflecting the current state.
    /// Can be called frequently (e.g., on every HTTP request).
    /// - Returns: A complete M3U8 playlist string.
    func renderPlaylist() async -> String

    /// End the live stream.
    ///
    /// Adds `EXT-X-ENDLIST` and returns the final playlist.
    /// After this call, no more segments should be added.
    /// - Returns: The final M3U8 playlist string with ENDLIST.
    func endStream() async -> String

    /// Stream of playlist lifecycle events.
    ///
    /// Emits events when segments are added/removed, playlist is updated,
    /// or the stream ends.
    var events: AsyncStream<LivePlaylistEvent> { get }

    /// Current media sequence number.
    var mediaSequence: Int { get async }

    /// Current discontinuity sequence number.
    var discontinuitySequence: Int { get async }

    /// Number of segments currently in the playlist.
    var segmentCount: Int { get async }
}
