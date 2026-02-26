// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates HLS variant entries with correct HDR attributes.
///
/// Produces `EXT-X-STREAM-INF` attribute sets for HDR content,
/// including `VIDEO-RANGE`, `SUPPLEMENTAL-CODECS`, `CODECS`,
/// `RESOLUTION`, and `BANDWIDTH`.
///
/// ```swift
/// let generator = HDRVariantGenerator()
/// let variants = generator.generateVariants(
///     hdrConfig: .dolbyVisionProfile8,
///     resolutions: [.fullHD1080p, .uhd4K],
///     codec: .h265
/// )
/// ```
public struct HDRVariantGenerator: Sendable {

    /// Creates an HDR variant generator.
    public init() {}

    // MARK: - VariantDescriptor

    /// A generated variant descriptor with HDR-relevant attributes.
    public struct VariantDescriptor: Sendable, Equatable {

        /// Resolution.
        public let resolution: ResolutionPreset

        /// VIDEO-RANGE attribute.
        public let videoRange: VideoRange

        /// CODECS string.
        public let codecs: String

        /// SUPPLEMENTAL-CODECS string (nil if not DV).
        public let supplementalCodecs: String?

        /// Recommended BANDWIDTH.
        public let bandwidth: Int

        /// Frame rate.
        public let frameRate: Double?

        /// Whether this is an SDR fallback variant.
        public let isSDRFallback: Bool

        /// Formats as EXT-X-STREAM-INF attribute string (without the tag name).
        public func formatAttributes() -> String {
            var attrs: [String] = [
                "BANDWIDTH=\(bandwidth)",
                "RESOLUTION=\(resolution.resolutionString)",
                "CODECS=\"\(codecs)\"",
                "VIDEO-RANGE=\(videoRange.rawValue)"
            ]
            if let supplementalCodecs {
                attrs.append("SUPPLEMENTAL-CODECS=\"\(supplementalCodecs)\"")
            }
            if let frameRate {
                attrs.append(String(format: "FRAME-RATE=%.3f", frameRate))
            }
            return attrs.joined(separator: ",")
        }
    }

    // MARK: - Generation

    /// Generate variant descriptors for an HDR configuration across resolutions.
    ///
    /// - Parameters:
    ///   - hdrConfig: The HDR configuration.
    ///   - resolutions: Target resolutions.
    ///   - codec: Video codec. Default is H.265.
    ///   - frameRate: Optional frame rate.
    /// - Returns: Array of variant descriptors. Includes SDR fallbacks if configured.
    public func generateVariants(
        hdrConfig: HDRConfig,
        resolutions: [ResolutionPreset],
        codec: VideoCodec = .h265,
        frameRate: Double? = nil
    ) -> [VariantDescriptor] {
        let mapper = VideoRangeMapper()
        var variants: [VariantDescriptor] = []

        for resolution in resolutions {
            let attrs = mapper.mapToHLSAttributes(
                config: hdrConfig,
                resolution: resolution,
                codec: codec
            )
            let hdrVariant = VariantDescriptor(
                resolution: resolution,
                videoRange: attrs.videoRange,
                codecs: attrs.recommendedCodecs ?? codecString(for: codec, hdr: true),
                supplementalCodecs: attrs.supplementalCodecs,
                bandwidth: resolution.recommendedBandwidth(for: codec, hdr: true),
                frameRate: frameRate,
                isSDRFallback: false
            )
            variants.append(hdrVariant)
        }

        if hdrConfig.generateSDRFallback {
            for resolution in resolutions {
                let sdrVariant = VariantDescriptor(
                    resolution: resolution,
                    videoRange: .sdr,
                    codecs: codecString(for: codec, hdr: false),
                    supplementalCodecs: nil,
                    bandwidth: resolution.recommendedBandwidth(for: codec, hdr: false),
                    frameRate: frameRate,
                    isSDRFallback: true
                )
                variants.append(sdrVariant)
            }
        }

        return variants
    }

    /// Generate a complete adaptive bitrate ladder with HDR.
    ///
    /// Returns variants from lowest to highest resolution/bitrate.
    /// Uses standard resolutions from SD to 4K (or 8K for H.265/AV1).
    ///
    /// - Parameters:
    ///   - hdrConfig: The HDR configuration.
    ///   - codec: Video codec. Default is H.265.
    ///   - frameRate: Frame rate. Default is 30.
    /// - Returns: Sorted array of variant descriptors.
    public func generateAdaptiveLadder(
        hdrConfig: HDRConfig,
        codec: VideoCodec = .h265,
        frameRate: Double = 30
    ) -> [VariantDescriptor] {
        let resolutions: [ResolutionPreset]
        switch codec {
        case .h265, .av1:
            resolutions = [.sd480p, .hd720p, .fullHD1080p, .qhd1440p, .uhd4K, .uhd8K]
        case .h264, .vp9:
            resolutions = [.sd480p, .hd720p, .fullHD1080p, .qhd1440p, .uhd4K]
        }

        return generateVariants(
            hdrConfig: hdrConfig,
            resolutions: resolutions,
            codec: codec,
            frameRate: frameRate
        )
    }

    // MARK: - Validation

    /// Validate a set of variant descriptors for HLS compliance.
    ///
    /// Checks consistent VIDEO-RANGE grouping, bandwidth ordering,
    /// and codec consistency.
    ///
    /// - Parameter variants: The variant descriptors to validate.
    /// - Returns: Array of warning messages. Empty means valid.
    public func validateLadder(_ variants: [VariantDescriptor]) -> [String] {
        var warnings: [String] = []

        let hdrVariants = variants.filter { !$0.isSDRFallback }
        let videoRanges = Set(hdrVariants.map(\.videoRange))
        if videoRanges.count > 1 {
            let rangeStrings = videoRanges.map(\.rawValue).sorted()
            warnings.append(
                "Mixed VIDEO-RANGE values in HDR variants: \(rangeStrings.joined(separator: ", "))"
            )
        }

        let codecFamilies = Set(hdrVariants.map { codecFamily($0.codecs) })
        if codecFamilies.count > 1 {
            warnings.append(
                "Inconsistent CODECS across HDR variants"
            )
        }

        for index in 1..<hdrVariants.count
        where hdrVariants[index].bandwidth < hdrVariants[index - 1].bandwidth {
            warnings.append(
                "Bandwidth not ascending at index \(index): "
                    + "\(hdrVariants[index].bandwidth) < \(hdrVariants[index - 1].bandwidth)"
            )
        }

        return warnings
    }

    // MARK: - Helpers

    /// Extract codec family prefix (e.g., "hvc1" from "hvc1.2.4.L153.B0").
    private func codecFamily(_ codecs: String) -> String {
        String(codecs.prefix(while: { $0 != "." }))
    }

    /// Generate a codec string for a given codec and HDR flag.
    private func codecString(for codec: VideoCodec, hdr: Bool) -> String {
        switch codec {
        case .h265:
            return hdr ? "hvc1.2.4.L150.B0" : "hvc1.1.6.L150.B0"
        case .h264:
            return hdr ? "avc1.640033" : "avc1.640028"
        case .av1:
            return hdr ? "av01.0.09M.10" : "av01.0.09M.08"
        case .vp9:
            return hdr ? "vp09.02.10.10" : "vp09.00.10.08"
        }
    }
}
