// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for Hi-Res audio in HLS.
///
/// Supports high sample rates (96/192 kHz), high bit depths (24/32-bit),
/// and lossless codecs (ALAC, FLAC) alongside standard AAC.
///
/// ```swift
/// let hiRes = HiResAudioConfig(
///     sampleRate: .rate96kHz,
///     bitDepth: .depth24,
///     codec: .alac
/// )
/// print(hiRes.hlsCodecString)  // "alac"
/// ```
public struct HiResAudioConfig: Sendable, Equatable, Hashable {

    /// Sample rate tier.
    public var sampleRate: SampleRateTier

    /// Bit depth.
    public var bitDepth: BitDepth

    /// Lossless or lossy codec.
    public var codec: HiResCodec

    /// Whether to include a standard-quality AAC fallback.
    public var generateAACFallback: Bool

    /// AAC fallback bitrate (used if generateAACFallback is true).
    public var aacFallbackBitrate: Int

    /// Creates a Hi-Res audio configuration.
    ///
    /// - Parameters:
    ///   - sampleRate: Sample rate tier. Default is 96 kHz.
    ///   - bitDepth: Bit depth. Default is 24-bit.
    ///   - codec: Audio codec. Default is ALAC.
    ///   - generateAACFallback: Whether to include AAC fallback. Default is true.
    ///   - aacFallbackBitrate: AAC fallback bitrate in bps. Default is 256,000.
    public init(
        sampleRate: SampleRateTier = .rate96kHz,
        bitDepth: BitDepth = .depth24,
        codec: HiResCodec = .alac,
        generateAACFallback: Bool = true,
        aacFallbackBitrate: Int = 256_000
    ) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.codec = codec
        self.generateAACFallback = generateAACFallback
        self.aacFallbackBitrate = aacFallbackBitrate
    }

    // MARK: - Sample Rate Tiers

    /// Sample rate tiers for Hi-Res audio.
    public enum SampleRateTier: Double, Sendable, CaseIterable, Comparable, Hashable {
        /// 44.1 kHz (CD quality).
        case rate44_1kHz = 44100
        /// 48 kHz (standard broadcast).
        case rate48kHz = 48000
        /// 88.2 kHz (2x CD rate).
        case rate88_2kHz = 88200
        /// 96 kHz (Hi-Res standard).
        case rate96kHz = 96000
        /// 176.4 kHz (4x CD rate).
        case rate176_4kHz = 176400
        /// 192 kHz (Hi-Res maximum).
        case rate192kHz = 192000

        /// Whether this is a Hi-Res rate (> 48 kHz).
        public var isHiRes: Bool { rawValue > 48000 }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Bit Depth

    /// Bit depth options for Hi-Res audio.
    public enum BitDepth: Int, Sendable, CaseIterable, Comparable, Hashable {
        /// 16-bit (CD quality).
        case depth16 = 16
        /// 24-bit (Hi-Res standard).
        case depth24 = 24
        /// 32-bit (studio master).
        case depth32 = 32

        /// Whether this is Hi-Res depth (> 16-bit).
        public var isHiRes: Bool { rawValue > 16 }

        public static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: - Hi-Res Codecs

    /// Hi-Res audio codecs.
    public enum HiResCodec: String, Sendable, CaseIterable, Hashable {
        /// Apple Lossless Audio Codec.
        case alac
        /// Free Lossless Audio Codec.
        case flac
        /// HE-AAC (high efficiency, lossy).
        case aacHE
        /// AAC-LC (standard quality baseline).
        case aacLC
    }

    // MARK: - Computed Properties

    /// HLS codec string for this configuration.
    public var hlsCodecString: String {
        switch codec {
        case .alac: "alac"
        case .flac: "fLaC"
        case .aacHE: "mp4a.40.5"
        case .aacLC: "mp4a.40.2"
        }
    }

    /// Estimated bitrate for the configured format.
    ///
    /// Lossless codecs estimate based on sample rate, bit depth, and 2 channels.
    /// Lossy codecs return typical bitrates for the quality tier.
    public var estimatedBitrate: Int {
        switch codec {
        case .alac, .flac:
            // Approximate: sampleRate × bitDepth × 2 channels × compression ratio
            let raw = Int(sampleRate.rawValue) * bitDepth.rawValue * 2
            // Lossless typically achieves ~60% compression
            return raw * 60 / 100
        case .aacHE:
            return sampleRate.isHiRes ? 128_000 : 64_000
        case .aacLC:
            return sampleRate.isHiRes ? 320_000 : 256_000
        }
    }

    /// Whether this configuration qualifies as "Hi-Res" per industry standards.
    public var isHiRes: Bool {
        sampleRate.isHiRes || bitDepth.isHiRes
    }

    // MARK: - Presets

    /// CD quality: 44.1 kHz, 16-bit, ALAC.
    public static let cdQuality = HiResAudioConfig(
        sampleRate: .rate44_1kHz,
        bitDepth: .depth16,
        codec: .alac
    )

    /// Studio Hi-Res: 96 kHz, 24-bit, ALAC.
    public static let studioHiRes = HiResAudioConfig(
        sampleRate: .rate96kHz,
        bitDepth: .depth24,
        codec: .alac
    )

    /// Master Hi-Res: 192 kHz, 24-bit, FLAC.
    public static let masterHiRes = HiResAudioConfig(
        sampleRate: .rate192kHz,
        bitDepth: .depth24,
        codec: .flac
    )

    /// Audiophile: 192 kHz, 32-bit, FLAC.
    public static let audiophile = HiResAudioConfig(
        sampleRate: .rate192kHz,
        bitDepth: .depth32,
        codec: .flac
    )
}
