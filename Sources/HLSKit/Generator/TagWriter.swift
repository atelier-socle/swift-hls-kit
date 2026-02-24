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

    // MARK: - Media Segment Tags

    /// Writes an `EXTINF` tag line.
    ///
    /// - Parameters:
    ///   - duration: The segment duration in seconds.
    ///   - title: An optional segment title.
    ///   - version: The HLS version (controls duration precision).
    /// - Returns: The formatted tag line.
    public func writeExtInf(
        duration: Double, title: String?, version: HLSVersion?
    ) -> String {
        let formatted = formatDuration(duration, version: version)
        let titlePart = title ?? ""
        return "#EXTINF:\(formatted),\(titlePart)"
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
        var attrs: [(String, String)] = []
        attrs.append(("METHOD", key.method.rawValue))
        if let uri = key.uri {
            attrs.append(("URI", quoted(uri)))
        }
        if let iv = key.iv {
            attrs.append(("IV", iv))
        }
        if let keyFormat = key.keyFormat {
            attrs.append(("KEYFORMAT", quoted(keyFormat)))
        }
        if let versions = key.keyFormatVersions {
            attrs.append(("KEYFORMATVERSIONS", quoted(versions)))
        }
        return "#EXT-X-KEY:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-MAP` tag line.
    ///
    /// - Parameter map: The map tag value.
    /// - Returns: The formatted tag line.
    public func writeMap(_ map: MapTag) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("URI", quoted(map.uri)))
        if let byteRange = map.byteRange {
            attrs.append(("BYTERANGE", quoted(formatByteRange(byteRange))))
        }
        return "#EXT-X-MAP:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-PROGRAM-DATE-TIME` tag line.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: The formatted tag line.
    public func writeProgramDateTime(_ date: Date) -> String {
        "#EXT-X-PROGRAM-DATE-TIME:\(formatISO8601(date))"
    }

    /// Writes an `EXT-X-DATERANGE` tag line.
    ///
    /// - Parameter dateRange: The date range value.
    /// - Returns: The formatted tag line.
    public func writeDateRange(_ dateRange: DateRange) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("ID", quoted(dateRange.id)))
        attrs.append(("START-DATE", quoted(formatISO8601(dateRange.startDate))))
        if let cls = dateRange.classAttribute {
            attrs.append(("CLASS", quoted(cls)))
        }
        if let endDate = dateRange.endDate {
            attrs.append(("END-DATE", quoted(formatISO8601(endDate))))
        }
        if let duration = dateRange.duration {
            attrs.append(("DURATION", formatDecimal(duration)))
        }
        if let planned = dateRange.plannedDuration {
            attrs.append(("PLANNED-DURATION", formatDecimal(planned)))
        }
        if dateRange.endOnNext {
            attrs.append(("END-ON-NEXT", "YES"))
        }
        if let cmd = dateRange.scte35Cmd {
            attrs.append(("SCTE35-CMD", cmd))
        }
        if let out = dateRange.scte35Out {
            attrs.append(("SCTE35-OUT", out))
        }
        if let scte35In = dateRange.scte35In {
            attrs.append(("SCTE35-IN", scte35In))
        }
        for (key, value) in dateRange.clientAttributes.sorted(by: { $0.key < $1.key }) {
            attrs.append((key, quoted(value)))
        }
        return "#EXT-X-DATERANGE:\(formatAttributes(attrs))"
    }
}

// MARK: - Master Playlist Tags

extension TagWriter {

    /// Writes an `EXT-X-STREAM-INF` tag line (URI on next line).
    ///
    /// - Parameter variant: The variant stream.
    /// - Returns: The formatted tag line.
    public func writeStreamInf(_ variant: Variant) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("BANDWIDTH", "\(variant.bandwidth)"))
        if let avg = variant.averageBandwidth {
            attrs.append(("AVERAGE-BANDWIDTH", "\(avg)"))
        }
        if let resolution = variant.resolution {
            attrs.append(("RESOLUTION", formatResolution(resolution)))
        }
        if let frameRate = variant.frameRate {
            attrs.append(("FRAME-RATE", formatFrameRate(frameRate)))
        }
        if let codecs = variant.codecs {
            attrs.append(("CODECS", quoted(codecs)))
        }
        appendStreamInfGroups(variant, to: &attrs)
        return "#EXT-X-STREAM-INF:\(formatAttributes(attrs))"
    }

    private func appendStreamInfGroups(
        _ variant: Variant, to attrs: inout [(String, String)]
    ) {
        if let audio = variant.audio {
            attrs.append(("AUDIO", quoted(audio)))
        }
        if let video = variant.video {
            attrs.append(("VIDEO", quoted(video)))
        }
        if let subtitles = variant.subtitles {
            attrs.append(("SUBTITLES", quoted(subtitles)))
        }
        if let cc = variant.closedCaptions {
            switch cc {
            case .groupId(let groupId):
                attrs.append(("CLOSED-CAPTIONS", quoted(groupId)))
            case .none:
                attrs.append(("CLOSED-CAPTIONS", "NONE"))
            }
        }
        if let hdcp = variant.hdcpLevel {
            attrs.append(("HDCP-LEVEL", hdcp.rawValue))
        }
        if let videoRange = variant.videoRange {
            attrs.append(("VIDEO-RANGE", videoRange.rawValue))
        }
        if let supplemental = variant.supplementalCodecs {
            attrs.append(("SUPPLEMENTAL-CODECS", quoted(supplemental)))
        }
    }

    /// Writes an `EXT-X-I-FRAME-STREAM-INF` tag line.
    ///
    /// - Parameter variant: The I-frame variant.
    /// - Returns: The formatted tag line.
    public func writeIFrameStreamInf(_ variant: IFrameVariant) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("BANDWIDTH", "\(variant.bandwidth)"))
        if let avg = variant.averageBandwidth {
            attrs.append(("AVERAGE-BANDWIDTH", "\(avg)"))
        }
        if let resolution = variant.resolution {
            attrs.append(("RESOLUTION", formatResolution(resolution)))
        }
        if let codecs = variant.codecs {
            attrs.append(("CODECS", quoted(codecs)))
        }
        if let hdcp = variant.hdcpLevel {
            attrs.append(("HDCP-LEVEL", hdcp.rawValue))
        }
        if let video = variant.video {
            attrs.append(("VIDEO", quoted(video)))
        }
        attrs.append(("URI", quoted(variant.uri)))
        return "#EXT-X-I-FRAME-STREAM-INF:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-MEDIA` tag line.
    ///
    /// - Parameter rendition: The rendition.
    /// - Returns: The formatted tag line.
    public func writeMedia(_ rendition: Rendition) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("TYPE", rendition.type.rawValue))
        attrs.append(("GROUP-ID", quoted(rendition.groupId)))
        attrs.append(("NAME", quoted(rendition.name)))
        if rendition.isDefault {
            attrs.append(("DEFAULT", "YES"))
        }
        if rendition.autoselect {
            attrs.append(("AUTOSELECT", "YES"))
        }
        if rendition.type == .subtitles {
            attrs.append(("FORCED", formatBool(rendition.forced)))
        }
        if let language = rendition.language {
            attrs.append(("LANGUAGE", quoted(language)))
        }
        if let assocLang = rendition.assocLanguage {
            attrs.append(("ASSOC-LANGUAGE", quoted(assocLang)))
        }
        if let instreamId = rendition.instreamId {
            attrs.append(("INSTREAM-ID", quoted(instreamId)))
        }
        if let characteristics = rendition.characteristics {
            attrs.append(("CHARACTERISTICS", quoted(characteristics)))
        }
        if let channels = rendition.channels {
            attrs.append(("CHANNELS", quoted(channels)))
        }
        if let uri = rendition.uri {
            attrs.append(("URI", quoted(uri)))
        }
        return "#EXT-X-MEDIA:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-SESSION-DATA` tag line.
    ///
    /// - Parameter sessionData: The session data.
    /// - Returns: The formatted tag line.
    public func writeSessionData(_ sessionData: SessionData) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("DATA-ID", quoted(sessionData.dataId)))
        if let value = sessionData.value {
            attrs.append(("VALUE", quoted(value)))
        }
        if let uri = sessionData.uri {
            attrs.append(("URI", quoted(uri)))
        }
        if let language = sessionData.language {
            attrs.append(("LANGUAGE", quoted(language)))
        }
        return "#EXT-X-SESSION-DATA:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-CONTENT-STEERING` tag line.
    ///
    /// - Parameter steering: The content steering configuration.
    /// - Returns: The formatted tag line.
    public func writeContentSteering(
        _ steering: ContentSteering
    ) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("SERVER-URI", quoted(steering.serverUri)))
        if let pathwayId = steering.pathwayId {
            attrs.append(("PATHWAY-ID", quoted(pathwayId)))
        }
        return "#EXT-X-CONTENT-STEERING:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-SESSION-KEY` tag line.
    ///
    /// - Parameter key: The session encryption key.
    /// - Returns: The formatted tag line.
    public func writeSessionKey(_ key: EncryptionKey) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("METHOD", key.method.rawValue))
        if let uri = key.uri {
            attrs.append(("URI", quoted(uri)))
        }
        if let iv = key.iv {
            attrs.append(("IV", iv))
        }
        if let keyFormat = key.keyFormat {
            attrs.append(("KEYFORMAT", quoted(keyFormat)))
        }
        if let versions = key.keyFormatVersions {
            attrs.append(("KEYFORMATVERSIONS", quoted(versions)))
        }
        return "#EXT-X-SESSION-KEY:\(formatAttributes(attrs))"
    }
}

// MARK: - Low-Latency HLS Tags

extension TagWriter {

    /// Writes an `EXT-X-PART` tag line.
    ///
    /// - Parameter part: The partial segment.
    /// - Returns: The formatted tag line.
    public func writePart(_ part: PartialSegment) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("DURATION", formatDecimal(part.duration)))
        attrs.append(("URI", quoted(part.uri)))
        if part.independent {
            attrs.append(("INDEPENDENT", "YES"))
        }
        if let byteRange = part.byteRange {
            attrs.append(("BYTERANGE", quoted(formatByteRange(byteRange))))
        }
        if part.isGap {
            attrs.append(("GAP", "YES"))
        }
        return "#EXT-X-PART:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-PART-INF` tag line.
    ///
    /// - Parameter partTarget: The part target duration.
    /// - Returns: The formatted tag line.
    public func writePartInf(partTarget: Double) -> String {
        "#EXT-X-PART-INF:PART-TARGET=\(formatDecimal(partTarget))"
    }

    /// Writes an `EXT-X-SERVER-CONTROL` tag line.
    ///
    /// - Parameter control: The server control parameters.
    /// - Returns: The formatted tag line.
    public func writeServerControl(
        _ control: ServerControl
    ) -> String {
        var attrs: [(String, String)] = []
        if control.canBlockReload {
            attrs.append(("CAN-BLOCK-RELOAD", "YES"))
        }
        if let skipUntil = control.canSkipUntil {
            attrs.append(("CAN-SKIP-UNTIL", formatDecimal(skipUntil)))
        }
        if control.canSkipDateRanges {
            attrs.append(("CAN-SKIP-DATERANGES", "YES"))
        }
        if let holdBack = control.holdBack {
            attrs.append(("HOLD-BACK", formatDecimal(holdBack)))
        }
        if let partHoldBack = control.partHoldBack {
            attrs.append(("PART-HOLD-BACK", formatDecimal(partHoldBack)))
        }
        return "#EXT-X-SERVER-CONTROL:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-PRELOAD-HINT` tag line.
    ///
    /// - Parameter hint: The preload hint.
    /// - Returns: The formatted tag line.
    public func writePreloadHint(_ hint: PreloadHint) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("TYPE", hint.type.rawValue))
        attrs.append(("URI", quoted(hint.uri)))
        if let start = hint.byteRangeStart {
            attrs.append(("BYTERANGE-START", "\(start)"))
        }
        if let length = hint.byteRangeLength {
            attrs.append(("BYTERANGE-LENGTH", "\(length)"))
        }
        return "#EXT-X-PRELOAD-HINT:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-RENDITION-REPORT` tag line.
    ///
    /// - Parameter report: The rendition report.
    /// - Returns: The formatted tag line.
    public func writeRenditionReport(
        _ report: RenditionReport
    ) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("URI", quoted(report.uri)))
        if let msn = report.lastMediaSequence {
            attrs.append(("LAST-MSN", "\(msn)"))
        }
        if let part = report.lastPartIndex {
            attrs.append(("LAST-PART", "\(part)"))
        }
        return "#EXT-X-RENDITION-REPORT:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-SKIP` tag line.
    ///
    /// - Parameter skip: The skip information.
    /// - Returns: The formatted tag line.
    public func writeSkip(_ skip: SkipInfo) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("SKIPPED-SEGMENTS", "\(skip.skippedSegments)"))
        if !skip.recentlyRemovedDateRanges.isEmpty {
            let joined = skip.recentlyRemovedDateRanges.joined(separator: "\t")
            attrs.append(("RECENTLY-REMOVED-DATERANGES", quoted(joined)))
        }
        return "#EXT-X-SKIP:\(formatAttributes(attrs))"
    }
}

// MARK: - Common Tags

extension TagWriter {

    /// Writes an `EXT-X-START` tag line.
    ///
    /// - Parameter start: The start offset.
    /// - Returns: The formatted tag line.
    public func writeStart(_ start: StartOffset) -> String {
        var attrs: [(String, String)] = []
        attrs.append(("TIME-OFFSET", formatDecimal(start.timeOffset)))
        if start.precise {
            attrs.append(("PRECISE", "YES"))
        }
        return "#EXT-X-START:\(formatAttributes(attrs))"
    }

    /// Writes an `EXT-X-DEFINE` tag line.
    ///
    /// - Parameter definition: The variable definition.
    /// - Returns: The formatted tag line.
    public func writeDefine(_ definition: VariableDefinition) -> String {
        let attrs: [(String, String)] = [
            ("NAME", quoted(definition.name)),
            ("VALUE", quoted(definition.value))
        ]
        return "#EXT-X-DEFINE:\(formatAttributes(attrs))"
    }
}

// MARK: - Formatting Helpers

extension TagWriter {

    func formatAttributes(_ attributes: [(String, String)]) -> String {
        attributes.map { "\($0.0)=\($0.1)" }.joined(separator: ",")
    }

    func quoted(_ value: String) -> String {
        "\"\(value)\""
    }

    func formatResolution(_ resolution: Resolution) -> String {
        "\(resolution.width)x\(resolution.height)"
    }

    func formatBool(_ value: Bool) -> String {
        value ? "YES" : "NO"
    }

    func formatByteRange(_ byteRange: ByteRange) -> String {
        if let offset = byteRange.offset {
            return "\(byteRange.length)@\(offset)"
        }
        return "\(byteRange.length)"
    }

    func formatFrameRate(_ rate: Double) -> String {
        String(format: "%.3f", rate)
    }

    /// Formats a decimal value, trimming trailing zeros but keeping
    /// at least one decimal place.
    func formatDecimal(_ value: Double) -> String {
        let formatted = String(format: "%.3f", value)
        var result = formatted
        while result.hasSuffix("0") && !result.hasSuffix(".0") {
            result = String(result.dropLast())
        }
        return result
    }

    /// Formats a duration value with version-dependent precision.
    ///
    /// - For version < 3: integer format (e.g., `6`).
    /// - For version >= 3: decimal with minimal precision (e.g., `6.006`),
    ///   keeping at least one decimal place (e.g., `6.0` not `6`).
    func formatDuration(
        _ duration: Double, version: HLSVersion?
    ) -> String {
        let versionRaw = version?.rawValue ?? 3
        if versionRaw < 3 {
            return "\(Int(duration.rounded()))"
        }
        return formatDecimal(duration)
    }

    /// Formats a `Date` as ISO 8601 with fractional seconds.
    func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime, .withFractionalSeconds
        ]
        return formatter.string(from: date)
    }
}
