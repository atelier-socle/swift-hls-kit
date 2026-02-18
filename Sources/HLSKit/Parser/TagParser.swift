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

    // MARK: - Media Segment Tags

    /// Parses an `EXTINF` tag value: `<duration>,[<title>]`.
    ///
    /// - Parameter value: The tag value after the colon.
    /// - Returns: A tuple of duration and optional title.
    /// - Throws: ``ParserError`` if the format is invalid.
    public func parseExtInf(
        _ value: String
    ) throws(ParserError) -> (duration: Double, title: String?) {
        let parts = value.split(separator: ",", maxSplits: 1)
        guard let durationString = parts.first,
            let duration = Double(
                durationString.trimmingCharacters(in: .whitespaces)
            )
        else {
            throw .invalidAttributeValue(
                tag: "EXTINF", attribute: "duration", value: value
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

    /// Parses an `EXT-X-BYTERANGE` value: `<length>[@<offset>]`.
    ///
    /// - Parameter value: The byte range string.
    /// - Returns: A ``ByteRange`` value.
    /// - Throws: ``ParserError`` if the format is invalid.
    public func parseByteRange(
        _ value: String
    ) throws(ParserError) -> ByteRange {
        let parts = value.split(separator: "@")
        guard let length = Int(parts[0]) else {
            throw .invalidAttributeValue(
                tag: "EXT-X-BYTERANGE", attribute: "length", value: value
            )
        }

        let offset: Int?
        if parts.count > 1 {
            guard let parsed = Int(parts[1]) else {
                throw .invalidAttributeValue(
                    tag: "EXT-X-BYTERANGE",
                    attribute: "offset",
                    value: String(parts[1])
                )
            }
            offset = parsed
        } else {
            offset = nil
        }

        return ByteRange(length: length, offset: offset)
    }

    /// Parses an `EXT-X-KEY` attribute list into an ``EncryptionKey``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: An ``EncryptionKey``.
    /// - Throws: ``ParserError`` if required attributes are missing or invalid.
    public func parseKey(
        _ attributeString: String
    ) throws(ParserError) -> EncryptionKey {
        let attrs = attributeParser.parseAttributes(attributeString)
        let methodRaw = try attributeParser.requiredEnumString(
            "METHOD", from: attrs, tag: "EXT-X-KEY"
        )
        guard let method = EncryptionMethod(rawValue: methodRaw) else {
            throw .invalidAttributeValue(
                tag: "EXT-X-KEY", attribute: "METHOD", value: methodRaw
            )
        }
        return EncryptionKey(
            method: method,
            uri: attributeParser.optionalQuotedString("URI", from: attrs),
            iv: attributeParser.optionalHex("IV", from: attrs),
            keyFormat: attributeParser.optionalQuotedString(
                "KEYFORMAT", from: attrs
            ),
            keyFormatVersions: attributeParser.optionalQuotedString(
                "KEYFORMATVERSIONS", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-MAP` attribute list into a ``MapTag``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``MapTag``.
    /// - Throws: ``ParserError`` if the URI attribute is missing.
    public func parseMap(
        _ attributeString: String
    ) throws(ParserError) -> MapTag {
        let attrs = attributeParser.parseAttributes(attributeString)
        let uri = try attributeParser.requiredQuotedString(
            "URI", from: attrs, tag: "EXT-X-MAP"
        )
        var byteRange: ByteRange?
        if let rangeStr = attributeParser.optionalQuotedString(
            "BYTERANGE", from: attrs
        ) {
            byteRange = try parseByteRange(rangeStr)
        }
        return MapTag(uri: uri, byteRange: byteRange)
    }

    /// Parses an `EXT-X-DATERANGE` attribute list into a ``DateRange``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``DateRange``.
    /// - Throws: ``ParserError`` if required attributes are missing.
    public func parseDateRange(
        _ attributeString: String
    ) throws(ParserError) -> DateRange {
        let attrs = attributeParser.parseAttributes(attributeString)
        let id = try attributeParser.requiredQuotedString(
            "ID", from: attrs, tag: "EXT-X-DATERANGE"
        )
        let startDateStr = try attributeParser.requiredQuotedString(
            "START-DATE", from: attrs, tag: "EXT-X-DATERANGE"
        )
        guard let startDate = Self.parseISO8601Date(startDateStr) else {
            throw .invalidAttributeValue(
                tag: "EXT-X-DATERANGE",
                attribute: "START-DATE",
                value: startDateStr
            )
        }

        var endDate: Date?
        if let endDateStr = attributeParser.optionalQuotedString(
            "END-DATE", from: attrs
        ) {
            endDate = Self.parseISO8601Date(endDateStr)
        }

        var clientAttributes: [String: String] = [:]
        for (key, value) in attrs where key.hasPrefix("X-") {
            clientAttributes[key] = value
        }

        return DateRange(
            id: id,
            startDate: startDate,
            classAttribute: attributeParser.optionalQuotedString(
                "CLASS", from: attrs
            ),
            endDate: endDate,
            duration: attributeParser.optionalDouble(
                "DURATION", from: attrs
            ),
            plannedDuration: attributeParser.optionalDouble(
                "PLANNED-DURATION", from: attrs
            ),
            endOnNext: attributeParser.optionalBool(
                "END-ON-NEXT", from: attrs
            ) ?? false,
            clientAttributes: clientAttributes,
            scte35Cmd: attributeParser.optionalHex(
                "SCTE35-CMD", from: attrs
            ),
            scte35Out: attributeParser.optionalHex(
                "SCTE35-OUT", from: attrs
            ),
            scte35In: attributeParser.optionalHex(
                "SCTE35-IN", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-PROGRAM-DATE-TIME` ISO 8601 date string.
    ///
    /// - Parameter value: The ISO 8601 date string.
    /// - Returns: The parsed `Date`.
    /// - Throws: ``ParserError`` if the date format is invalid.
    public func parseProgramDateTime(
        _ value: String
    ) throws(ParserError) -> Date {
        guard let date = Self.parseISO8601Date(value) else {
            throw .invalidAttributeValue(
                tag: "EXT-X-PROGRAM-DATE-TIME",
                attribute: "date",
                value: value
            )
        }
        return date
    }

}

// MARK: - Master Playlist Tags

extension TagParser {

    /// Parses an `EXT-X-STREAM-INF` attribute list into a ``Variant``.
    ///
    /// The URI is not included; it is read from the next line by the manifest parser.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``Variant`` with an empty URI (to be filled by caller).
    /// - Throws: ``ParserError`` if the BANDWIDTH attribute is missing.
    public func parseStreamInf(
        _ attributeString: String
    ) throws(ParserError) -> Variant {
        let attrs = attributeParser.parseAttributes(attributeString)
        let bandwidth = try attributeParser.requiredInteger(
            "BANDWIDTH", from: attrs, tag: "EXT-X-STREAM-INF"
        )

        var closedCaptions: ClosedCaptionsValue?
        if let ccValue = attrs["CLOSED-CAPTIONS"] {
            if ccValue == "NONE" {
                closedCaptions = ClosedCaptionsValue.none
            } else {
                closedCaptions = .groupId(ccValue)
            }
        }

        var hdcpLevel: HDCPLevel?
        if let raw = attributeParser.optionalEnumString(
            "HDCP-LEVEL", from: attrs
        ) {
            hdcpLevel = HDCPLevel(rawValue: raw)
        }

        return Variant(
            bandwidth: bandwidth,
            resolution: attributeParser.optionalResolution(
                "RESOLUTION", from: attrs
            ),
            uri: "",
            averageBandwidth: attributeParser.optionalInteger(
                "AVERAGE-BANDWIDTH", from: attrs
            ),
            codecs: attributeParser.optionalQuotedString(
                "CODECS", from: attrs
            ),
            frameRate: attributeParser.optionalDouble(
                "FRAME-RATE", from: attrs
            ),
            hdcpLevel: hdcpLevel,
            audio: attributeParser.optionalQuotedString(
                "AUDIO", from: attrs
            ),
            video: attributeParser.optionalQuotedString(
                "VIDEO", from: attrs
            ),
            subtitles: attributeParser.optionalQuotedString(
                "SUBTITLES", from: attrs
            ),
            closedCaptions: closedCaptions
        )
    }

    /// Parses an `EXT-X-I-FRAME-STREAM-INF` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: An ``IFrameVariant``.
    /// - Throws: ``ParserError`` if required attributes are missing.
    public func parseIFrameStreamInf(
        _ attributeString: String
    ) throws(ParserError) -> IFrameVariant {
        let attrs = attributeParser.parseAttributes(attributeString)
        let bandwidth = try attributeParser.requiredInteger(
            "BANDWIDTH", from: attrs, tag: "EXT-X-I-FRAME-STREAM-INF"
        )
        let uri = try attributeParser.requiredQuotedString(
            "URI", from: attrs, tag: "EXT-X-I-FRAME-STREAM-INF"
        )

        var hdcpLevel: HDCPLevel?
        if let raw = attributeParser.optionalEnumString(
            "HDCP-LEVEL", from: attrs
        ) {
            hdcpLevel = HDCPLevel(rawValue: raw)
        }

        return IFrameVariant(
            bandwidth: bandwidth,
            uri: uri,
            averageBandwidth: attributeParser.optionalInteger(
                "AVERAGE-BANDWIDTH", from: attrs
            ),
            codecs: attributeParser.optionalQuotedString(
                "CODECS", from: attrs
            ),
            resolution: attributeParser.optionalResolution(
                "RESOLUTION", from: attrs
            ),
            hdcpLevel: hdcpLevel,
            video: attributeParser.optionalQuotedString(
                "VIDEO", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-MEDIA` attribute list into a ``Rendition``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``Rendition``.
    /// - Throws: ``ParserError`` if required attributes are missing.
    public func parseMedia(
        _ attributeString: String
    ) throws(ParserError) -> Rendition {
        let attrs = attributeParser.parseAttributes(attributeString)
        let typeRaw = try attributeParser.requiredEnumString(
            "TYPE", from: attrs, tag: "EXT-X-MEDIA"
        )
        guard let type = MediaType(rawValue: typeRaw) else {
            throw .invalidAttributeValue(
                tag: "EXT-X-MEDIA", attribute: "TYPE", value: typeRaw
            )
        }
        let groupId = try attributeParser.requiredQuotedString(
            "GROUP-ID", from: attrs, tag: "EXT-X-MEDIA"
        )
        let name = try attributeParser.requiredQuotedString(
            "NAME", from: attrs, tag: "EXT-X-MEDIA"
        )

        return Rendition(
            type: type,
            groupId: groupId,
            name: name,
            uri: attributeParser.optionalQuotedString("URI", from: attrs),
            language: attributeParser.optionalQuotedString(
                "LANGUAGE", from: attrs
            ),
            assocLanguage: attributeParser.optionalQuotedString(
                "ASSOC-LANGUAGE", from: attrs
            ),
            isDefault: attributeParser.optionalBool(
                "DEFAULT", from: attrs
            ) ?? false,
            autoselect: attributeParser.optionalBool(
                "AUTOSELECT", from: attrs
            ) ?? false,
            forced: attributeParser.optionalBool(
                "FORCED", from: attrs
            ) ?? false,
            instreamId: attributeParser.optionalQuotedString(
                "INSTREAM-ID", from: attrs
            ),
            characteristics: attributeParser.optionalQuotedString(
                "CHARACTERISTICS", from: attrs
            ),
            channels: attributeParser.optionalQuotedString(
                "CHANNELS", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-SESSION-DATA` attribute list into a ``SessionData``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``SessionData``.
    /// - Throws: ``ParserError`` if the DATA-ID attribute is missing.
    public func parseSessionData(
        _ attributeString: String
    ) throws(ParserError) -> SessionData {
        let attrs = attributeParser.parseAttributes(attributeString)
        let dataId = try attributeParser.requiredQuotedString(
            "DATA-ID", from: attrs, tag: "EXT-X-SESSION-DATA"
        )
        return SessionData(
            dataId: dataId,
            value: attributeParser.optionalQuotedString(
                "VALUE", from: attrs
            ),
            uri: attributeParser.optionalQuotedString("URI", from: attrs),
            language: attributeParser.optionalQuotedString(
                "LANGUAGE", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-CONTENT-STEERING` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``ContentSteering``.
    /// - Throws: ``ParserError`` if the SERVER-URI attribute is missing.
    public func parseContentSteering(
        _ attributeString: String
    ) throws(ParserError) -> ContentSteering {
        let attrs = attributeParser.parseAttributes(attributeString)
        let serverUri = try attributeParser.requiredQuotedString(
            "SERVER-URI", from: attrs, tag: "EXT-X-CONTENT-STEERING"
        )
        return ContentSteering(
            serverUri: serverUri,
            pathwayId: attributeParser.optionalQuotedString(
                "PATHWAY-ID", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-SESSION-KEY` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: An ``EncryptionKey``.
    /// - Throws: ``ParserError`` if required attributes are missing.
    public func parseSessionKey(
        _ attributeString: String
    ) throws(ParserError) -> EncryptionKey {
        try parseKey(attributeString)
    }
}

// MARK: - Low-Latency HLS Tags

extension TagParser {

    /// Parses an `EXT-X-PART` attribute list into a ``PartialSegment``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``PartialSegment``.
    /// - Throws: ``ParserError`` if required attributes are missing.
    public func parsePart(
        _ attributeString: String
    ) throws(ParserError) -> PartialSegment {
        let attrs = attributeParser.parseAttributes(attributeString)
        let uri = try attributeParser.requiredQuotedString(
            "URI", from: attrs, tag: "EXT-X-PART"
        )
        let duration = try attributeParser.requiredDouble(
            "DURATION", from: attrs, tag: "EXT-X-PART"
        )

        var byteRange: ByteRange?
        if let rangeStr = attributeParser.optionalQuotedString(
            "BYTERANGE", from: attrs
        ) {
            byteRange = try parseByteRange(rangeStr)
        }

        return PartialSegment(
            uri: uri,
            duration: duration,
            independent: attributeParser.optionalBool(
                "INDEPENDENT", from: attrs
            ) ?? false,
            byteRange: byteRange,
            isGap: attributeParser.optionalBool(
                "GAP", from: attrs
            ) ?? false
        )
    }

    /// Parses an `EXT-X-PART-INF` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: The part target duration in seconds.
    /// - Throws: ``ParserError`` if the PART-TARGET attribute is missing.
    public func parsePartInf(
        _ attributeString: String
    ) throws(ParserError) -> Double {
        let attrs = attributeParser.parseAttributes(attributeString)
        return try attributeParser.requiredDouble(
            "PART-TARGET", from: attrs, tag: "EXT-X-PART-INF"
        )
    }

    /// Parses an `EXT-X-SERVER-CONTROL` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``ServerControl``.
    public func parseServerControl(
        _ attributeString: String
    ) -> ServerControl {
        let attrs = attributeParser.parseAttributes(attributeString)
        return ServerControl(
            canBlockReload: attributeParser.optionalBool(
                "CAN-BLOCK-RELOAD", from: attrs
            ) ?? false,
            canSkipUntil: attributeParser.optionalDouble(
                "CAN-SKIP-UNTIL", from: attrs
            ),
            canSkipDateRanges: attributeParser.optionalBool(
                "CAN-SKIP-DATERANGES", from: attrs
            ) ?? false,
            holdBack: attributeParser.optionalDouble(
                "HOLD-BACK", from: attrs
            ),
            partHoldBack: attributeParser.optionalDouble(
                "PART-HOLD-BACK", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-PRELOAD-HINT` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``PreloadHint``.
    /// - Throws: ``ParserError`` if required attributes are missing.
    public func parsePreloadHint(
        _ attributeString: String
    ) throws(ParserError) -> PreloadHint {
        let attrs = attributeParser.parseAttributes(attributeString)
        let typeRaw = try attributeParser.requiredEnumString(
            "TYPE", from: attrs, tag: "EXT-X-PRELOAD-HINT"
        )
        guard let type = PreloadHintType(rawValue: typeRaw) else {
            throw .invalidAttributeValue(
                tag: "EXT-X-PRELOAD-HINT",
                attribute: "TYPE",
                value: typeRaw
            )
        }
        let uri = try attributeParser.requiredQuotedString(
            "URI", from: attrs, tag: "EXT-X-PRELOAD-HINT"
        )
        return PreloadHint(
            type: type,
            uri: uri,
            byteRangeStart: attributeParser.optionalInteger(
                "BYTERANGE-START", from: attrs
            ),
            byteRangeLength: attributeParser.optionalInteger(
                "BYTERANGE-LENGTH", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-RENDITION-REPORT` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``RenditionReport``.
    /// - Throws: ``ParserError`` if the URI attribute is missing.
    public func parseRenditionReport(
        _ attributeString: String
    ) throws(ParserError) -> RenditionReport {
        let attrs = attributeParser.parseAttributes(attributeString)
        let uri = try attributeParser.requiredQuotedString(
            "URI", from: attrs, tag: "EXT-X-RENDITION-REPORT"
        )
        return RenditionReport(
            uri: uri,
            lastMediaSequence: attributeParser.optionalInteger(
                "LAST-MSN", from: attrs
            ),
            lastPartIndex: attributeParser.optionalInteger(
                "LAST-PART", from: attrs
            )
        )
    }

    /// Parses an `EXT-X-SKIP` attribute list into a ``SkipInfo``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``SkipInfo``.
    /// - Throws: ``ParserError`` if required attributes are missing.
    public func parseSkip(
        _ attributeString: String
    ) throws(ParserError) -> SkipInfo {
        let attrs = attributeParser.parseAttributes(attributeString)
        let skipped = try attributeParser.requiredInteger(
            "SKIPPED-SEGMENTS", from: attrs, tag: "EXT-X-SKIP"
        )
        var removedDateRanges: [String] = []
        if let raw = attributeParser.optionalQuotedString(
            "RECENTLY-REMOVED-DATERANGES", from: attrs
        ) {
            removedDateRanges = raw.split(separator: "\t").map(String.init)
        }
        return SkipInfo(
            skippedSegments: skipped,
            recentlyRemovedDateRanges: removedDateRanges
        )
    }
}

// MARK: - Common Tags

extension TagParser {

    /// Parses an `EXT-X-START` attribute list into a ``StartOffset``.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``StartOffset``.
    /// - Throws: ``ParserError`` if the TIME-OFFSET attribute is missing.
    public func parseStart(
        _ attributeString: String
    ) throws(ParserError) -> StartOffset {
        let attrs = attributeParser.parseAttributes(attributeString)
        let timeOffset = try attributeParser.requiredDouble(
            "TIME-OFFSET", from: attrs, tag: "EXT-X-START"
        )
        return StartOffset(
            timeOffset: timeOffset,
            precise: attributeParser.optionalBool(
                "PRECISE", from: attrs
            ) ?? false
        )
    }

    /// Parses an `EXT-X-DEFINE` attribute list.
    ///
    /// - Parameter attributeString: The raw attribute list.
    /// - Returns: A ``VariableDefinition``, or `nil` if it's an IMPORT.
    /// - Throws: ``ParserError`` if the definition is invalid.
    public func parseDefine(
        _ attributeString: String
    ) throws(ParserError) -> VariableDefinition? {
        let attrs = attributeParser.parseAttributes(attributeString)
        if let name = attributeParser.optionalQuotedString(
            "NAME", from: attrs
        ),
            let value = attributeParser.optionalQuotedString(
                "VALUE", from: attrs
            )
        {
            return VariableDefinition(name: name, value: value)
        }
        // IMPORT definitions are resolved at a higher level
        return nil
    }

    /// Parses an attribute list from a tag value.
    ///
    /// - Parameter value: The raw attribute list string.
    /// - Returns: A dictionary of attribute key-value pairs.
    public func parseAttributeList(_ value: String) -> [String: String] {
        attributeParser.parseAttributes(value)
    }
}

// MARK: - Date Parsing

extension TagParser {

    /// Parses an ISO 8601 date string.
    ///
    /// Supports both formats with and without fractional seconds.
    ///
    /// - Parameter string: The ISO 8601 date string.
    /// - Returns: The parsed `Date`, or `nil` if the format is invalid.
    static func parseISO8601Date(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds
        ]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }
}
