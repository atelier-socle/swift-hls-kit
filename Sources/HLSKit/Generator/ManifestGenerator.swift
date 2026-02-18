// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates HLS M3U8 manifest strings from typed Swift models.
///
/// The generator produces spec-compliant M3U8 text from
/// ``MasterPlaylist`` or ``MediaPlaylist`` instances.
///
/// ```swift
/// let generator = ManifestGenerator()
/// let m3u8 = generator.generate(.master(playlist))
/// ```
///
/// See RFC 8216 for the full M3U8 specification.
public struct ManifestGenerator: Sendable {

    /// The tag writer used for individual tag serialization.
    private let tagWriter: TagWriter

    /// Creates a manifest generator.
    ///
    /// - Parameter tagWriter: The tag writer to use.
    public init(tagWriter: TagWriter = TagWriter()) {
        self.tagWriter = tagWriter
    }

    /// Generates an M3U8 string from a manifest.
    ///
    /// - Parameter manifest: The manifest to serialize.
    /// - Returns: The M3U8 text string.
    public func generate(_ manifest: Manifest) -> String {
        switch manifest {
        case .master(let playlist):
            return generateMaster(playlist)
        case .media(let playlist):
            return generateMedia(playlist)
        }
    }

    /// Generates an M3U8 string from a master playlist.
    ///
    /// - Parameter playlist: The master playlist.
    /// - Returns: The M3U8 text string.
    public func generateMaster(_ playlist: MasterPlaylist) -> String {
        var lines: [String] = ["#EXTM3U"]

        if let version = playlist.version {
            lines.append("#EXT-X-VERSION:\(version.rawValue)")
        }

        if playlist.independentSegments {
            lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
        }

        // Stub — full tag serialization in a later session.

        for variant in playlist.variants {
            var attributes = "BANDWIDTH=\(variant.bandwidth)"
            if let resolution = variant.resolution {
                attributes += ",RESOLUTION=\(resolution)"
            }
            if let codecs = variant.codecs {
                attributes += ",CODECS=\"\(codecs)\""
            }
            lines.append("#EXT-X-STREAM-INF:\(attributes)")
            lines.append(variant.uri)
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Generates an M3U8 string from a media playlist.
    ///
    /// - Parameter playlist: The media playlist.
    /// - Returns: The M3U8 text string.
    public func generateMedia(_ playlist: MediaPlaylist) -> String {
        var lines: [String] = ["#EXTM3U"]

        if let version = playlist.version {
            lines.append("#EXT-X-VERSION:\(version.rawValue)")
        }

        lines.append("#EXT-X-TARGETDURATION:\(playlist.targetDuration)")

        if playlist.mediaSequence != 0 {
            lines.append("#EXT-X-MEDIA-SEQUENCE:\(playlist.mediaSequence)")
        }

        if let playlistType = playlist.playlistType {
            lines.append("#EXT-X-PLAYLIST-TYPE:\(playlistType.rawValue)")
        }

        if playlist.independentSegments {
            lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
        }

        // Stub — full tag serialization in a later session.

        for segment in playlist.segments {
            lines.append(tagWriter.writeExtInf(duration: segment.duration, title: segment.title))
            lines.append(segment.uri)
        }

        if playlist.hasEndList {
            lines.append("#EXT-X-ENDLIST")
        }

        lines.append("")
        return lines.joined(separator: "\n")
    }
}
