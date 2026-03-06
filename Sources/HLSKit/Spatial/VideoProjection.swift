// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Video projection type for `REQ-VIDEO-LAYOUT` attribute.
///
/// Specifies the spatial projection of video content (360°, 180°,
/// rectilinear, or Apple Immersive Video).
///
/// Reference: RFC 8216bis-20, WWDC 2025 "What's new in HLS".
///
/// ```swift
/// let projection = VideoProjection.equirectangular
/// print(projection.rawValue)  // "PROJ-EQUI"
/// ```
public enum VideoProjection: String, Sendable, Equatable, Hashable, Codable, CaseIterable {
    /// Standard rectilinear (flat) video projection.
    /// This is the default — typically not declared explicitly in manifests.
    case rectilinear = "PROJ-RECT"

    /// Equirectangular projection mapping a full 360° sphere.
    case equirectangular = "PROJ-EQUI"

    /// Half equirectangular projection (180° hemisphere).
    /// Typical for Apple Immersive content captured with spatial cameras.
    case halfEquirectangular = "PROJ-HEQU"

    /// Primary projection (device-specific interpretation).
    case primary = "PROJ-PRIM"

    /// Apple Immersive Video format for Vision Pro.
    case appleImmersiveVideo = "PROJ-AIV"
}
