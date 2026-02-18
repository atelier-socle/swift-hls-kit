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

    // MARK: - Attribute List Parsing

    /// Parses an attribute list string into key-value pairs.
    ///
    /// Attribute lists have the format:
    /// `KEY1=VALUE1,KEY2="quoted value",KEY3=12345`
    ///
    /// - Parameter string: The attribute list string.
    /// - Returns: A dictionary of attribute name to raw string value.
    public func parseAttributes(_ string: String) -> [String: String] {
        var attributes: [String: String] = [:]
        var remaining = string[string.startIndex...]

        while !remaining.isEmpty {
            remaining = remaining.drop { $0 == "," || $0 == " " }
            guard !remaining.isEmpty else { break }

            guard let equalsIndex = remaining.firstIndex(of: "=") else {
                break
            }

            let key = String(remaining[remaining.startIndex..<equalsIndex])
            remaining = remaining[remaining.index(after: equalsIndex)...]

            if remaining.first == "\"" {
                remaining = remaining.dropFirst()
                guard let closeQuote = remaining.firstIndex(of: "\"") else {
                    attributes[key] = String(remaining)
                    break
                }
                let value = String(remaining[remaining.startIndex..<closeQuote])
                attributes[key] = value
                remaining = remaining[remaining.index(after: closeQuote)...]
            } else {
                let commaIndex = remaining.firstIndex(of: ",") ?? remaining.endIndex
                let value = String(remaining[remaining.startIndex..<commaIndex])
                attributes[key] = value
                remaining = remaining[commaIndex...]
            }
        }

        return attributes
    }

    // MARK: - Required Extraction

    /// Extracts a required decimal integer value from an attributes dictionary.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    ///   - tag: The tag name for error reporting.
    /// - Returns: The parsed integer value.
    /// - Throws: ``ParserError`` if the attribute is missing or invalid.
    public func requiredInteger(
        _ key: String, from attributes: [String: String], tag: String
    ) throws(ParserError) -> Int {
        guard let raw = attributes[key] else {
            throw .missingRequiredAttribute(tag: tag, attribute: key)
        }
        guard let value = Int(raw) else {
            throw .invalidAttributeValue(tag: tag, attribute: key, value: raw)
        }
        return value
    }

    /// Extracts a required decimal floating-point value.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    ///   - tag: The tag name for error reporting.
    /// - Returns: The parsed double value.
    /// - Throws: ``ParserError`` if the attribute is missing or invalid.
    public func requiredDouble(
        _ key: String, from attributes: [String: String], tag: String
    ) throws(ParserError) -> Double {
        guard let raw = attributes[key] else {
            throw .missingRequiredAttribute(tag: tag, attribute: key)
        }
        guard let value = Double(raw) else {
            throw .invalidAttributeValue(tag: tag, attribute: key, value: raw)
        }
        return value
    }

    /// Extracts a required quoted string value.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    ///   - tag: The tag name for error reporting.
    /// - Returns: The string value (quotes already stripped by `parseAttributes`).
    /// - Throws: ``ParserError`` if the attribute is missing.
    public func requiredQuotedString(
        _ key: String, from attributes: [String: String], tag: String
    ) throws(ParserError) -> String {
        guard let value = attributes[key] else {
            throw .missingRequiredAttribute(tag: tag, attribute: key)
        }
        return value
    }

    /// Extracts a required enumerated string value (unquoted).
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    ///   - tag: The tag name for error reporting.
    /// - Returns: The unquoted string value.
    /// - Throws: ``ParserError`` if the attribute is missing.
    public func requiredEnumString(
        _ key: String, from attributes: [String: String], tag: String
    ) throws(ParserError) -> String {
        guard let value = attributes[key] else {
            throw .missingRequiredAttribute(tag: tag, attribute: key)
        }
        return value
    }

    // MARK: - Optional Extraction

    /// Extracts an optional decimal integer value.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    /// - Returns: The parsed integer, or `nil` if absent or invalid.
    public func optionalInteger(
        _ key: String, from attributes: [String: String]
    ) -> Int? {
        attributes[key].flatMap { Int($0) }
    }

    /// Extracts an optional decimal floating-point value.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    /// - Returns: The parsed double, or `nil` if absent or invalid.
    public func optionalDouble(
        _ key: String, from attributes: [String: String]
    ) -> Double? {
        attributes[key].flatMap { Double($0) }
    }

    /// Extracts an optional quoted string value.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    /// - Returns: The string value, or `nil` if absent.
    public func optionalQuotedString(
        _ key: String, from attributes: [String: String]
    ) -> String? {
        attributes[key]
    }

    /// Extracts an optional enumerated string value (unquoted).
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    /// - Returns: The string value, or `nil` if absent.
    public func optionalEnumString(
        _ key: String, from attributes: [String: String]
    ) -> String? {
        attributes[key]
    }

    /// Extracts an optional resolution value (`WIDTHxHEIGHT`).
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    /// - Returns: The parsed resolution, or `nil` if absent or invalid.
    public func optionalResolution(
        _ key: String, from attributes: [String: String]
    ) -> Resolution? {
        guard let raw = attributes[key] else { return nil }
        let parts = raw.split(separator: "x")
        guard parts.count == 2,
            let width = Int(parts[0]),
            let height = Int(parts[1])
        else { return nil }
        return Resolution(width: width, height: height)
    }

    /// Extracts an optional hexadecimal value (0x-prefixed).
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    /// - Returns: The raw hex string, or `nil` if absent.
    public func optionalHex(
        _ key: String, from attributes: [String: String]
    ) -> String? {
        attributes[key]
    }

    /// Extracts an optional boolean (`YES`/`NO`) value.
    ///
    /// - Parameters:
    ///   - key: The attribute key.
    ///   - attributes: The parsed attributes dictionary.
    /// - Returns: `true` for `"YES"`, `false` for `"NO"`, or `nil` if absent.
    public func optionalBool(
        _ key: String, from attributes: [String: String]
    ) -> Bool? {
        guard let raw = attributes[key] else { return nil }
        return raw == "YES"
    }

    // MARK: - Low-Level Parsing (kept for backward compatibility)

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
                tag: "", attribute: attribute, value: value
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
                tag: "", attribute: attribute, value: value
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
                tag: "", attribute: attribute, value: value
            )
        }
        return Resolution(width: width, height: height)
    }
}
