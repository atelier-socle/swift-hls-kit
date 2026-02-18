// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A media playlist containing an ordered list of media segments.
///
/// Media playlists are referenced by master playlists (via variants)
/// or may be used as standalone playlists. Each segment is described
/// by an `EXTINF` tag. See RFC 8216 Section 4.3.3.
public struct MediaPlaylist: Sendable, Hashable, Codable {

    /// The HLS protocol version declared by `EXT-X-VERSION`.
    public var version: HLSVersion?

    /// The maximum segment duration in seconds, rounded to the nearest integer.
    ///
    /// Corresponds to the `EXT-X-TARGETDURATION` tag. This value MUST
    /// be greater than or equal to the `EXTINF` duration of every segment.
    public var targetDuration: Int

    /// The sequence number of the first segment in the playlist.
    ///
    /// Corresponds to the `EXT-X-MEDIA-SEQUENCE` tag.
    public var mediaSequence: Int

    /// The discontinuity sequence number.
    ///
    /// Corresponds to the `EXT-X-DISCONTINUITY-SEQUENCE` tag.
    public var discontinuitySequence: Int

    /// The playlist type (VOD, EVENT, or absent for live).
    ///
    /// Corresponds to the `EXT-X-PLAYLIST-TYPE` tag.
    public var playlistType: PlaylistType?

    /// Whether the playlist has ended (no more segments will be added).
    ///
    /// Corresponds to the `EXT-X-ENDLIST` tag.
    public var hasEndList: Bool

    /// Whether this is an I-frames-only playlist.
    ///
    /// Corresponds to the `EXT-X-I-FRAMES-ONLY` tag.
    public var iFramesOnly: Bool

    /// The ordered list of media segments.
    public var segments: [Segment]

    /// Date range metadata entries.
    ///
    /// Corresponds to `EXT-X-DATERANGE` tags in the playlist.
    public var dateRanges: [DateRange]

    /// Whether segments are independent.
    ///
    /// Corresponds to the `EXT-X-INDEPENDENT-SEGMENTS` tag.
    public var independentSegments: Bool

    /// The preferred start offset for playback.
    ///
    /// Corresponds to the `EXT-X-START` tag.
    public var startOffset: StartOffset?

    /// Variable definitions for playlist variable substitution.
    ///
    /// Corresponds to `EXT-X-DEFINE` tags.
    public var definitions: [VariableDefinition]

    // MARK: - Low-Latency HLS

    /// The partial segment target duration in seconds.
    ///
    /// Corresponds to the `EXT-X-PART-INF` tag.
    public var partTargetDuration: Double?

    /// Server control parameters for Low-Latency HLS.
    ///
    /// Corresponds to the `EXT-X-SERVER-CONTROL` tag.
    public var serverControl: ServerControl?

    /// Partial segments (Low-Latency HLS).
    ///
    /// Corresponds to `EXT-X-PART` tags.
    public var partialSegments: [PartialSegment]

    /// Preload hints (Low-Latency HLS).
    ///
    /// Corresponds to `EXT-X-PRELOAD-HINT` tags.
    public var preloadHints: [PreloadHint]

    /// Rendition reports (Low-Latency HLS).
    ///
    /// Corresponds to `EXT-X-RENDITION-REPORT` tags.
    public var renditionReports: [RenditionReport]

    /// Skip information for playlist delta updates (Low-Latency HLS).
    ///
    /// Corresponds to the `EXT-X-SKIP` tag.
    public var skip: SkipInfo?

    /// Creates a media playlist.
    ///
    /// - Parameters:
    ///   - version: The optional HLS version.
    ///   - targetDuration: The maximum segment duration.
    ///   - mediaSequence: The first segment sequence number.
    ///   - discontinuitySequence: The discontinuity sequence number.
    ///   - playlistType: The optional playlist type.
    ///   - hasEndList: Whether the playlist has ended.
    ///   - iFramesOnly: Whether this is an I-frames-only playlist.
    ///   - segments: The media segments.
    ///   - dateRanges: Date range entries.
    ///   - independentSegments: Whether segments are independent.
    ///   - startOffset: The optional start offset.
    ///   - definitions: Variable definitions.
    ///   - partTargetDuration: Optional partial segment target duration.
    ///   - serverControl: Optional server control parameters.
    ///   - partialSegments: Partial segments for LL-HLS.
    ///   - preloadHints: Preload hints for LL-HLS.
    ///   - renditionReports: Rendition reports for LL-HLS.
    ///   - skip: Optional skip information.
    public init(
        version: HLSVersion? = nil,
        targetDuration: Int = 10,
        mediaSequence: Int = 0,
        discontinuitySequence: Int = 0,
        playlistType: PlaylistType? = nil,
        hasEndList: Bool = false,
        iFramesOnly: Bool = false,
        segments: [Segment] = [],
        dateRanges: [DateRange] = [],
        independentSegments: Bool = false,
        startOffset: StartOffset? = nil,
        definitions: [VariableDefinition] = [],
        partTargetDuration: Double? = nil,
        serverControl: ServerControl? = nil,
        partialSegments: [PartialSegment] = [],
        preloadHints: [PreloadHint] = [],
        renditionReports: [RenditionReport] = [],
        skip: SkipInfo? = nil
    ) {
        self.version = version
        self.targetDuration = targetDuration
        self.mediaSequence = mediaSequence
        self.discontinuitySequence = discontinuitySequence
        self.playlistType = playlistType
        self.hasEndList = hasEndList
        self.iFramesOnly = iFramesOnly
        self.segments = segments
        self.dateRanges = dateRanges
        self.independentSegments = independentSegments
        self.startOffset = startOffset
        self.definitions = definitions
        self.partTargetDuration = partTargetDuration
        self.serverControl = serverControl
        self.partialSegments = partialSegments
        self.preloadHints = preloadHints
        self.renditionReports = renditionReports
        self.skip = skip
    }
}

// MARK: - ServerControl

/// Server control parameters for Low-Latency HLS.
///
/// Corresponds to the `EXT-X-SERVER-CONTROL` tag.
public struct ServerControl: Sendable, Hashable, Codable {

    /// Whether the server supports blocking playlist reloads.
    public var canBlockReload: Bool

    /// Whether the server supports playlist delta updates.
    public var canSkipUntil: Double?

    /// Whether the server supports skipping date ranges.
    public var canSkipDateRanges: Bool

    /// The hold-back distance in seconds for live playback.
    public var holdBack: Double?

    /// The part hold-back distance in seconds for Low-Latency HLS.
    public var partHoldBack: Double?

    /// Creates server control parameters.
    ///
    /// - Parameters:
    ///   - canBlockReload: Whether blocking reloads are supported.
    ///   - canSkipUntil: The skip distance in seconds.
    ///   - canSkipDateRanges: Whether date range skipping is supported.
    ///   - holdBack: The hold-back distance in seconds.
    ///   - partHoldBack: The part hold-back distance in seconds.
    public init(
        canBlockReload: Bool = false,
        canSkipUntil: Double? = nil,
        canSkipDateRanges: Bool = false,
        holdBack: Double? = nil,
        partHoldBack: Double? = nil
    ) {
        self.canBlockReload = canBlockReload
        self.canSkipUntil = canSkipUntil
        self.canSkipDateRanges = canSkipDateRanges
        self.holdBack = holdBack
        self.partHoldBack = partHoldBack
    }
}

// MARK: - PartialSegment

/// A partial segment for Low-Latency HLS.
///
/// Corresponds to the `EXT-X-PART` tag.
public struct PartialSegment: Sendable, Hashable, Codable {

    /// The URI of the partial segment.
    public var uri: String

    /// The duration of the partial segment in seconds.
    public var duration: Double

    /// Whether this partial segment is independent (starts with an I-frame).
    public var independent: Bool

    /// An optional byte range within the resource.
    public var byteRange: ByteRange?

    /// Whether this is a gap in the partial segment sequence.
    public var isGap: Bool

    /// Creates a partial segment.
    ///
    /// - Parameters:
    ///   - uri: The URI.
    ///   - duration: The duration in seconds.
    ///   - independent: Whether the segment starts with an I-frame.
    ///   - byteRange: An optional byte range.
    ///   - isGap: Whether this is a gap.
    public init(
        uri: String,
        duration: Double,
        independent: Bool = false,
        byteRange: ByteRange? = nil,
        isGap: Bool = false
    ) {
        self.uri = uri
        self.duration = duration
        self.independent = independent
        self.byteRange = byteRange
        self.isGap = isGap
    }
}

// MARK: - PreloadHint

/// A preload hint for Low-Latency HLS.
///
/// Corresponds to the `EXT-X-PRELOAD-HINT` tag.
public struct PreloadHint: Sendable, Hashable, Codable {

    /// The type of resource to preload.
    public var type: PreloadHintType

    /// The URI of the resource to preload.
    public var uri: String

    /// An optional byte range start offset.
    public var byteRangeStart: Int?

    /// An optional byte range length.
    public var byteRangeLength: Int?

    /// Creates a preload hint.
    ///
    /// - Parameters:
    ///   - type: The resource type.
    ///   - uri: The resource URI.
    ///   - byteRangeStart: An optional start offset.
    ///   - byteRangeLength: An optional length.
    public init(
        type: PreloadHintType,
        uri: String,
        byteRangeStart: Int? = nil,
        byteRangeLength: Int? = nil
    ) {
        self.type = type
        self.uri = uri
        self.byteRangeStart = byteRangeStart
        self.byteRangeLength = byteRangeLength
    }
}

/// The type of resource referenced by a preload hint.
public enum PreloadHintType: String, Sendable, Hashable, Codable, CaseIterable {

    /// A partial segment.
    case part = "PART"

    /// A media initialization section.
    case map = "MAP"
}

// MARK: - RenditionReport

/// A rendition report for Low-Latency HLS.
///
/// Corresponds to the `EXT-X-RENDITION-REPORT` tag.
public struct RenditionReport: Sendable, Hashable, Codable {

    /// The URI of the rendition playlist.
    public var uri: String

    /// The last media sequence number available.
    public var lastMediaSequence: Int?

    /// The last partial segment index available.
    public var lastPartIndex: Int?

    /// Creates a rendition report.
    ///
    /// - Parameters:
    ///   - uri: The rendition playlist URI.
    ///   - lastMediaSequence: The last media sequence.
    ///   - lastPartIndex: The last partial segment index.
    public init(
        uri: String,
        lastMediaSequence: Int? = nil,
        lastPartIndex: Int? = nil
    ) {
        self.uri = uri
        self.lastMediaSequence = lastMediaSequence
        self.lastPartIndex = lastPartIndex
    }
}

// MARK: - SkipInfo

/// Skip information for playlist delta updates.
///
/// Corresponds to the `EXT-X-SKIP` tag.
public struct SkipInfo: Sendable, Hashable, Codable {

    /// The number of segments that were skipped.
    public var skippedSegments: Int

    /// Recently removed date ranges, if any.
    public var recentlyRemovedDateRanges: [String]

    /// Creates skip information.
    ///
    /// - Parameters:
    ///   - skippedSegments: The number of skipped segments.
    ///   - recentlyRemovedDateRanges: Recently removed date range IDs.
    public init(
        skippedSegments: Int,
        recentlyRemovedDateRanges: [String] = []
    ) {
        self.skippedSegments = skippedSegments
        self.recentlyRemovedDateRanges = recentlyRemovedDateRanges
    }
}
