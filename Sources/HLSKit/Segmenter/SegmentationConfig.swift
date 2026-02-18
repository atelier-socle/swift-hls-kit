// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for MP4 segmentation.
///
/// Controls how MP4 files are split into HLS-compatible fMP4
/// segments, including target duration, output format, naming,
/// and playlist generation options.
///
/// ```swift
/// var config = SegmentationConfig()
/// config.targetSegmentDuration = 10.0
/// config.outputMode = .byteRange
/// let result = try segmenter.segment(data: mp4Data, config: config)
/// ```
public struct SegmentationConfig: Sendable, Hashable {

    /// Target segment duration in seconds.
    /// Actual segment duration depends on keyframe positions.
    /// Default: 6.0 (Apple recommended)
    public var targetSegmentDuration: Double

    /// Output format for segments.
    /// Default: `.separateFiles`
    public var outputMode: OutputMode

    /// Naming pattern for segment files.
    /// Use `%d` for segment number (0-based).
    /// Default: `"segment_%d.m4s"`
    public var segmentNamePattern: String

    /// Name for the initialization segment file.
    /// Default: `"init.mp4"`
    public var initSegmentName: String

    /// Name for the generated media playlist.
    /// Default: `"playlist.m3u8"`
    public var playlistName: String

    /// Whether to include audio track in segments (if present).
    /// When true, generates muxed segments with video + audio.
    /// When false, generates video-only segments.
    /// Default: `true`
    public var includeAudio: Bool

    /// Whether to generate the HLS playlist automatically.
    /// Default: `true`
    public var generatePlaylist: Bool

    /// HLS playlist type.
    /// Default: `.vod`
    public var playlistType: PlaylistType

    /// HLS version to use in the playlist.
    /// Default: 7 (required for fMP4)
    public var hlsVersion: Int

    /// Creates a segmentation configuration with default values.
    ///
    /// - Parameters:
    ///   - targetSegmentDuration: Target segment duration in seconds.
    ///   - outputMode: Output format for segments.
    ///   - segmentNamePattern: Naming pattern for segment files.
    ///   - initSegmentName: Name for the init segment.
    ///   - playlistName: Name for the playlist file.
    ///   - includeAudio: Whether to include audio.
    ///   - generatePlaylist: Whether to generate a playlist.
    ///   - playlistType: HLS playlist type.
    ///   - hlsVersion: HLS version for the playlist.
    public init(
        targetSegmentDuration: Double = 6.0,
        outputMode: OutputMode = .separateFiles,
        segmentNamePattern: String = "segment_%d.m4s",
        initSegmentName: String = "init.mp4",
        playlistName: String = "playlist.m3u8",
        includeAudio: Bool = true,
        generatePlaylist: Bool = true,
        playlistType: PlaylistType = .vod,
        hlsVersion: Int = 7
    ) {
        self.targetSegmentDuration = targetSegmentDuration
        self.outputMode = outputMode
        self.segmentNamePattern = segmentNamePattern
        self.initSegmentName = initSegmentName
        self.playlistName = playlistName
        self.includeAudio = includeAudio
        self.generatePlaylist = generatePlaylist
        self.playlistType = playlistType
        self.hlsVersion = hlsVersion
    }

    /// Output mode for segmented content.
    public enum OutputMode: String, Sendable, Hashable, Codable {
        /// Each segment is a separate `.m4s` file.
        case separateFiles

        /// All segments in a single file, referenced by byte ranges.
        case byteRange
    }
}
