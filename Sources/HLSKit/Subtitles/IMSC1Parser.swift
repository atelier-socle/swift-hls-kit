// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
#if canImport(FoundationXML)
    import FoundationXML
#endif

// MARK: - IMSC1Error

/// Errors encountered when parsing IMSC1 (TTML) documents.
public enum IMSC1Error: Error, Sendable, Equatable {

    /// The input is not valid XML.
    case invalidXML(String)

    /// The root `<tt>` element is missing.
    case missingTTElement

    /// A timecode value could not be parsed.
    case invalidTimecode(String)

    /// The required `xml:lang` attribute is missing on `<tt>`.
    case missingLanguage
}

// MARK: - IMSC1Parser

/// Parses IMSC1 Text Profile (TTML) XML into an ``IMSC1Document``.
///
/// Uses Foundation's `XMLParser` (SAX) for cross-platform compatibility.
///
/// ```swift
/// let xml = "<tt xml:lang=\"en\" ...>...</tt>"
/// let document = try IMSC1Parser.parse(xml: xml)
/// ```
public struct IMSC1Parser: Sendable {

    /// Parses an IMSC1 TTML XML string into a document model.
    ///
    /// - Parameter xml: The TTML XML string to parse.
    /// - Returns: The parsed ``IMSC1Document``.
    /// - Throws: ``IMSC1Error`` if the XML is malformed or missing
    ///   required elements.
    public static func parse(xml: String) throws -> IMSC1Document {
        guard let data = xml.data(using: .utf8) else {
            throw IMSC1Error.invalidXML("Unable to encode as UTF-8")
        }
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = false
        let delegate = IMSC1ParserDelegate()
        parser.delegate = delegate
        guard parser.parse() else {
            if let error = delegate.parseError {
                throw error
            }
            let xmlError =
                parser.parserError?.localizedDescription
                ?? "Unknown XML error"
            throw IMSC1Error.invalidXML(xmlError)
        }
        if let error = delegate.parseError {
            throw error
        }
        guard delegate.foundTTElement else {
            throw IMSC1Error.missingTTElement
        }
        guard let language = delegate.language else {
            throw IMSC1Error.missingLanguage
        }
        return IMSC1Document(
            language: language,
            regions: delegate.regions,
            styles: delegate.styles,
            subtitles: delegate.subtitles
        )
    }
}

// MARK: - Timecode Parsing

extension IMSC1Parser {

    /// Parses a TTML timecode string into seconds.
    ///
    /// Supports `HH:MM:SS.mmm` and `HH:MM:SS` formats.
    ///
    /// - Parameter timecode: The timecode string.
    /// - Returns: Time in seconds.
    /// - Throws: ``IMSC1Error/invalidTimecode(_:)`` if the format
    ///   is not recognized.
    static func parseTimecode(_ timecode: String) throws -> Double {
        let trimmed = timecode.trimmingCharacters(
            in: .whitespaces
        )
        let parts = trimmed.split(separator: ":")
        guard parts.count == 3 else {
            throw IMSC1Error.invalidTimecode(timecode)
        }
        guard let hours = Double(parts[0]),
            let minutes = Double(parts[1])
        else {
            throw IMSC1Error.invalidTimecode(timecode)
        }
        let secondsPart = String(parts[2])
        let secondsComponents = secondsPart.split(
            separator: ".",
            maxSplits: 1
        )
        guard let wholeSeconds = Double(secondsComponents[0]) else {
            throw IMSC1Error.invalidTimecode(timecode)
        }
        var fractional = 0.0
        if secondsComponents.count == 2 {
            let fracStr = String(secondsComponents[1])
            guard let fracVal = Double("0.\(fracStr)") else {
                throw IMSC1Error.invalidTimecode(timecode)
            }
            fractional = fracVal
        }
        return hours * 3600.0 + minutes * 60.0
            + wholeSeconds + fractional
    }
}

// MARK: - XMLParser Delegate

/// Private SAX delegate for IMSC1 parsing.
///
/// Used only within the synchronous `parse()` scope so Sendable
/// conformance is not required.
private final class IMSC1ParserDelegate: NSObject, XMLParserDelegate {

    var language: String?
    var regions: [IMSC1Region] = []
    var styles: [IMSC1Style] = []
    var subtitles: [IMSC1Subtitle] = []
    var foundTTElement = false
    var parseError: IMSC1Error?

    private var elementStack: [String] = []
    private var currentText = ""
    private var currentBegin: Double?
    private var currentEnd: Double?
    private var currentRegion: String?
    private var currentStyle: String?

    // MARK: - XMLParserDelegate

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        let localName = stripPrefix(elementName)
        elementStack.append(localName)

        switch localName {
        case "tt":
            foundTTElement = true
            language = attributes["xml:lang"]

        case "region":
            parseRegion(attributes: attributes)

        case "style":
            if isInHead() {
                parseStyle(attributes: attributes)
            }

        case "p":
            currentText = ""
            parseSubtitleTiming(attributes: attributes)

        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let localName = stripPrefix(elementName)

        if localName == "p" {
            if let begin = currentBegin, let end = currentEnd {
                let subtitle = IMSC1Subtitle(
                    begin: begin,
                    end: end,
                    text: currentText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                    region: currentRegion,
                    style: currentStyle
                )
                subtitles.append(subtitle)
            }
            currentBegin = nil
            currentEnd = nil
            currentRegion = nil
            currentStyle = nil
            currentText = ""
        }

        if let last = elementStack.last, last == localName {
            elementStack.removeLast()
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        if let last = elementStack.last, last == "p" || last == "span" {
            currentText += string
        }
    }

    func parser(
        _ parser: XMLParser,
        parseErrorOccurred parseError: Error
    ) {
        self.parseError = IMSC1Error.invalidXML(
            parseError.localizedDescription
        )
    }

    // MARK: - Region Parsing

    private func parseRegion(attributes: [String: String]) {
        let id =
            attributes["xml:id"]
            ?? attributes["id"] ?? ""
        guard !id.isEmpty else { return }

        let origin = parsePercentagePair(
            attributes["tts:origin"]
        )
        let extent = parsePercentagePair(
            attributes["tts:extent"]
        )
        let region = IMSC1Region(
            id: id,
            originX: origin.0,
            originY: origin.1,
            extentWidth: extent.0,
            extentHeight: extent.1
        )
        regions.append(region)
    }

    // MARK: - Style Parsing

    private func parseStyle(attributes: [String: String]) {
        let id =
            attributes["xml:id"]
            ?? attributes["id"] ?? ""
        guard !id.isEmpty else { return }

        let style = IMSC1Style(
            id: id,
            fontFamily: attributes["tts:fontFamily"],
            fontSize: attributes["tts:fontSize"],
            color: attributes["tts:color"],
            backgroundColor: attributes["tts:backgroundColor"],
            textAlign: attributes["tts:textAlign"],
            fontStyle: attributes["tts:fontStyle"],
            fontWeight: attributes["tts:fontWeight"],
            textOutline: attributes["tts:textOutline"]
        )
        styles.append(style)
    }

    // MARK: - Subtitle Timing

    private func parseSubtitleTiming(
        attributes: [String: String]
    ) {
        if let beginStr = attributes["begin"] {
            do {
                currentBegin = try IMSC1Parser.parseTimecode(
                    beginStr
                )
            } catch {
                parseError = error as? IMSC1Error
            }
        }
        if let endStr = attributes["end"] {
            do {
                currentEnd = try IMSC1Parser.parseTimecode(
                    endStr
                )
            } catch {
                parseError = error as? IMSC1Error
            }
        }
        currentRegion = attributes["region"]
        currentStyle = attributes["style"]
    }

    // MARK: - Helpers

    private func stripPrefix(_ name: String) -> String {
        if let colonIndex = name.firstIndex(of: ":") {
            return String(name[name.index(after: colonIndex)...])
        }
        return name
    }

    private func isInHead() -> Bool {
        elementStack.contains("head")
    }

    private func parsePercentagePair(
        _ value: String?
    ) -> (Double, Double) {
        guard let value else { return (0.0, 0.0) }
        let components = value.split(separator: " ")
        guard components.count == 2 else { return (0.0, 0.0) }
        let first = parsePercentage(String(components[0]))
        let second = parsePercentage(String(components[1]))
        return (first, second)
    }

    private func parsePercentage(_ str: String) -> Double {
        let cleaned = str.replacingOccurrences(of: "%", with: "")
        return Double(cleaned) ?? 0.0
    }
}
