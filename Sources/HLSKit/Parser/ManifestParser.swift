// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// The result of parsing an HLS manifest.
///
/// An HLS manifest is either a master playlist (listing variant streams)
/// or a media playlist (listing media segments). The parser determines
/// which type based on the tags present.
public enum Manifest: Sendable, Hashable {

    /// A master playlist containing variant stream references.
    case master(MasterPlaylist)

    /// A media playlist containing media segments.
    case media(MediaPlaylist)
}

/// Parses HLS M3U8 manifest strings into typed Swift models.
///
/// The parser reads an M3U8 text string and produces either a
/// ``MasterPlaylist`` or ``MediaPlaylist`` depending on the tags present.
///
/// ```swift
/// let parser = ManifestParser()
/// let manifest = try parser.parse(m3u8String)
/// switch manifest {
/// case .master(let playlist):
///     print("Found \(playlist.variants.count) variants")
/// case .media(let playlist):
///     print("Found \(playlist.segments.count) segments")
/// }
/// ```
///
/// See RFC 8216 for the full M3U8 specification.
public struct ManifestParser: Sendable {

    /// The tag parser used for individual tag processing.
    private let tagParser: TagParser

    /// Creates a manifest parser.
    ///
    /// - Parameter tagParser: The tag parser to use.
    public init(tagParser: TagParser = TagParser()) {
        self.tagParser = tagParser
    }

    /// Parses an M3U8 manifest string.
    ///
    /// The parser determines whether the manifest is a master or media
    /// playlist based on the presence of `EXT-X-STREAM-INF` tags
    /// (master) or `EXTINF` tags (media).
    ///
    /// - Parameter string: The M3U8 manifest text.
    /// - Returns: A ``Manifest`` value — either `.master` or `.media`.
    /// - Throws: ``ParserError`` if the input is not a valid HLS manifest.
    public func parse(_ string: String) throws(ParserError) -> Manifest {
        let lines = string.components(separatedBy: .newlines)

        guard let firstLine = lines.first?.trimmingCharacters(in: .whitespaces),
            firstLine == "#EXTM3U"
        else {
            throw .missingHeader
        }

        // Determine playlist type by scanning for key tags
        let isMaster = lines.contains { line in
            line.hasPrefix("#EXT-X-STREAM-INF:")
                || line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:")
        }

        if isMaster {
            return .master(try parseMasterPlaylist(lines: lines))
        } else {
            return .media(try parseMediaPlaylist(lines: lines))
        }
    }

    // MARK: - Private Helpers

    /// Parses lines into a master playlist.
    private func parseMasterPlaylist(lines: [String]) throws(ParserError) -> MasterPlaylist {
        // Stub — full implementation in a later session.
        MasterPlaylist()
    }

    /// Parses lines into a media playlist.
    private func parseMediaPlaylist(lines: [String]) throws(ParserError) -> MediaPlaylist {
        // Stub — full implementation in a later session.
        MediaPlaylist()
    }
}
