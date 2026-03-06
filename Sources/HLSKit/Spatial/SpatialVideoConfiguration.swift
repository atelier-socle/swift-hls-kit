// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for spatial (stereoscopic) video packaging.
///
/// Describes codec, layout, and resolution parameters for MV-HEVC
/// and Dolby Vision stereoscopic content targeting Apple Vision Pro.
///
/// ```swift
/// let config = SpatialVideoConfiguration.visionProStandard
/// print(config.channelLayout.rawValue)  // "CH-STEREO"
/// ```
public struct SpatialVideoConfiguration: Sendable, Equatable {

    /// Base layer codec string (e.g. "hvc1.2.4.L123.B0").
    public var baseLayerCodec: String

    /// Supplemental codecs string for Dolby Vision or MV-HEVC layers.
    public var supplementalCodecs: String?

    /// Video channel layout (stereo or mono).
    public var channelLayout: VideoChannelLayout

    /// Dolby Vision profile number, if applicable.
    public var dolbyVisionProfile: Int?

    /// Video width in pixels.
    public var width: Int

    /// Video height in pixels.
    public var height: Int

    /// Video frame rate in frames per second.
    public var frameRate: Double

    /// Creates a spatial video configuration.
    ///
    /// - Parameters:
    ///   - baseLayerCodec: Base layer codec string.
    ///   - supplementalCodecs: Supplemental codecs string.
    ///   - channelLayout: Video channel layout.
    ///   - dolbyVisionProfile: Dolby Vision profile number.
    ///   - width: Video width in pixels.
    ///   - height: Video height in pixels.
    ///   - frameRate: Video frame rate.
    public init(
        baseLayerCodec: String,
        supplementalCodecs: String? = nil,
        channelLayout: VideoChannelLayout = .stereoLeftRight,
        dolbyVisionProfile: Int? = nil,
        width: Int,
        height: Int,
        frameRate: Double
    ) {
        self.baseLayerCodec = baseLayerCodec
        self.supplementalCodecs = supplementalCodecs
        self.channelLayout = channelLayout
        self.dolbyVisionProfile = dolbyVisionProfile
        self.width = width
        self.height = height
        self.frameRate = frameRate
    }
}

// MARK: - Presets

extension SpatialVideoConfiguration {

    /// Standard Vision Pro preset: 1080p stereo MV-HEVC at 30 fps.
    public static var visionProStandard: Self {
        Self(
            baseLayerCodec: "hvc1.2.4.L123.B0",
            channelLayout: .stereoLeftRight,
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )
    }

    /// High-quality Vision Pro preset: 4K stereo MV-HEVC at 30 fps.
    public static var visionProHighQuality: Self {
        Self(
            baseLayerCodec: "hvc1.2.4.L153.B0",
            channelLayout: .stereoLeftRight,
            width: 3840,
            height: 2160,
            frameRate: 30.0
        )
    }

    /// Dolby Vision stereo preset: 4K DV Profile 20 at 30 fps.
    public static var dolbyVisionStereo: Self {
        Self(
            baseLayerCodec: "hvc1.2.4.L153.B0",
            supplementalCodecs: "dvh1.20.09/db4h",
            channelLayout: .stereoLeftRight,
            dolbyVisionProfile: 20,
            width: 3840,
            height: 2160,
            frameRate: 30.0
        )
    }
}
