// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for MP4 segmentation.
///
/// Controls how MP4 files are split into HLS-compatible segments,
/// including target duration, output format, naming, container
/// format, and playlist generation options.
///
/// ```swift
/// var config = SegmentationConfig()
/// config.containerFormat = .mpegTS
/// config.targetSegmentDuration = 10.0
/// let result = try segmenter.segment(data: mp4Data, config: config)
/// ```
public struct SegmentationConfig: Sendable, Hashable {

    /// Target segment duration in seconds.
    /// Actual segment duration depends on keyframe positions.
    /// Default: 6.0 (Apple recommended)
    public var targetSegmentDuration: Double

    /// Output container format for segments.
    /// Default: `.fragmentedMP4`
    public var containerFormat: ContainerFormat

    /// Output format for segments.
    /// Default: `.separateFiles`
    public var outputMode: OutputMode

    /// Naming pattern for segment files.
    /// Use `%d` for segment number (0-based).
    /// Default depends on `containerFormat`:
    /// - `.fragmentedMP4`: `"segment_%d.m4s"`
    /// - `.mpegTS`: `"segment_%d.ts"`
    public var segmentNamePattern: String

    /// Name for the initialization segment file.
    /// Default: `"init.mp4"` (unused for MPEG-TS)
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
    /// Default depends on `containerFormat`:
    /// - `.fragmentedMP4`: 7
    /// - `.mpegTS`: 3
    public var hlsVersion: Int

    /// Creates a segmentation configuration with default values.
    ///
    /// - Parameters:
    ///   - targetSegmentDuration: Target segment duration in seconds.
    ///   - containerFormat: Output container format.
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
        containerFormat: ContainerFormat = .fragmentedMP4,
        outputMode: OutputMode = .separateFiles,
        segmentNamePattern: String? = nil,
        initSegmentName: String = "init.mp4",
        playlistName: String = "playlist.m3u8",
        includeAudio: Bool = true,
        generatePlaylist: Bool = true,
        playlistType: PlaylistType = .vod,
        hlsVersion: Int? = nil
    ) {
        self.targetSegmentDuration = targetSegmentDuration
        self.containerFormat = containerFormat
        self.outputMode = outputMode
        self.segmentNamePattern =
            segmentNamePattern
            ?? containerFormat.defaultSegmentPattern
        self.initSegmentName = initSegmentName
        self.playlistName = playlistName
        self.includeAudio = includeAudio
        self.generatePlaylist = generatePlaylist
        self.playlistType = playlistType
        self.hlsVersion =
            hlsVersion
            ?? containerFormat.defaultHLSVersion
    }

    /// Output container format for segments.
    public enum ContainerFormat: String, Sendable, Hashable, Codable {
        /// Fragmented MP4 (init.mp4 + segment_N.m4s).
        case fragmentedMP4

        /// MPEG Transport Stream (segment_N.ts).
        case mpegTS

        /// Default segment name pattern for this format.
        public var defaultSegmentPattern: String {
            switch self {
            case .fragmentedMP4: return "segment_%d.m4s"
            case .mpegTS: return "segment_%d.ts"
            }
        }

        /// Default HLS version for this format.
        public var defaultHLSVersion: Int {
            switch self {
            case .fragmentedMP4: return 7
            case .mpegTS: return 3
            }
        }
    }

    /// Output mode for segmented content.
    public enum OutputMode: String, Sendable, Hashable, Codable {
        /// Each segment is a separate file.
        case separateFiles

        /// All segments in a single file, referenced by byte ranges.
        case byteRange
    }
}
