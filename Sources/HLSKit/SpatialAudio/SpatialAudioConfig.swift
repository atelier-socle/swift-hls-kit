// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for spatial audio encoding and rendition generation.
///
/// Supports Dolby Atmos (E-AC-3 JOC), Dolby Digital (AC-3),
/// Dolby Digital Plus (E-AC-3), and discrete multichannel layouts.
///
/// ```swift
/// let config = SpatialAudioConfig(
///     format: .dolbyAtmos,
///     channelLayout: .atmos7_1_4,
///     generateStereoFallback: true
/// )
/// ```
public struct SpatialAudioConfig: Sendable, Equatable, Hashable {

    /// Spatial audio format.
    public var format: SpatialFormat

    /// Channel layout for the spatial stream.
    public var channelLayout: MultiChannelLayout

    /// Whether to auto-generate a stereo AAC fallback rendition.
    public var generateStereoFallback: Bool

    /// Bitrate in bits per second for the spatial stream.
    public var bitrate: Int

    /// Optional GROUP-ID for linking renditions to variants.
    public var groupID: String

    /// Spatial audio format enumeration.
    public enum SpatialFormat: String, Sendable, CaseIterable, Equatable, Hashable {
        /// Dolby Atmos via E-AC-3 JOC (Joint Object Coding) — immersive object-based.
        case dolbyAtmos = "atmos"
        /// Dolby Digital (AC-3) — up to 5.1 channels.
        case dolbyDigital = "ac3"
        /// Dolby Digital Plus (E-AC-3) — up to 7.1 channels.
        case dolbyDigitalPlus = "eac3"
        /// Discrete multichannel (no Dolby metadata).
        case multichannel = "multichannel"
    }

    /// Creates a spatial audio configuration.
    ///
    /// - Parameters:
    ///   - format: Spatial audio format.
    ///   - channelLayout: Channel layout for the spatial stream.
    ///   - generateStereoFallback: Whether to generate a stereo AAC fallback.
    ///   - bitrate: Bitrate in bps. Defaults per format: Atmos=768k, E-AC-3=384k, AC-3=448k, multichannel=256k.
    ///   - groupID: GROUP-ID for HLS renditions.
    public init(
        format: SpatialFormat,
        channelLayout: MultiChannelLayout,
        generateStereoFallback: Bool = true,
        bitrate: Int? = nil,
        groupID: String = "audio-spatial"
    ) {
        self.format = format
        self.channelLayout = channelLayout
        self.generateStereoFallback = generateStereoFallback
        self.bitrate = bitrate ?? Self.defaultBitrate(for: format)
        self.groupID = groupID
    }

    // MARK: - HLS Attributes

    /// HLS codec string for this configuration.
    public var hlsCodecString: String {
        switch format {
        case .dolbyAtmos: "ec+3"
        case .dolbyDigital: "ac-3"
        case .dolbyDigitalPlus: "ec-3"
        case .multichannel: "mp4a.40.2"
        }
    }

    /// HLS CHANNELS attribute value.
    public var hlsChannelsAttribute: String {
        channelLayout.hlsChannelsAttribute
    }

    /// Recommended bitrate range for this format.
    public var bitrateRange: ClosedRange<Int> {
        switch format {
        case .dolbyAtmos: 384_000...1_536_000
        case .dolbyDigital: 192_000...640_000
        case .dolbyDigitalPlus: 96_000...6_144_000
        case .multichannel: 128_000...512_000
        }
    }

    // MARK: - Presets

    /// Atmos 5.1 surround bed with stereo fallback.
    public static let atmos5_1 = SpatialAudioConfig(
        format: .dolbyAtmos,
        channelLayout: .surround5_1,
        bitrate: 768_000
    )

    /// Atmos 7.1.4 immersive bed with stereo fallback.
    public static let atmos7_1_4 = SpatialAudioConfig(
        format: .dolbyAtmos,
        channelLayout: .atmos7_1_4,
        bitrate: 768_000
    )

    /// AC-3 5.1 surround with stereo fallback.
    public static let surround5_1_ac3 = SpatialAudioConfig(
        format: .dolbyDigital,
        channelLayout: .surround5_1,
        bitrate: 448_000
    )

    /// E-AC-3 5.1 surround with stereo fallback.
    public static let surround5_1_eac3 = SpatialAudioConfig(
        format: .dolbyDigitalPlus,
        channelLayout: .surround5_1,
        bitrate: 384_000
    )

    /// E-AC-3 7.1 surround with stereo fallback.
    public static let surround7_1 = SpatialAudioConfig(
        format: .dolbyDigitalPlus,
        channelLayout: .surround7_1,
        bitrate: 512_000
    )

    // MARK: - Helpers

    /// Default bitrate per format.
    private static func defaultBitrate(
        for format: SpatialFormat
    ) -> Int {
        switch format {
        case .dolbyAtmos: 768_000
        case .dolbyDigital: 448_000
        case .dolbyDigitalPlus: 384_000
        case .multichannel: 256_000
        }
    }
}
