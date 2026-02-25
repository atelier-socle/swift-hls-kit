// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Represents an LL-HLS skip request from the client.
///
/// Parsed from query parameters:
/// - `_HLS_skip=YES` → ``yes``
/// - `_HLS_skip=v2` → ``v2``
///
/// ## Usage
/// ```swift
/// let skip = HLSSkipRequest(rawValue: "YES") // .yes
/// let delta = await manager.renderDeltaPlaylist(
///     skipRequest: skip ?? .yes
/// )
/// ```
public enum HLSSkipRequest: String, Sendable {

    /// Standard skip — replace old segments with `EXT-X-SKIP`.
    case yes = "YES"

    /// Version 2 skip — also skip `EXT-X-DATERANGE` tags.
    case v2 = "v2"

    /// Whether this request includes date-range skipping.
    public var skipDateRanges: Bool {
        self == .v2
    }
}
