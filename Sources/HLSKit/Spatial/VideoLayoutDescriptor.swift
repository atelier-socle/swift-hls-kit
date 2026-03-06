// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Describes the complete video layout for `REQ-VIDEO-LAYOUT` attribute.
///
/// Combines channel layout (stereo/mono) with projection type
/// (360°, 180°, Apple Immersive, etc.) for spatial video signaling.
///
/// Examples:
/// - `"CH-STEREO"` → stereo video, rectilinear
/// - `"PROJ-EQUI"` → mono 360° video
/// - `"CH-STEREO,PROJ-HEQU"` → stereo 180° hemisphere (Apple Immersive)
/// - `"CH-STEREO,PROJ-AIV"` → Apple Immersive Video
///
/// ```swift
/// let layout = VideoLayoutDescriptor.immersive180
/// print(layout.attributeValue)  // "CH-STEREO,PROJ-HEQU"
/// ```
public struct VideoLayoutDescriptor: Sendable, Equatable, Hashable, Codable {

    /// Channel layout (CH-STEREO, CH-MONO). Nil for projection-only declarations.
    public var channelLayout: VideoChannelLayout?

    /// Video projection type. Nil for standard rectilinear video.
    public var projection: VideoProjection?

    /// Creates a video layout descriptor.
    ///
    /// - Parameters:
    ///   - channelLayout: Channel layout (stereo/mono), or nil.
    ///   - projection: Video projection type, or nil.
    public init(
        channelLayout: VideoChannelLayout? = nil,
        projection: VideoProjection? = nil
    ) {
        self.channelLayout = channelLayout
        self.projection = projection
    }

    /// Renders as the `REQ-VIDEO-LAYOUT` attribute value string.
    ///
    /// Returns comma-separated components (e.g., `"CH-STEREO,PROJ-HEQU"`).
    public var attributeValue: String {
        var components: [String] = []
        if let channelLayout {
            components.append(channelLayout.rawValue)
        }
        if let projection {
            components.append(projection.rawValue)
        }
        return components.joined(separator: ",")
    }

    /// Parses a `REQ-VIDEO-LAYOUT` attribute string into a descriptor.
    ///
    /// Handles single values (`"CH-STEREO"`), projections (`"PROJ-EQUI"`),
    /// and combinations (`"CH-STEREO,PROJ-HEQU"`).
    ///
    /// - Parameter value: The raw attribute value string.
    /// - Returns: A parsed video layout descriptor.
    public static func parse(_ value: String) -> VideoLayoutDescriptor {
        let components = value.split(separator: ",").map {
            String($0.trimmingCharacters(in: .whitespaces))
        }
        var channelLayout: VideoChannelLayout?
        var projection: VideoProjection?

        for component in components {
            if let layout = VideoChannelLayout(rawValue: component) {
                channelLayout = layout
            } else if let proj = VideoProjection(rawValue: component) {
                projection = proj
            }
        }
        return VideoLayoutDescriptor(
            channelLayout: channelLayout,
            projection: projection
        )
    }
}

// MARK: - Presets

extension VideoLayoutDescriptor {

    /// Standard stereoscopic (e.g., Vision Pro MV-HEVC without projection).
    public static let stereo = VideoLayoutDescriptor(
        channelLayout: .stereoLeftRight
    )

    /// Monoscopic standard video.
    public static let mono = VideoLayoutDescriptor(
        channelLayout: .mono
    )

    /// 360° equirectangular video.
    public static let video360 = VideoLayoutDescriptor(
        projection: .equirectangular
    )

    /// 180° stereoscopic (Apple Immersive style).
    public static let immersive180 = VideoLayoutDescriptor(
        channelLayout: .stereoLeftRight,
        projection: .halfEquirectangular
    )

    /// Apple Immersive Video (stereo + AIV projection).
    public static let appleImmersive = VideoLayoutDescriptor(
        channelLayout: .stereoLeftRight,
        projection: .appleImmersiveVideo
    )
}
