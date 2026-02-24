// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for the transcoding process.
///
/// Controls video/audio codec selection, container format,
/// segment duration, hardware acceleration, and other encoding
/// parameters.
///
/// ```swift
/// var config = TranscodingConfig()
/// config.videoCodec = .h265
/// config.hardwareAcceleration = true
/// config.segmentDuration = 4.0
/// ```
///
/// - SeeAlso: ``Transcoder``, ``QualityPreset``
public struct TranscodingConfig: Sendable, Hashable {

    /// Video codec to use for encoding.
    /// Default: `.h264`
    public var videoCodec: OutputVideoCodec

    /// Audio codec to use for encoding.
    /// Default: `.aac`
    public var audioCodec: OutputAudioCodec

    /// Container format for segmented output.
    /// Default: `.fragmentedMP4`
    public var containerFormat: SegmentationConfig.ContainerFormat

    /// Target segment duration in seconds.
    /// Default: 6.0
    public var segmentDuration: Double

    /// Whether to generate HLS playlists automatically.
    /// Default: `true`
    public var generatePlaylist: Bool

    /// Playlist type.
    /// Default: `.vod`
    public var playlistType: PlaylistType

    /// Whether to include audio in the output.
    /// Default: `true`
    public var includeAudio: Bool

    /// Whether to pass through audio without re-encoding.
    /// When true, audio is copied from source (faster, no quality loss).
    /// Default: `true`
    public var audioPassthrough: Bool

    /// Whether to enable hardware acceleration.
    /// Default: `true`
    public var hardwareAcceleration: Bool

    /// Two-pass encoding for better quality at target bitrate.
    /// Default: `false` (single-pass)
    public var twoPass: Bool

    /// Custom metadata to include in output files.
    public var metadata: [String: String]

    /// Creates a transcoding configuration with default values.
    ///
    /// - Parameters:
    ///   - videoCodec: Video codec to use.
    ///   - audioCodec: Audio codec to use.
    ///   - containerFormat: Output container format.
    ///   - segmentDuration: Target segment duration.
    ///   - generatePlaylist: Whether to generate playlists.
    ///   - playlistType: HLS playlist type.
    ///   - includeAudio: Whether to include audio.
    ///   - audioPassthrough: Whether to pass through audio.
    ///   - hardwareAcceleration: Whether to use HW acceleration.
    ///   - twoPass: Whether to use two-pass encoding.
    ///   - metadata: Custom metadata key-value pairs.
    public init(
        videoCodec: OutputVideoCodec = .h264,
        audioCodec: OutputAudioCodec = .aac,
        containerFormat: SegmentationConfig.ContainerFormat = .fragmentedMP4,
        segmentDuration: Double = 6.0,
        generatePlaylist: Bool = true,
        playlistType: PlaylistType = .vod,
        includeAudio: Bool = true,
        audioPassthrough: Bool = true,
        hardwareAcceleration: Bool = true,
        twoPass: Bool = false,
        metadata: [String: String] = [:]
    ) {
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.containerFormat = containerFormat
        self.segmentDuration = segmentDuration
        self.generatePlaylist = generatePlaylist
        self.playlistType = playlistType
        self.includeAudio = includeAudio
        self.audioPassthrough = audioPassthrough
        self.hardwareAcceleration = hardwareAcceleration
        self.twoPass = twoPass
        self.metadata = metadata
    }
}

// MARK: - OutputVideoCodec

/// Video codec for encoding output.
///
/// Defines the video compression standard to use during
/// transcoding. Compatibility varies by platform and device.
public enum OutputVideoCodec: String, Sendable, Hashable, Codable,
    CaseIterable
{
    /// H.264 / AVC — widest compatibility.
    case h264

    /// H.265 / HEVC — better compression, newer devices.
    case h265

    /// VP9 — Google codec (not standard for HLS).
    case vp9

    /// AV1 — next-gen open codec.
    case av1
}

// MARK: - OutputAudioCodec

/// Audio codec for encoding output.
///
/// Defines the audio compression standard to use during
/// transcoding. AAC is the standard for HLS.
public enum OutputAudioCodec: String, Sendable, Hashable, Codable,
    CaseIterable
{
    /// AAC-LC — standard for HLS.
    case aac

    /// HE-AAC v1 — better at low bitrates.
    case heAAC

    /// HE-AAC v2 — best at very low bitrates.
    case heAACv2

    /// FLAC — lossless (Apple supports in HLS).
    case flac

    /// Opus — modern, efficient (limited HLS support).
    case opus
}
