// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Every HLS tag defined in RFC 8216 and its extensions.
///
/// Tags are grouped by their role in the specification:
/// basic tags, media segment tags, media playlist tags, and
/// master playlist tags.
public enum HLSTag: String, Sendable, Hashable, Codable, CaseIterable {

    // MARK: - Basic Tags

    /// Playlist header. MUST be the first line of a playlist.
    case extm3u = "EXTM3U"

    /// Protocol compatibility version.
    case extXVersion = "EXT-X-VERSION"

    // MARK: - Media Segment Tags

    /// Segment duration and optional title.
    case extinf = "EXTINF"

    /// Sub-range of a resource.
    case extXByterange = "EXT-X-BYTERANGE"

    /// Encoding discontinuity between segments.
    case extXDiscontinuity = "EXT-X-DISCONTINUITY"

    /// Encryption parameters for subsequent segments.
    case extXKey = "EXT-X-KEY"

    /// Media initialization section (fMP4 init segment or WebVTT header).
    case extXMap = "EXT-X-MAP"

    /// Absolute date and time of the first sample of the next segment.
    case extXProgramDateTime = "EXT-X-PROGRAM-DATE-TIME"

    /// Indicates a gap in the media presentation.
    case extXGap = "EXT-X-GAP"

    /// Approximate segment bitrate in kilobits per second.
    case extXBitrate = "EXT-X-BITRATE"

    /// Timed metadata associated with a date range.
    case extXDaterange = "EXT-X-DATERANGE"

    // MARK: - Media Playlist Tags

    /// Maximum segment duration rounded to the nearest integer.
    case extXTargetduration = "EXT-X-TARGETDURATION"

    /// Sequence number of the first segment in the playlist.
    case extXMediaSequence = "EXT-X-MEDIA-SEQUENCE"

    /// Discontinuity sequence number.
    case extXDiscontinuitySequence = "EXT-X-DISCONTINUITY-SEQUENCE"

    /// Indicates that no more segments will be added.
    case extXEndlist = "EXT-X-ENDLIST"

    /// Playlist mutability: VOD or EVENT.
    case extXPlaylistType = "EXT-X-PLAYLIST-TYPE"

    /// Indicates the playlist contains only I-frames.
    case extXIFramesOnly = "EXT-X-I-FRAMES-ONLY"

    /// Partial segment (Low-Latency HLS).
    case extXPart = "EXT-X-PART"

    /// Partial segment information (Low-Latency HLS).
    case extXPartInf = "EXT-X-PART-INF"

    /// Server control hints for Low-Latency HLS.
    case extXServerControl = "EXT-X-SERVER-CONTROL"

    /// Preload hint for Low-Latency HLS.
    case extXPreloadHint = "EXT-X-PRELOAD-HINT"

    /// Rendition report for Low-Latency HLS.
    case extXRenditionReport = "EXT-X-RENDITION-REPORT"

    /// Playlist delta updates for Low-Latency HLS.
    case extXSkip = "EXT-X-SKIP"

    // MARK: - Master Playlist Tags

    /// Rendition group (audio, video, subtitles, closed-captions).
    case extXMedia = "EXT-X-MEDIA"

    /// Variant stream definition.
    case extXStreamInf = "EXT-X-STREAM-INF"

    /// I-frame variant stream.
    case extXIFrameStreamInf = "EXT-X-I-FRAME-STREAM-INF"

    /// Arbitrary session data.
    case extXSessionData = "EXT-X-SESSION-DATA"

    /// Session-level encryption key.
    case extXSessionKey = "EXT-X-SESSION-KEY"

    /// Content steering server URI.
    case extXContentSteering = "EXT-X-CONTENT-STEERING"

    // MARK: - Universal Tags

    /// Declares that all media samples in a segment can be decoded
    /// without information from other segments.
    case extXIndependentSegments = "EXT-X-INDEPENDENT-SEGMENTS"

    /// Preferred start point for playback.
    case extXStart = "EXT-X-START"

    /// Variable definition for playlist variable substitution.
    case extXDefine = "EXT-X-DEFINE"
}
