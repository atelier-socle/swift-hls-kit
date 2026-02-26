// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Unified HDR configuration for HLS video streams.
///
/// Maps to the correct `VIDEO-RANGE` and `SUPPLEMENTAL-CODECS` attributes
/// in HLS master playlists via ``VideoRangeMapper``.
///
/// ```swift
/// let config = HDRConfig(type: .dolbyVision, dolbyVisionProfile: .profile8_1)
/// print(config.videoRange)          // .pq
/// print(config.supplementalCodecs)  // "dvh1.08.01"
/// ```
public struct HDRConfig: Sendable, Equatable, Hashable {

    /// HDR format type.
    public var type: HDRType

    /// Static HDR10 metadata (only for .hdr10 and .hdr10Plus).
    public var staticMetadata: HDR10StaticMetadata?

    /// Dolby Vision profile (only for .dolbyVision and .dolbyVisionWithHDR10Fallback).
    public var dolbyVisionProfile: DolbyVisionProfile?

    /// Whether to generate an SDR fallback variant.
    public var generateSDRFallback: Bool

    /// Creates an HDR configuration.
    ///
    /// - Parameters:
    ///   - type: HDR format type.
    ///   - staticMetadata: Optional HDR10 static metadata.
    ///   - dolbyVisionProfile: Optional Dolby Vision profile.
    ///   - generateSDRFallback: Whether to generate SDR fallback. Default is true.
    public init(
        type: HDRType,
        staticMetadata: HDR10StaticMetadata? = nil,
        dolbyVisionProfile: DolbyVisionProfile? = nil,
        generateSDRFallback: Bool = true
    ) {
        self.type = type
        self.staticMetadata = staticMetadata
        self.dolbyVisionProfile = dolbyVisionProfile
        self.generateSDRFallback = generateSDRFallback
    }

    // MARK: - HDRType

    /// HDR format types.
    public enum HDRType: String, Sendable, CaseIterable, Equatable, Hashable {
        /// HDR10: SMPTE ST 2084 (PQ) with static metadata.
        case hdr10 = "hdr10"
        /// HDR10+: PQ with dynamic scene-by-scene metadata.
        case hdr10Plus = "hdr10plus"
        /// Dolby Vision: proprietary HDR with RPU.
        case dolbyVision = "dolby-vision"
        /// HLG: Hybrid Log-Gamma (BBC/NHK), backward-compatible with SDR displays.
        case hlg = "hlg"
        /// Dolby Vision with HDR10 base layer fallback.
        case dolbyVisionWithHDR10Fallback = "dolby-vision-hdr10"
    }

    // MARK: - Computed Properties

    /// Maps to HLS VIDEO-RANGE attribute.
    public var videoRange: VideoRange {
        switch type {
        case .hdr10, .hdr10Plus, .dolbyVision, .dolbyVisionWithHDR10Fallback:
            .pq
        case .hlg:
            .hlg
        }
    }

    /// Maps to HLS SUPPLEMENTAL-CODECS (nil if not applicable).
    public var supplementalCodecs: String? {
        switch type {
        case .dolbyVision, .dolbyVisionWithHDR10Fallback:
            dolbyVisionProfile?.supplementalCodecsString
        case .hdr10, .hdr10Plus, .hlg:
            nil
        }
    }

    /// Required color space for this HDR type.
    public var requiredColorSpace: VideoColorSpace {
        switch type {
        case .hdr10, .hdr10Plus, .dolbyVision, .dolbyVisionWithHDR10Fallback:
            .hdr10
        case .hlg:
            .hlg
        }
    }

    /// Recommended minimum bit depth.
    public var minimumBitDepth: Int {
        if let dvProfile = dolbyVisionProfile,
            dvProfile.profile == 8, dvProfile.level >= 4
        {
            return 12
        }
        return 10
    }

    // MARK: - Presets

    /// HDR10 default configuration.
    public static let hdr10Default = HDRConfig(type: .hdr10)

    /// HDR10+ default configuration.
    public static let hdr10PlusDefault = HDRConfig(type: .hdr10Plus)

    /// Dolby Vision profile 5 (single-layer HEVC, 10-bit).
    public static let dolbyVisionProfile5 = HDRConfig(
        type: .dolbyVision,
        dolbyVisionProfile: .profile5
    )

    /// Dolby Vision profile 8.1 with HDR10 base layer fallback.
    public static let dolbyVisionProfile8 = HDRConfig(
        type: .dolbyVisionWithHDR10Fallback,
        dolbyVisionProfile: .profile8_1
    )

    /// HLG default configuration.
    public static let hlgDefault = HDRConfig(type: .hlg)
}

// MARK: - HDR10StaticMetadata

/// SMPTE ST 2086 mastering display metadata for HDR10.
public struct HDR10StaticMetadata: Sendable, Equatable, Hashable {

    /// Maximum content light level (MaxCLL) in cd/m2.
    public var maxContentLightLevel: Int

    /// Maximum frame-average light level (MaxFALL) in cd/m2.
    public var maxFrameAverageLightLevel: Int

    /// Mastering display color primaries (CIE 1931 xy).
    public var masteringDisplayPrimaries: MasteringDisplayPrimaries?

    /// Mastering display luminance range.
    public var masteringDisplayLuminance: MasteringDisplayLuminance?

    /// Creates HDR10 static metadata.
    ///
    /// - Parameters:
    ///   - maxContentLightLevel: MaxCLL in cd/m2.
    ///   - maxFrameAverageLightLevel: MaxFALL in cd/m2.
    ///   - masteringDisplayPrimaries: Optional mastering display primaries.
    ///   - masteringDisplayLuminance: Optional mastering display luminance.
    public init(
        maxContentLightLevel: Int,
        maxFrameAverageLightLevel: Int,
        masteringDisplayPrimaries: MasteringDisplayPrimaries? = nil,
        masteringDisplayLuminance: MasteringDisplayLuminance? = nil
    ) {
        self.maxContentLightLevel = maxContentLightLevel
        self.maxFrameAverageLightLevel = maxFrameAverageLightLevel
        self.masteringDisplayPrimaries = masteringDisplayPrimaries
        self.masteringDisplayLuminance = masteringDisplayLuminance
    }
}

// MARK: - MasteringDisplayPrimaries

/// CIE 1931 xy color primaries for mastering display.
public struct MasteringDisplayPrimaries: Sendable, Equatable, Hashable {

    /// Red primary x coordinate.
    public let redX: Double
    /// Red primary y coordinate.
    public let redY: Double
    /// Green primary x coordinate.
    public let greenX: Double
    /// Green primary y coordinate.
    public let greenY: Double
    /// Blue primary x coordinate.
    public let blueX: Double
    /// Blue primary y coordinate.
    public let blueY: Double
    /// White point x coordinate.
    public let whitePointX: Double
    /// White point y coordinate.
    public let whitePointY: Double

    /// Creates mastering display primaries.
    ///
    /// - Parameters:
    ///   - redX: Red primary x.
    ///   - redY: Red primary y.
    ///   - greenX: Green primary x.
    ///   - greenY: Green primary y.
    ///   - blueX: Blue primary x.
    ///   - blueY: Blue primary y.
    ///   - whitePointX: White point x.
    ///   - whitePointY: White point y.
    public init(
        redX: Double, redY: Double,
        greenX: Double, greenY: Double,
        blueX: Double, blueY: Double,
        whitePointX: Double, whitePointY: Double
    ) {
        self.redX = redX
        self.redY = redY
        self.greenX = greenX
        self.greenY = greenY
        self.blueX = blueX
        self.blueY = blueY
        self.whitePointX = whitePointX
        self.whitePointY = whitePointY
    }

    /// BT.2020 wide color gamut (standard for HDR10).
    public static let bt2020 = MasteringDisplayPrimaries(
        redX: 0.708, redY: 0.292,
        greenX: 0.170, greenY: 0.797,
        blueX: 0.131, blueY: 0.046,
        whitePointX: 0.3127, whitePointY: 0.3290
    )

    /// Display P3 (Apple displays).
    public static let displayP3 = MasteringDisplayPrimaries(
        redX: 0.680, redY: 0.320,
        greenX: 0.265, greenY: 0.690,
        blueX: 0.150, blueY: 0.060,
        whitePointX: 0.3127, whitePointY: 0.3290
    )
}

// MARK: - MasteringDisplayLuminance

/// Mastering display luminance range.
public struct MasteringDisplayLuminance: Sendable, Equatable, Hashable {

    /// Minimum luminance in cd/m2 (e.g., 0.0001).
    public let minLuminance: Double

    /// Maximum luminance in cd/m2 (e.g., 1000, 4000, 10000).
    public let maxLuminance: Double

    /// Creates mastering display luminance.
    ///
    /// - Parameters:
    ///   - minLuminance: Minimum luminance in cd/m2.
    ///   - maxLuminance: Maximum luminance in cd/m2.
    public init(minLuminance: Double, maxLuminance: Double) {
        self.minLuminance = minLuminance
        self.maxLuminance = maxLuminance
    }

    /// Standard HDR10 mastering display (1000 nits peak).
    public static let standard1000nits = MasteringDisplayLuminance(
        minLuminance: 0.0001, maxLuminance: 1000
    )

    /// High-end mastering display (4000 nits peak).
    public static let premium4000nits = MasteringDisplayLuminance(
        minLuminance: 0.0001, maxLuminance: 4000
    )

    /// Reference mastering display (10000 nits peak).
    public static let reference10000nits = MasteringDisplayLuminance(
        minLuminance: 0.00001, maxLuminance: 10000
    )
}
