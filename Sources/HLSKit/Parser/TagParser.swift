// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Parses individual HLS tags and their attributes.
///
/// This parser handles the specifics of each tag type, delegating
/// attribute parsing to ``AttributeParser``. It converts raw tag
/// lines into typed model values.
public struct TagParser: Sendable {

    /// The attribute parser used for key-value attribute lists.
    private let attributeParser: AttributeParser

    /// Creates a tag parser.
    ///
    /// - Parameter attributeParser: The attribute parser to use.
    public init(attributeParser: AttributeParser = AttributeParser()) {
        self.attributeParser = attributeParser
    }

    /// Parses an `EXTINF` tag line into a duration and optional title.
    ///
    /// The format is `#EXTINF:<duration>,[<title>]`.
    ///
    /// - Parameter value: The tag value after the colon.
    /// - Returns: A tuple of duration and optional title.
    /// - Throws: ``ParserError`` if the format is invalid.
    public func parseExtInf(_ value: String) throws(ParserError) -> (duration: Double, title: String?) {
        let parts = value.split(separator: ",", maxSplits: 1)
        guard let durationString = parts.first,
            let duration = Double(durationString.trimmingCharacters(in: .whitespaces))
        else {
            throw .invalidAttributeValue(
                attribute: "EXTINF",
                expectedType: "decimal-floating-point"
            )
        }

        let title: String?
        if parts.count > 1 {
            let trimmed = parts[1].trimmingCharacters(in: .whitespaces)
            title = trimmed.isEmpty ? nil : trimmed
        } else {
            title = nil
        }

        return (duration, title)
    }

    /// Parses a `BYTERANGE` value in the format `<length>[@<offset>]`.
    ///
    /// - Parameter value: The byte range string.
    /// - Returns: A ``ByteRange`` value.
    /// - Throws: ``ParserError`` if the format is invalid.
    public func parseByteRange(_ value: String) throws(ParserError) -> ByteRange {
        let parts = value.split(separator: "@")
        guard let length = Int(parts[0]) else {
            throw .invalidAttributeValue(
                attribute: "BYTERANGE",
                expectedType: "length[@offset]"
            )
        }

        let offset: Int?
        if parts.count > 1 {
            guard let parsed = Int(parts[1]) else {
                throw .invalidAttributeValue(
                    attribute: "BYTERANGE",
                    expectedType: "length[@offset]"
                )
            }
            offset = parsed
        } else {
            offset = nil
        }

        return ByteRange(length: length, offset: offset)
    }

    /// Parses an attribute list from a tag value.
    ///
    /// - Parameter value: The raw attribute list string.
    /// - Returns: A dictionary of attribute key-value pairs.
    /// - Throws: ``ParserError`` if the format is invalid.
    public func parseAttributeList(_ value: String) throws(ParserError) -> [String: String] {
        try attributeParser.parseAttributes(value)
    }
}
