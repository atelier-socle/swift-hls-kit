// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Maps HDR configurations to HLS manifest attributes.
///
/// Translates ``HDRConfig`` into the correct `VIDEO-RANGE` and
/// `SUPPLEMENTAL-CODECS` values for `EXT-X-STREAM-INF`.
///
/// ```swift
/// let mapper = VideoRangeMapper()
/// let attrs = mapper.mapToHLSAttributes(config: .dolbyVisionProfile8)
/// // attrs.videoRange = .pq
/// // attrs.supplementalCodecs = "dvh1.08.01"
/// ```
public struct VideoRangeMapper: Sendable {

    /// Creates a video range mapper.
    public init() {}

    // MARK: - HLSAttributes

    /// HLS attributes derived from an HDR configuration.
    public struct HLSAttributes: Sendable, Equatable {
        /// VIDEO-RANGE value.
        public let videoRange: VideoRange
        /// SUPPLEMENTAL-CODECS value (nil for non-DV content).
        public let supplementalCodecs: String?
        /// Recommended CODECS string for the base codec.
        public let recommendedCodecs: String?
        /// Minimum required bit depth.
        public let minimumBitDepth: Int
        /// Required color space.
        public let colorSpace: VideoColorSpace
    }

    // MARK: - Mapping

    /// Map an HDR config to HLS attributes.
    ///
    /// - Parameter config: The HDR configuration.
    /// - Returns: HLS attributes for the given config.
    public func mapToHLSAttributes(config: HDRConfig) -> HLSAttributes {
        HLSAttributes(
            videoRange: config.videoRange,
            supplementalCodecs: config.supplementalCodecs,
            recommendedCodecs: codecString(for: .h265, hdr: true),
            minimumBitDepth: config.minimumBitDepth,
            colorSpace: config.requiredColorSpace
        )
    }

    /// Map an HDR config to HLS attributes for a specific resolution and codec.
    ///
    /// - Parameters:
    ///   - config: The HDR configuration.
    ///   - resolution: The target resolution.
    ///   - codec: The video codec.
    /// - Returns: HLS attributes for the given config, resolution, and codec.
    public func mapToHLSAttributes(
        config: HDRConfig,
        resolution: ResolutionPreset,
        codec: VideoCodec
    ) -> HLSAttributes {
        HLSAttributes(
            videoRange: config.videoRange,
            supplementalCodecs: config.supplementalCodecs,
            recommendedCodecs: codecString(for: codec, hdr: true, resolution: resolution),
            minimumBitDepth: config.minimumBitDepth,
            colorSpace: config.requiredColorSpace
        )
    }

    // MARK: - Validation

    /// Validate that a Variant's attributes are consistent with its HDR config.
    ///
    /// - Parameters:
    ///   - variant: The variant to validate.
    ///   - expectedConfig: The expected HDR configuration.
    /// - Returns: Array of warning messages. Empty means valid.
    public func validateVariant(
        _ variant: Variant,
        expectedConfig: HDRConfig
    ) -> [String] {
        var warnings: [String] = []

        let expectedRange = expectedConfig.videoRange
        if let variantRange = variant.videoRange, variantRange != expectedRange {
            warnings.append(
                "VIDEO-RANGE mismatch: expected \(expectedRange.rawValue), got \(variantRange.rawValue)"
            )
        } else if variant.videoRange == nil {
            warnings.append(
                "VIDEO-RANGE missing: expected \(expectedRange.rawValue)"
            )
        }

        let expectedSupplemental = expectedConfig.supplementalCodecs
        if expectedSupplemental != nil && variant.supplementalCodecs == nil {
            warnings.append(
                "SUPPLEMENTAL-CODECS missing for Dolby Vision content"
            )
        }

        if let variantSupplemental = variant.supplementalCodecs,
            let expected = expectedSupplemental,
            variantSupplemental != expected
        {
            warnings.append(
                "SUPPLEMENTAL-CODECS mismatch: expected \(expected), got \(variantSupplemental)"
            )
        }

        return warnings
    }

    // MARK: - Helpers

    /// Generate a codec string for a given codec, HDR flag, and optional resolution.
    private func codecString(
        for codec: VideoCodec,
        hdr: Bool,
        resolution: ResolutionPreset? = nil
    ) -> String {
        let level = hevcLevel(for: resolution)
        switch codec {
        case .h265:
            let profile = hdr ? "2.4" : "1.6"
            return "hvc1.\(profile).L\(level).B0"
        case .h264:
            return hdr ? "avc1.640033" : "avc1.640028"
        case .av1:
            let bitDepth = hdr ? "10" : "08"
            return "av01.0.09M.\(bitDepth)"
        case .vp9:
            return hdr ? "vp09.02.10.10" : "vp09.00.10.08"
        }
    }

    /// Map resolution to HEVC level.
    private func hevcLevel(for resolution: ResolutionPreset?) -> Int {
        guard let resolution else { return 150 }
        switch resolution.height {
        case ..<720: return 93
        case ..<1080: return 120
        case ..<1440: return 123
        case ..<2160: return 150
        case ..<4320: return 153
        default: return 183
        }
    }
}
