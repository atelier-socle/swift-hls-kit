// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A master playlist (also known as a multivariant playlist) that
/// references one or more variant streams.
///
/// The master playlist is the entry point for HLS playback. It lists
/// all available variants, rendition groups, session data, and
/// content steering information. See RFC 8216 Section 4.3.4.
public struct MasterPlaylist: Sendable, Hashable, Codable {

    /// The HLS protocol version declared by `EXT-X-VERSION`.
    public var version: HLSVersion?

    /// The variant streams listed in the playlist.
    ///
    /// Each variant is defined by an `EXT-X-STREAM-INF` tag.
    public var variants: [Variant]

    /// I-frame variant streams.
    ///
    /// Each entry is defined by an `EXT-X-I-FRAME-STREAM-INF` tag.
    public var iFrameVariants: [IFrameVariant]

    /// Rendition groups for alternative media tracks.
    ///
    /// Each rendition is defined by an `EXT-X-MEDIA` tag.
    public var renditions: [Rendition]

    /// Session data entries.
    ///
    /// Each entry is defined by an `EXT-X-SESSION-DATA` tag.
    public var sessionData: [SessionData]

    /// Session-level encryption keys.
    ///
    /// Each key is defined by an `EXT-X-SESSION-KEY` tag.
    public var sessionKeys: [EncryptionKey]

    /// The content steering configuration, if present.
    public var contentSteering: ContentSteering?

    /// Whether segments in all variant streams are independent.
    ///
    /// Corresponds to the `EXT-X-INDEPENDENT-SEGMENTS` tag.
    public var independentSegments: Bool

    /// The preferred start offset for playback.
    ///
    /// Corresponds to the `EXT-X-START` tag.
    public var startOffset: StartOffset?

    /// Variable definitions for playlist variable substitution.
    ///
    /// Each entry is defined by an `EXT-X-DEFINE` tag.
    public var definitions: [VariableDefinition]

    /// Creates a master playlist.
    ///
    /// - Parameters:
    ///   - version: The optional HLS version.
    ///   - variants: The variant streams.
    ///   - iFrameVariants: The I-frame variant streams.
    ///   - renditions: The rendition groups.
    ///   - sessionData: The session data entries.
    ///   - sessionKeys: The session encryption keys.
    ///   - contentSteering: The optional content steering configuration.
    ///   - independentSegments: Whether segments are independent.
    ///   - startOffset: The optional preferred start offset.
    ///   - definitions: Variable definitions.
    public init(
        version: HLSVersion? = nil,
        variants: [Variant] = [],
        iFrameVariants: [IFrameVariant] = [],
        renditions: [Rendition] = [],
        sessionData: [SessionData] = [],
        sessionKeys: [EncryptionKey] = [],
        contentSteering: ContentSteering? = nil,
        independentSegments: Bool = false,
        startOffset: StartOffset? = nil,
        definitions: [VariableDefinition] = []
    ) {
        self.version = version
        self.variants = variants
        self.iFrameVariants = iFrameVariants
        self.renditions = renditions
        self.sessionData = sessionData
        self.sessionKeys = sessionKeys
        self.contentSteering = contentSteering
        self.independentSegments = independentSegments
        self.startOffset = startOffset
        self.definitions = definitions
    }
}

// MARK: - IFrameVariant

/// An I-frame variant stream from `EXT-X-I-FRAME-STREAM-INF`.
///
/// I-frame playlists contain only I-frames, allowing fast forward
/// and reverse playback. See RFC 8216 Section 4.3.4.3.
public struct IFrameVariant: Sendable, Hashable, Codable {

    /// The peak segment bitrate in bits per second.
    public var bandwidth: Int

    /// The average segment bitrate in bits per second.
    public var averageBandwidth: Int?

    /// A comma-separated list of codec identifiers.
    public var codecs: String?

    /// The optimal pixel resolution.
    public var resolution: Resolution?

    /// The HDCP level required to play the content.
    public var hdcpLevel: HDCPLevel?

    /// The video rendition group identifier.
    public var video: String?

    /// The URI of the I-frame media playlist.
    public var uri: String

    /// Creates an I-frame variant.
    ///
    /// - Parameters:
    ///   - bandwidth: The peak bitrate in bits per second.
    ///   - uri: The URI of the I-frame playlist.
    ///   - averageBandwidth: The optional average bitrate.
    ///   - codecs: An optional codec string.
    ///   - resolution: An optional resolution.
    ///   - hdcpLevel: An optional HDCP level.
    ///   - video: An optional video group identifier.
    public init(
        bandwidth: Int,
        uri: String,
        averageBandwidth: Int? = nil,
        codecs: String? = nil,
        resolution: Resolution? = nil,
        hdcpLevel: HDCPLevel? = nil,
        video: String? = nil
    ) {
        self.bandwidth = bandwidth
        self.uri = uri
        self.averageBandwidth = averageBandwidth
        self.codecs = codecs
        self.resolution = resolution
        self.hdcpLevel = hdcpLevel
        self.video = video
    }
}

// MARK: - StartOffset

/// The preferred start offset for playback from `EXT-X-START`.
///
/// See RFC 8216 Section 4.3.5.2.
public struct StartOffset: Sendable, Hashable, Codable {

    /// The time offset in seconds from the beginning of the playlist.
    /// A negative value indicates an offset from the end.
    public var timeOffset: Double

    /// If `true`, playback should start at the segment containing the
    /// offset but render from the beginning of that segment.
    public var precise: Bool

    /// Creates a start offset.
    ///
    /// - Parameters:
    ///   - timeOffset: The time offset in seconds.
    ///   - precise: Whether the offset is precise.
    public init(timeOffset: Double, precise: Bool = false) {
        self.timeOffset = timeOffset
        self.precise = precise
    }
}

// MARK: - VariableDefinition

/// A variable definition from `EXT-X-DEFINE`.
///
/// Variables allow playlist authors to reduce repetition by defining
/// named values that can be substituted into attribute values.
/// See RFC 8216 Section 4.3.5.3.
public struct VariableDefinition: Sendable, Hashable, Codable {

    /// The variable name.
    public var name: String

    /// The variable value.
    public var value: String

    /// Creates a variable definition.
    ///
    /// - Parameters:
    ///   - name: The variable name.
    ///   - value: The variable value.
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}
