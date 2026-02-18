// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The HLS protocol version as defined by `EXT-X-VERSION`.
///
/// Each version introduces new tags and capabilities.
/// Per RFC 8216, a playlist that uses features introduced in a later
/// version MUST declare that version with `EXT-X-VERSION`.
public enum HLSVersion: Int, Sendable, Hashable, Codable, CaseIterable, Comparable {

    /// HLS version 1 — original specification.
    case v1 = 1

    /// HLS version 2 — `IV` attribute for `EXT-X-KEY`.
    case v2 = 2

    /// HLS version 3 — floating-point `EXTINF` durations.
    case v3 = 3

    /// HLS version 4 — `EXT-X-BYTERANGE` and `EXT-X-I-FRAMES-ONLY`.
    case v4 = 4

    /// HLS version 5 — `EXT-X-KEY` `KEYFORMAT` / `KEYFORMATVERSIONS`.
    case v5 = 5

    /// HLS version 6 — `EXT-X-MAP` for non-I-frame playlists.
    case v6 = 6

    /// HLS version 7 — `EXT-X-SESSION-DATA`, `EXT-X-SESSION-KEY`, `EXT-X-DATERANGE`.
    case v7 = 7

    /// HLS version 8 — variable substitution with `EXT-X-DEFINE`.
    case v8 = 8

    /// HLS version 9 — `EXT-X-SKIP`, Low-Latency HLS extensions.
    case v9 = 9

    /// HLS version 10 — `EXT-X-CONTENT-STEERING`.
    case v10 = 10

    // MARK: - Comparable

    public static func < (lhs: HLSVersion, rhs: HLSVersion) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
