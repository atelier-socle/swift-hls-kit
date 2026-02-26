// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Standard video resolution presets from SD to 8K.
///
/// Each preset includes resolution, recommended bitrate ranges per codec,
/// and appropriate HLS BANDWIDTH values.
///
/// ```swift
/// let preset = ResolutionPreset.uhd4K
/// print(preset.width)      // 3840
/// print(preset.height)     // 2160
/// print(preset.bitrateRange(for: .h265, hdr: true))  // 8_000_000...25_000_000
/// ```
public struct ResolutionPreset: Sendable, Equatable, Hashable {

    /// Display name (e.g., "4K UHD").
    public let name: String

    /// Width in pixels.
    public let width: Int

    /// Height in pixels.
    public let height: Int

    /// Recommended frame rates.
    public let recommendedFrameRates: [Double]

    /// Creates a resolution preset.
    ///
    /// - Parameters:
    ///   - name: Display name.
    ///   - width: Width in pixels.
    ///   - height: Height in pixels.
    ///   - recommendedFrameRates: Recommended frame rates.
    public init(
        name: String,
        width: Int,
        height: Int,
        recommendedFrameRates: [Double]
    ) {
        self.name = name
        self.width = width
        self.height = height
        self.recommendedFrameRates = recommendedFrameRates
    }

    // MARK: - Computed Properties

    /// Resolution string (e.g., "3840x2160").
    public var resolutionString: String { "\(width)x\(height)" }

    /// Aspect ratio as a string (e.g., "16:9").
    public var aspectRatio: String {
        let divisor = gcd(width, height)
        return "\(width / divisor):\(height / divisor)"
    }

    /// Whether this is an ultra-high resolution (> 1920x1080).
    public var isUltraHighRes: Bool { width > 1920 || height > 1080 }

    /// Recommended bitrate range for a given codec and HDR setting.
    ///
    /// - Parameters:
    ///   - codec: The video codec.
    ///   - hdr: Whether HDR is enabled (adds ~20% overhead).
    /// - Returns: Recommended bitrate range in bits per second.
    public func bitrateRange(
        for codec: VideoCodec,
        hdr: Bool = false
    ) -> ClosedRange<Int> {
        let base = baseBitrateRange(for: codec)
        if hdr {
            let lower = base.lowerBound * 120 / 100
            let upper = base.upperBound * 120 / 100
            return lower...upper
        }
        return base
    }

    /// Recommended BANDWIDTH value for HLS master playlist.
    ///
    /// - Parameters:
    ///   - codec: The video codec.
    ///   - hdr: Whether HDR is enabled.
    /// - Returns: Recommended bandwidth in bits per second.
    public func recommendedBandwidth(
        for codec: VideoCodec,
        hdr: Bool = false
    ) -> Int {
        let range = bitrateRange(for: codec, hdr: hdr)
        return (range.lowerBound + range.upperBound) / 2
    }

    // MARK: - Standard Presets

    /// SD 480p (854x480).
    public static let sd480p = ResolutionPreset(
        name: "SD 480p", width: 854, height: 480,
        recommendedFrameRates: [24, 25, 30]
    )

    /// HD 720p (1280x720).
    public static let hd720p = ResolutionPreset(
        name: "HD 720p", width: 1280, height: 720,
        recommendedFrameRates: [24, 25, 30, 50, 60]
    )

    /// Full HD 1080p (1920x1080).
    public static let fullHD1080p = ResolutionPreset(
        name: "Full HD 1080p", width: 1920, height: 1080,
        recommendedFrameRates: [24, 25, 30, 50, 60]
    )

    /// QHD 1440p (2560x1440).
    public static let qhd1440p = ResolutionPreset(
        name: "QHD 1440p", width: 2560, height: 1440,
        recommendedFrameRates: [24, 25, 30, 50, 60]
    )

    /// 4K UHD (3840x2160).
    public static let uhd4K = ResolutionPreset(
        name: "4K UHD", width: 3840, height: 2160,
        recommendedFrameRates: [24, 25, 30, 50, 60]
    )

    /// Cinema 4K DCI (4096x2160).
    public static let cinema4K = ResolutionPreset(
        name: "Cinema 4K (DCI)", width: 4096, height: 2160,
        recommendedFrameRates: [24, 25, 30, 48]
    )

    /// 8K UHD (7680x4320).
    public static let uhd8K = ResolutionPreset(
        name: "8K UHD", width: 7680, height: 4320,
        recommendedFrameRates: [24, 25, 30]
    )

    /// All standard presets ordered by resolution.
    public static let allPresets: [ResolutionPreset] = [
        sd480p, hd720p, fullHD1080p, qhd1440p, uhd4K, cinema4K, uhd8K
    ]

    // MARK: - Helpers

    /// Resolution tier index for bitrate lookup.
    private var resolutionTier: Int {
        switch height {
        case ..<600: return 0
        case ..<800: return 1
        case ..<1200: return 2
        case ..<1600: return 3
        case ..<2400: return 4
        default: return 5
        }
    }

    /// Base bitrate range per codec (without HDR overhead).
    private func baseBitrateRange(for codec: VideoCodec) -> ClosedRange<Int> {
        let tier = resolutionTier
        switch codec {
        case .h264: return Self.h264Bitrates[min(tier, Self.h264Bitrates.count - 1)]
        case .h265: return Self.h265Bitrates[min(tier, Self.h265Bitrates.count - 1)]
        case .av1: return Self.av1Bitrates[min(tier, Self.av1Bitrates.count - 1)]
        case .vp9: return Self.h265Bitrates[min(tier, Self.h265Bitrates.count - 1)]
        }
    }

    /// H.264 bitrate ranges by tier: [SD, HD, FHD, QHD, 4K, 8K].
    private static let h264Bitrates: [ClosedRange<Int>] = [
        1_000_000...2_500_000,
        2_500_000...5_000_000,
        4_000_000...8_000_000,
        8_000_000...16_000_000,
        15_000_000...30_000_000,
        40_000_000...80_000_000
    ]

    /// H.265 bitrate ranges by tier: [SD, HD, FHD, QHD, 4K, 8K].
    private static let h265Bitrates: [ClosedRange<Int>] = [
        500_000...1_500_000,
        1_500_000...3_000_000,
        2_500_000...6_000_000,
        4_000_000...10_000_000,
        8_000_000...25_000_000,
        25_000_000...60_000_000
    ]

    /// AV1 bitrate ranges by tier: [SD, HD, FHD, QHD, 4K, 8K].
    private static let av1Bitrates: [ClosedRange<Int>] = [
        400_000...1_000_000,
        1_000_000...2_000_000,
        1_500_000...4_000_000,
        3_000_000...7_000_000,
        6_000_000...16_000_000,
        15_000_000...40_000_000
    ]
}

/// Greatest common divisor.
private func gcd(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : gcd(b, a % b)
}
