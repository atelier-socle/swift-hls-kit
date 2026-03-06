// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

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
            removedDateRanges = raw.split(separator: "\t").map(
                String.init
            )
        }
        return SkipInfo(
            skippedSegments: skipped,
            recentlyRemovedDateRanges: removedDateRanges
        )
    }
}
