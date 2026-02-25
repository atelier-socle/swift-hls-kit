// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Represents an `EXT-X-I-FRAME-STREAM-INF` entry in a master playlist.
///
/// Used to advertise I-Frame playlists for each variant in the master playlist.
///
/// ```
/// #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=86000,URI="iframe-low.m3u8",
///   CODECS="avc1.640028",RESOLUTION=640x360
/// ```
public struct IFrameStreamInfo: Sendable, Equatable {

    /// Average bandwidth in bits/sec.
    public var bandwidth: Int

    /// Optional average bandwidth.
    public var averageBandwidth: Int?

    /// Codec string (e.g., "avc1.640028").
    public var codecs: String?

    /// Resolution.
    public var resolution: Resolution?

    /// HDCP level.
    public var hdcpLevel: String?

    /// Video range (SDR, PQ, HLG).
    public var videoRange: String?

    /// URI of the I-Frame playlist.
    public var uri: String

    /// Video resolution.
    public struct Resolution: Sendable, Equatable {

        /// Width in pixels.
        public var width: Int

        /// Height in pixels.
        public var height: Int

        /// Creates a resolution.
        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }

    /// Creates an I-Frame stream info entry.
    ///
    /// - Parameters:
    ///   - bandwidth: Average bandwidth in bits/sec.
    ///   - uri: URI of the I-Frame playlist.
    ///   - averageBandwidth: Optional average bandwidth.
    ///   - codecs: Codec string.
    ///   - resolution: Video resolution.
    ///   - hdcpLevel: HDCP level.
    ///   - videoRange: Video range (SDR, PQ, HLG).
    public init(
        bandwidth: Int,
        uri: String,
        averageBandwidth: Int? = nil,
        codecs: String? = nil,
        resolution: Resolution? = nil,
        hdcpLevel: String? = nil,
        videoRange: String? = nil
    ) {
        self.bandwidth = bandwidth
        self.uri = uri
        self.averageBandwidth = averageBandwidth
        self.codecs = codecs
        self.resolution = resolution
        self.hdcpLevel = hdcpLevel
        self.videoRange = videoRange
    }

    /// Render as `EXT-X-I-FRAME-STREAM-INF` tag.
    ///
    /// - Returns: The complete tag line.
    public func render() -> String {
        var attrs = [String]()
        attrs.append("BANDWIDTH=\(bandwidth)")
        if let avg = averageBandwidth {
            attrs.append("AVERAGE-BANDWIDTH=\(avg)")
        }
        if let codecs {
            attrs.append("CODECS=\"\(codecs)\"")
        }
        if let res = resolution {
            attrs.append("RESOLUTION=\(res.width)x\(res.height)")
        }
        if let hdcp = hdcpLevel {
            attrs.append("HDCP-LEVEL=\(hdcp)")
        }
        if let vr = videoRange {
            attrs.append("VIDEO-RANGE=\(vr)")
        }
        attrs.append("URI=\"\(uri)\"")
        return "#EXT-X-I-FRAME-STREAM-INF:\(attrs.joined(separator: ","))"
    }
}
