// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors that can occur during M3U8 manifest parsing.
///
/// - SeeAlso: RFC 8216, Section 4
public enum ParserError: Error, Sendable, Hashable, LocalizedError {

    /// The input string is empty or contains only whitespace.
    case emptyManifest

    /// The first line is not `#EXTM3U`.
    case missingHeader

    /// Unable to determine if the manifest is a master or media playlist.
    case ambiguousPlaylistType

    /// A required tag is missing (e.g., `EXT-X-TARGETDURATION` in media playlist).
    ///
    /// - Parameter tag: The name of the missing tag.
    case missingRequiredTag(String)

    /// A required attribute is missing from a tag.
    ///
    /// - Parameters:
    ///   - tag: The tag containing the missing attribute.
    ///   - attribute: The missing attribute name.
    case missingRequiredAttribute(tag: String, attribute: String)

    /// An attribute value has an invalid format.
    ///
    /// - Parameters:
    ///   - tag: The tag containing the attribute.
    ///   - attribute: The attribute name.
    ///   - value: The invalid value.
    case invalidAttributeValue(tag: String, attribute: String, value: String)

    /// A tag has an invalid format or cannot be parsed.
    ///
    /// - Parameters:
    ///   - tag: The tag name.
    ///   - line: The line number where the error occurred.
    case invalidTagFormat(tag: String, line: Int)

    /// An `EXTINF` duration value is invalid.
    ///
    /// - Parameter line: The line number where the error occurred.
    case invalidDuration(line: Int)

    /// A URI is expected but missing (e.g., after `EXT-X-STREAM-INF`).
    ///
    /// - Parameters:
    ///   - afterTag: The tag that requires a URI on the following line.
    ///   - line: The line number of the tag.
    case missingURI(afterTag: String, line: Int)

    /// The `EXT-X-VERSION` value is unsupported or invalid.
    ///
    /// - Parameter version: The invalid version string.
    case invalidVersion(String)

    /// Generic parsing failure with context.
    ///
    /// - Parameters:
    ///   - reason: A description of the failure.
    ///   - line: The optional line number where the error occurred.
    case parsingFailed(reason: String, line: Int?)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .emptyManifest:
            "The manifest is empty or contains only whitespace."
        case .missingHeader:
            "The playlist does not start with #EXTM3U."
        case .ambiguousPlaylistType:
            "Unable to determine if the manifest is a master or media playlist."
        case .missingRequiredTag(let tag):
            "Missing required tag: \(tag)."
        case .missingRequiredAttribute(let tag, let attribute):
            "Missing required attribute '\(attribute)' in \(tag)."
        case .invalidAttributeValue(let tag, let attribute, let value):
            "Invalid value '\(value)' for attribute '\(attribute)' in \(tag)."
        case .invalidTagFormat(let tag, let line):
            "Invalid format for tag '\(tag)' at line \(line)."
        case .invalidDuration(let line):
            "Invalid EXTINF duration at line \(line)."
        case .missingURI(let afterTag, let line):
            "Missing URI after \(afterTag) at line \(line)."
        case .invalidVersion(let version):
            "Invalid or unsupported EXT-X-VERSION value: \(version)."
        case .parsingFailed(let reason, let line):
            if let line {
                "Parsing failed at line \(line): \(reason)"
            } else {
                "Parsing failed: \(reason)"
            }
        }
    }
}
