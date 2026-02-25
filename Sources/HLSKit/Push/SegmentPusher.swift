// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol for pushing HLS segments, playlists, and related
/// content to a destination.
///
/// Implementations handle the specifics of transport (HTTP, RTMP,
/// SRT, etc.) while the protocol defines a common interface for
/// the push pipeline.
///
/// All push methods are async and can throw ``PushError``.
public protocol SegmentPusher: Sendable {

    /// Push a completed live segment.
    ///
    /// - Parameters:
    ///   - segment: The live segment to push.
    ///   - filename: The filename to use at the destination.
    func push(
        segment: LiveSegment, as filename: String
    ) async throws

    /// Push a partial segment (LL-HLS).
    ///
    /// - Parameters:
    ///   - partial: The partial segment to push.
    ///   - filename: The filename to use at the destination.
    func push(
        partial: LLPartialSegment, as filename: String
    ) async throws

    /// Push an updated playlist.
    ///
    /// - Parameters:
    ///   - m3u8: The M3U8 playlist string.
    ///   - filename: The filename to use at the destination.
    func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws

    /// Push an init segment (fMP4 initialization).
    ///
    /// - Parameters:
    ///   - data: The init segment data.
    ///   - filename: The filename to use at the destination.
    func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws

    /// Current connection state.
    var connectionState: PushConnectionState { get async }

    /// Current push statistics.
    var stats: PushStats { get async }

    /// Connect to the push destination.
    func connect() async throws

    /// Disconnect from the push destination.
    func disconnect() async
}
