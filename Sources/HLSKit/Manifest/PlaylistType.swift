// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The type of a media playlist as declared by `EXT-X-PLAYLIST-TYPE`.
///
/// Per RFC 8216 Section 4.3.3.5, this tag provides mutability information
/// about the playlist. If it is absent, the playlist may be updated
/// at any time.
public enum PlaylistType: String, Sendable, Hashable, Codable, CaseIterable {

    /// A Video on Demand playlist. The server MUST NOT change the playlist file.
    /// Clients may cache the entire playlist.
    case vod = "VOD"

    /// An event playlist. The server MUST NOT remove segments from the playlist.
    /// New segments may be appended. Clients should periodically reload.
    case event = "EVENT"
}
