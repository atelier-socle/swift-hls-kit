// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Parses HLS tag attribute lists.
///
/// HLS tags use a key=value format where values can be quoted strings,
/// decimal integers, hexadecimal sequences, decimal floating-point, or
/// enumerated strings. This parser handles all formats defined in
/// RFC 8216 Section 4.2.
public struct AttributeParser: Sendable {

    /// Creates an attribute parser.
    public init() {}

    /// Parses an attribute list string into key-value pairs.
    ///
    /// Attribute lists have the format:
    /// `KEY1=VALUE1,KEY2="quoted value",KEY3=12345`
    ///
    /// - Parameter string: The attribute list string.
    /// - Returns: A dictionary of attribute name to raw string value.
    /// - Throws: ``ParserError`` if the format is invalid.
    public func parseAttributes(_ string: String) throws(ParserError) -> [String: String] {
        var attributes: [String: String] = [:]
        var remaining = string[string.startIndex...]

        while !remaining.isEmpty {
            // Skip leading whitespace and commas
            remaining = remaining.drop { $0 == "," || $0 == " " }
            guard !remaining.isEmpty else { break }

            // Find the key
            guard let equalsIndex = remaining.firstIndex(of: "=") else {
                throw .invalidTag(String(remaining))
            }

            let key = String(remaining[remaining.startIndex..<equalsIndex])
            remaining = remaining[remaining.index(after: equalsIndex)...]

            // Parse the value
            if remaining.first == "\"" {
                // Quoted string value
                remaining = remaining.dropFirst()
                guard let closeQuote = remaining.firstIndex(of: "\"") else {
                    throw .invalidAttributeValue(
                        attribute: key,
                        expectedType: "quoted string"
                    )
                }
                let value = String(remaining[remaining.startIndex..<closeQuote])
                attributes[key] = value
                remaining = remaining[remaining.index(after: closeQuote)...]
            } else {
                // Unquoted value — read until comma or end
                let commaIndex = remaining.firstIndex(of: ",") ?? remaining.endIndex
                let value = String(remaining[remaining.startIndex..<commaIndex])
                attributes[key] = value
                remaining = remaining[commaIndex...]
            }
        }

        return attributes
    }

    /// Parses a decimal integer attribute value.
    ///
    /// - Parameters:
    ///   - value: The raw string value.
    ///   - attribute: The attribute name (for error reporting).
    /// - Returns: The parsed integer.
    /// - Throws: ``ParserError`` if the value is not a valid integer.
    public func parseDecimalInteger(
        _ value: String, attribute: String
    ) throws(ParserError) -> Int {
        guard let result = Int(value) else {
            throw .invalidAttributeValue(
                attribute: attribute,
                expectedType: "decimal-integer"
            )
        }
        return result
    }

    /// Parses a decimal floating-point attribute value.
    ///
    /// - Parameters:
    ///   - value: The raw string value.
    ///   - attribute: The attribute name (for error reporting).
    /// - Returns: The parsed double.
    /// - Throws: ``ParserError`` if the value is not a valid float.
    public func parseDecimalFloat(
        _ value: String, attribute: String
    ) throws(ParserError) -> Double {
        guard let result = Double(value) else {
            throw .invalidAttributeValue(
                attribute: attribute,
                expectedType: "decimal-floating-point"
            )
        }
        return result
    }

    /// Parses a resolution attribute value in the format `WIDTHxHEIGHT`.
    ///
    /// - Parameters:
    ///   - value: The raw string value (e.g., `"1920x1080"`).
    ///   - attribute: The attribute name (for error reporting).
    /// - Returns: The parsed ``Resolution``.
    /// - Throws: ``ParserError`` if the format is invalid.
    public func parseResolution(
        _ value: String, attribute: String
    ) throws(ParserError) -> Resolution {
        let parts = value.split(separator: "x")
        guard parts.count == 2,
            let width = Int(parts[0]),
            let height = Int(parts[1])
        else {
            throw .invalidAttributeValue(
                attribute: attribute,
                expectedType: "resolution (WIDTHxHEIGHT)"
            )
        }
        return Resolution(width: width, height: height)
    }
}
