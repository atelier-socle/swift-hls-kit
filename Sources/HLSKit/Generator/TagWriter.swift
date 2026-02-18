// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Serializes HLS model values into M3U8 tag strings.
///
/// This is the inverse of ``TagParser``: it takes typed Swift values
/// and produces the corresponding M3U8 tag lines.
public struct TagWriter: Sendable {

    /// Creates a tag writer.
    public init() {}

    /// Writes an `EXTINF` tag line.
    ///
    /// - Parameters:
    ///   - duration: The segment duration in seconds.
    ///   - title: An optional segment title.
    /// - Returns: The formatted tag line (e.g., `#EXTINF:6.006,`).
    public func writeExtInf(duration: Double, title: String?) -> String {
        let titlePart = title ?? ""
        return "#EXTINF:\(formatDuration(duration)),\(titlePart)"
    }

    /// Writes an `EXT-X-BYTERANGE` tag line.
    ///
    /// - Parameter byteRange: The byte range value.
    /// - Returns: The formatted tag line.
    public func writeByteRange(_ byteRange: ByteRange) -> String {
        if let offset = byteRange.offset {
            return "#EXT-X-BYTERANGE:\(byteRange.length)@\(offset)"
        }
        return "#EXT-X-BYTERANGE:\(byteRange.length)"
    }

    /// Writes an `EXT-X-KEY` tag line.
    ///
    /// - Parameter key: The encryption key parameters.
    /// - Returns: The formatted tag line.
    public func writeKey(_ key: EncryptionKey) -> String {
        var attributes = "METHOD=\(key.method.rawValue)"
        if let uri = key.uri {
            attributes += ",URI=\"\(uri)\""
        }
        if let iv = key.iv {
            attributes += ",IV=\(iv)"
        }
        if let keyFormat = key.keyFormat {
            attributes += ",KEYFORMAT=\"\(keyFormat)\""
        }
        if let keyFormatVersions = key.keyFormatVersions {
            attributes += ",KEYFORMATVERSIONS=\"\(keyFormatVersions)\""
        }
        return "#EXT-X-KEY:\(attributes)"
    }

    /// Writes an `EXT-X-MAP` tag line.
    ///
    /// - Parameter map: The map tag value.
    /// - Returns: The formatted tag line.
    public func writeMap(_ map: MapTag) -> String {
        var attributes = "URI=\"\(map.uri)\""
        if let byteRange = map.byteRange {
            let rangeString: String
            if let offset = byteRange.offset {
                rangeString = "\(byteRange.length)@\(offset)"
            } else {
                rangeString = "\(byteRange.length)"
            }
            attributes += ",BYTERANGE=\"\(rangeString)\""
        }
        return "#EXT-X-MAP:\(attributes)"
    }

    // MARK: - Private Helpers

    /// Formats a duration value, using integer format when possible.
    private func formatDuration(_ duration: Double) -> String {
        if duration == duration.rounded() && duration >= 0 {
            return String(format: "%.0f", duration)
        }
        // Use up to 3 decimal places, trimming trailing zeros
        let formatted = String(format: "%.3f", duration)
        var result = formatted
        while result.hasSuffix("0") {
            result = String(result.dropLast())
        }
        if result.hasSuffix(".") {
            result = String(result.dropLast())
        }
        return result
    }
}
