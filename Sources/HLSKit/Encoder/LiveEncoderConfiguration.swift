// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for a ``LiveEncoder``.
///
/// Describes the desired output format: codec, bitrate, sample rate,
/// channels, and AAC profile. Use the built-in presets for common
/// podcast and music encoding scenarios.
///
/// ## Presets
/// ```swift
/// let config = LiveEncoderConfiguration.podcastAudio
/// let config = LiveEncoderConfiguration.musicAudio
/// ```
///
/// ## Custom Configuration
/// ```swift
/// let config = LiveEncoderConfiguration(
///     audioCodec: .aac,
///     bitrate: 256_000,
///     sampleRate: 48000,
///     channels: 2,
///     aacProfile: .lc
/// )
/// ```
public struct LiveEncoderConfiguration: Sendable, Equatable, Hashable {

    /// Target audio codec for encoding.
    public let audioCodec: AudioCodec

    /// Video codec for video encoding. Nil for audio-only.
    public let videoCodec: VideoCodec?

    /// Target bitrate in bits per second.
    public let bitrate: Int

    /// Output sample rate in Hz.
    public let sampleRate: Double

    /// Number of output channels.
    public let channels: Int

    /// AAC profile to use. Nil for non-AAC codecs.
    public let aacProfile: AACProfile?

    /// Whether to pass through audio without re-encoding.
    public let passthrough: Bool

    /// Creates a live encoder configuration.
    ///
    /// - Parameters:
    ///   - audioCodec: Target audio codec.
    ///   - videoCodec: Target video codec. Nil for audio-only.
    ///   - bitrate: Target bitrate in bits per second.
    ///   - sampleRate: Output sample rate in Hz.
    ///   - channels: Number of output channels.
    ///   - aacProfile: AAC profile. Nil for non-AAC codecs.
    ///   - passthrough: Whether to pass through without re-encoding.
    public init(
        audioCodec: AudioCodec,
        videoCodec: VideoCodec? = nil,
        bitrate: Int,
        sampleRate: Double,
        channels: Int,
        aacProfile: AACProfile? = nil,
        passthrough: Bool = false
    ) {
        self.audioCodec = audioCodec
        self.videoCodec = videoCodec
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
        self.aacProfile = aacProfile
        self.passthrough = passthrough
    }
}

// MARK: - Presets

extension LiveEncoderConfiguration {

    /// Podcast audio — AAC-LC, 64 kbps, 44.1 kHz, mono.
    ///
    /// Optimized for spoken word: low bitrate, mono for voice clarity.
    public static let podcastAudio = LiveEncoderConfiguration(
        audioCodec: .aac,
        bitrate: 64_000,
        sampleRate: 44_100,
        channels: 1,
        aacProfile: .lc
    )

    /// Music audio — AAC-LC, 256 kbps, 48 kHz, stereo.
    ///
    /// High-quality stereo for music streaming.
    public static let musicAudio = LiveEncoderConfiguration(
        audioCodec: .aac,
        bitrate: 256_000,
        sampleRate: 48_000,
        channels: 2,
        aacProfile: .lc
    )

    /// Low bandwidth audio — HE-AAC v2, 32 kbps, 44.1 kHz, stereo.
    ///
    /// Minimal bandwidth for constrained connections.
    public static let lowBandwidthAudio = LiveEncoderConfiguration(
        audioCodec: .aac,
        bitrate: 32_000,
        sampleRate: 44_100,
        channels: 2,
        aacProfile: .heV2
    )

    /// Hi-res passthrough — no re-encoding.
    ///
    /// Passes ALAC/FLAC data through without transformation.
    public static let hiResPassthrough = LiveEncoderConfiguration(
        audioCodec: .alac,
        bitrate: 0,
        sampleRate: 96_000,
        channels: 2,
        passthrough: true
    )
}
