// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A variant stream in a master playlist.
///
/// Each variant is described by an `EXT-X-STREAM-INF` tag followed by
/// a URI line pointing to the media playlist. See RFC 8216 Section 4.3.4.2.
public struct Variant: Sendable, Hashable, Codable {

    /// The peak segment bitrate in bits per second.
    public var bandwidth: Int

    /// The average segment bitrate in bits per second.
    public var averageBandwidth: Int?

    /// A comma-separated list of codec identifiers (RFC 6381).
    public var codecs: String?

    /// The optimal pixel resolution for displaying the video.
    public var resolution: Resolution?

    /// The maximum frame rate in frames per second.
    public var frameRate: Double?

    /// The HDCP level required to play the content.
    public var hdcpLevel: HDCPLevel?

    /// The audio rendition group identifier.
    public var audio: String?

    /// The video rendition group identifier.
    public var video: String?

    /// The subtitles rendition group identifier.
    public var subtitles: String?

    /// The closed-captions rendition group identifier, or `nil` for `NONE`.
    public var closedCaptions: ClosedCaptionsValue?

    /// The URI of the media playlist for this variant.
    public var uri: String

    /// Creates a variant stream.
    ///
    /// - Parameters:
    ///   - bandwidth: The peak bitrate in bits per second.
    ///   - resolution: The optional video resolution.
    ///   - uri: The URI of the media playlist.
    ///   - averageBandwidth: The optional average bitrate.
    ///   - codecs: An optional codec string.
    ///   - frameRate: An optional maximum frame rate.
    ///   - hdcpLevel: An optional HDCP level.
    ///   - audio: An optional audio group identifier.
    ///   - video: An optional video group identifier.
    ///   - subtitles: An optional subtitles group identifier.
    ///   - closedCaptions: An optional closed-captions value.
    public init(
        bandwidth: Int,
        resolution: Resolution? = nil,
        uri: String,
        averageBandwidth: Int? = nil,
        codecs: String? = nil,
        frameRate: Double? = nil,
        hdcpLevel: HDCPLevel? = nil,
        audio: String? = nil,
        video: String? = nil,
        subtitles: String? = nil,
        closedCaptions: ClosedCaptionsValue? = nil
    ) {
        self.bandwidth = bandwidth
        self.resolution = resolution
        self.uri = uri
        self.averageBandwidth = averageBandwidth
        self.codecs = codecs
        self.frameRate = frameRate
        self.hdcpLevel = hdcpLevel
        self.audio = audio
        self.video = video
        self.subtitles = subtitles
        self.closedCaptions = closedCaptions
    }
}

// MARK: - HDCPLevel

/// The HDCP level required to play the content.
///
/// Per RFC 8216 Section 4.3.4.2, the `HDCP-LEVEL` attribute indicates
/// the minimum HDCP level required.
public enum HDCPLevel: String, Sendable, Hashable, Codable, CaseIterable {

    /// Type 0 content protection.
    case type0 = "TYPE-0"

    /// Type 1 content protection.
    case type1 = "TYPE-1"

    /// No HDCP required.
    case none = "NONE"
}

// MARK: - ClosedCaptionsValue

/// The value of the `CLOSED-CAPTIONS` attribute in `EXT-X-STREAM-INF`.
///
/// This can be either a group identifier string or the special value `NONE`
/// indicating that no closed captions are available.
public enum ClosedCaptionsValue: Sendable, Hashable, Codable {

    /// A reference to a closed-captions rendition group.
    case groupId(String)

    /// No closed captions available for this variant.
    case none
}
