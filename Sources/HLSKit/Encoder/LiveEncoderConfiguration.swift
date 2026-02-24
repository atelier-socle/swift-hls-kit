// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for a ``LiveEncoder``.
///
/// Describes the desired output format: codec, bitrate, sample rate,
/// channels, and AAC profile. Use the built-in presets for common
/// podcast and music encoding scenarios.
///
/// ## Audio Presets
/// ```swift
/// let config = LiveEncoderConfiguration.podcastAudio
/// let config = LiveEncoderConfiguration.musicAudio
/// ```
///
/// ## Video Configuration
/// ```swift
/// let config = LiveEncoderConfiguration(
///     videoCodec: .h264,
///     videoBitrate: 2_800_000,
///     keyframeInterval: 6.0,
///     qualityPreset: .p720
/// )
/// ```
public struct LiveEncoderConfiguration: Sendable, Equatable, Hashable {

    /// Target audio codec for encoding.
    public let audioCodec: AudioCodec

    /// Video codec for video encoding. Nil for audio-only.
    public let videoCodec: VideoCodec?

    /// Target audio bitrate in bits per second.
    public let bitrate: Int

    /// Output sample rate in Hz.
    public let sampleRate: Double

    /// Number of output channels.
    public let channels: Int

    /// AAC profile to use. Nil for non-AAC codecs.
    public let aacProfile: AACProfile?

    /// Whether to pass through audio without re-encoding.
    public let passthrough: Bool

    /// Target video bitrate in bits per second. Nil uses preset default.
    public let videoBitrate: Int?

    /// Keyframe interval in seconds. Nil uses preset default.
    public let keyframeInterval: Double?

    /// Quality preset for resolution, profile, and bitrate defaults.
    public let qualityPreset: QualityPreset?

    /// Creates a live encoder configuration.
    ///
    /// - Parameters:
    ///   - audioCodec: Target audio codec. Default is AAC.
    ///   - videoCodec: Target video codec. Nil for audio-only.
    ///   - bitrate: Target audio bitrate in bits per second.
    ///   - sampleRate: Output sample rate in Hz.
    ///   - channels: Number of output channels.
    ///   - aacProfile: AAC profile. Nil for non-AAC codecs.
    ///   - passthrough: Whether to pass through without re-encoding.
    ///   - videoBitrate: Target video bitrate. Nil uses preset default.
    ///   - keyframeInterval: Keyframe interval in seconds.
    ///   - qualityPreset: Quality preset for video settings.
    public init(
        audioCodec: AudioCodec = .aac,
        videoCodec: VideoCodec? = nil,
        bitrate: Int = 0,
        sampleRate: Double = 44_100,
        channels: Int = 2,
        aacProfile: AACProfile? = nil,
        passthrough: Bool = false,
        videoBitrate: Int? = nil,
        keyframeInterval: Double? = nil,
        qualityPreset: QualityPreset? = nil
    ) {
        self.audioCodec = audioCodec
        self.videoCodec = videoCodec
        self.bitrate = bitrate
        self.sampleRate = sampleRate
        self.channels = channels
        self.aacProfile = aacProfile
        self.passthrough = passthrough
        self.videoBitrate = videoBitrate
        self.keyframeInterval = keyframeInterval
        self.qualityPreset = qualityPreset
    }
}

// MARK: - Video Overrides

extension LiveEncoderConfiguration {

    /// Creates a copy with video settings overridden per-preset.
    ///
    /// Used by ``MultiBitrateEncoder`` to create per-preset configs
    /// from a shared base configuration.
    ///
    /// - Parameters:
    ///   - videoBitrate: Override video bitrate.
    ///   - qualityPreset: Override quality preset.
    /// - Returns: A new configuration with the overridden values.
    func withVideoOverrides(
        videoBitrate: Int?,
        qualityPreset: QualityPreset
    ) -> LiveEncoderConfiguration {
        LiveEncoderConfiguration(
            audioCodec: audioCodec,
            videoCodec: videoCodec,
            bitrate: bitrate,
            sampleRate: sampleRate,
            channels: channels,
            aacProfile: aacProfile,
            passthrough: passthrough,
            videoBitrate: videoBitrate,
            keyframeInterval: keyframeInterval,
            qualityPreset: qualityPreset
        )
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
