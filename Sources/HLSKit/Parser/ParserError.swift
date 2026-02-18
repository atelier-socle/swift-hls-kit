// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors that can occur during HLS manifest parsing.
public enum ParserError: Error, Sendable, Hashable, LocalizedError {

    /// The input does not start with the `#EXTM3U` header.
    case missingHeader

    /// An unrecognized or malformed tag was encountered.
    ///
    /// - Parameter tag: The tag string that could not be parsed.
    case invalidTag(String)

    /// A required attribute is missing from a tag.
    ///
    /// - Parameters:
    ///   - attribute: The missing attribute name.
    ///   - tag: The tag where the attribute was expected.
    case missingAttribute(attribute: String, tag: String)

    /// An attribute value could not be converted to the expected type.
    ///
    /// - Parameters:
    ///   - attribute: The attribute name.
    ///   - expectedType: A description of the expected type.
    case invalidAttributeValue(attribute: String, expectedType: String)

    /// The playlist is empty (no segments or variants).
    case emptyPlaylist

    /// A generic parsing error with a message.
    ///
    /// - Parameter message: A description of the error.
    case parsingFailed(String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .missingHeader:
            return "The playlist does not start with #EXTM3U."
        case .invalidTag(let tag):
            return "Invalid or unrecognized tag: \(tag)"
        case .missingAttribute(let attribute, let tag):
            return "Missing required attribute '\(attribute)' in \(tag)."
        case .invalidAttributeValue(let attribute, let expectedType):
            return "Invalid value for attribute '\(attribute)': expected \(expectedType)."
        case .emptyPlaylist:
            return "The playlist contains no segments or variants."
        case .parsingFailed(let message):
            return "Parsing failed: \(message)"
        }
    }
}
