// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Events emitted by a ``LivePlaylistManager`` during its lifecycle.
public enum LivePlaylistEvent: Sendable, Equatable {

    /// A segment was added to the playlist.
    case segmentAdded(index: Int, duration: TimeInterval)

    /// A segment was removed from the playlist (sliding window eviction).
    case segmentRemoved(index: Int)

    /// The playlist was re-rendered (new M3U8 available).
    case playlistUpdated(mediaSequence: Int)

    /// The stream has ended (EXT-X-ENDLIST was added).
    case streamEnded
}
