// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Codec identifiers for HLS subtitle tracks.
///
/// Used in `EXT-X-STREAM-INF` and `EXT-X-MEDIA` tags
/// to declare the subtitle format.
///
/// ```swift
/// let codec = SubtitleCodec.imsc1
/// print(codec.rawValue) // "stpp.ttml.im1t"
/// ```
public enum SubtitleCodec: String, Sendable, Equatable, CaseIterable {

    /// WebVTT subtitle format.
    case webvtt = "wvtt"

    /// IMSC1 Text Profile (TTML in fMP4).
    case imsc1 = "stpp.ttml.im1t"
}
