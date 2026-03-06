// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Video channel layout for stereoscopic content.
///
/// Maps to `REQ-VIDEO-LAYOUT` values in HLS multivariant playlists.
///
/// ```swift
/// let layout = VideoChannelLayout.stereoLeftRight
/// print(layout.rawValue)  // "CH-STEREO"
/// ```
public enum VideoChannelLayout: String, Sendable, Equatable, CaseIterable {
    /// Stereoscopic left/right layout (MV-HEVC).
    case stereoLeftRight = "CH-STEREO"
    /// Monoscopic layout (single view).
    case mono = "CH-MONO"
}
