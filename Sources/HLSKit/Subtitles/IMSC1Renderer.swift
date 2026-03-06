// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Renders an ``IMSC1Document`` to IMSC1 Text Profile TTML XML.
///
/// Produces valid TTML with all required IMSC1 namespaces
/// and profile declarations.
///
/// ```swift
/// let document = IMSC1Document(
///     language: "en",
///     subtitles: [IMSC1Subtitle(begin: 0, end: 2, text: "Hi")]
/// )
/// let xml = IMSC1Renderer.render(document)
/// ```
public struct IMSC1Renderer: Sendable {

    /// Renders an IMSC1 document as TTML XML.
    ///
    /// - Parameter document: The document to render.
    /// - Returns: A valid IMSC1 Text Profile TTML XML string.
    public static func render(_ document: IMSC1Document) -> String {
        var lines: [String] = []
        lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
        lines.append(ttOpenTag(language: document.language))

        // Head section (regions, styles)
        if !document.regions.isEmpty || !document.styles.isEmpty {
            lines.append("  <head>")
            if !document.styles.isEmpty {
                lines.append("    <styling>")
                for style in document.styles {
                    lines.append(renderStyle(style))
                }
                lines.append("    </styling>")
            }
            if !document.regions.isEmpty {
                lines.append("    <layout>")
                for region in document.regions {
                    lines.append(renderRegion(region))
                }
                lines.append("    </layout>")
            }
            lines.append("  </head>")
        }

        // Body section
        lines.append("  <body>")
        lines.append("    <div>")
        for subtitle in document.subtitles {
            lines.append(renderSubtitle(subtitle))
        }
        lines.append("    </div>")
        lines.append("  </body>")
        lines.append("</tt>")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Private Helpers

extension IMSC1Renderer {

    private static func ttOpenTag(language: String) -> String {
        var attrs: [String] = []
        attrs.append("xmlns=\"http://www.w3.org/ns/ttml\"")
        attrs.append(
            "xmlns:ttp=\"http://www.w3.org/ns/ttml#parameter\""
        )
        attrs.append(
            "xmlns:tts=\"http://www.w3.org/ns/ttml#styling\""
        )
        attrs.append(
            "ttp:profile="
                + "\"http://www.w3.org/ns/ttml/profile/imsc1/text\""
        )
        attrs.append("xml:lang=\"\(language)\"")
        return "<tt \(attrs.joined(separator: " "))>"
    }

    private static func renderStyle(
        _ style: IMSC1Style
    ) -> String {
        var attrs = "xml:id=\"\(style.id)\""
        if let v = style.fontFamily {
            attrs += " tts:fontFamily=\"\(v)\""
        }
        if let v = style.fontSize {
            attrs += " tts:fontSize=\"\(v)\""
        }
        if let v = style.color {
            attrs += " tts:color=\"\(v)\""
        }
        if let v = style.backgroundColor {
            attrs += " tts:backgroundColor=\"\(v)\""
        }
        if let v = style.textAlign {
            attrs += " tts:textAlign=\"\(v)\""
        }
        if let v = style.fontStyle {
            attrs += " tts:fontStyle=\"\(v)\""
        }
        if let v = style.fontWeight {
            attrs += " tts:fontWeight=\"\(v)\""
        }
        if let v = style.textOutline {
            attrs += " tts:textOutline=\"\(v)\""
        }
        return "      <style \(attrs)/>"
    }

    private static func renderRegion(
        _ region: IMSC1Region
    ) -> String {
        let origin =
            formatPercent(region.originX)
            + " " + formatPercent(region.originY)
        let extent =
            formatPercent(region.extentWidth)
            + " " + formatPercent(region.extentHeight)
        return "      <region xml:id=\"\(region.id)\""
            + " tts:origin=\"\(origin)\""
            + " tts:extent=\"\(extent)\"/>"
    }

    private static func renderSubtitle(
        _ subtitle: IMSC1Subtitle
    ) -> String {
        let begin = formatTimecode(subtitle.begin)
        let end = formatTimecode(subtitle.end)
        var attrs = "begin=\"\(begin)\" end=\"\(end)\""
        if let region = subtitle.region {
            attrs += " region=\"\(region)\""
        }
        if let style = subtitle.style {
            attrs += " style=\"\(style)\""
        }
        return "      <p \(attrs)>\(escapeXML(subtitle.text))</p>"
    }

    /// Formats seconds as TTML timecode `HH:MM:SS.mmm`.
    static func formatTimecode(_ seconds: Double) -> String {
        let totalMillis = Int((seconds * 1000).rounded())
        let hours = totalMillis / 3_600_000
        let minutes = (totalMillis % 3_600_000) / 60_000
        let secs = (totalMillis % 60_000) / 1_000
        let millis = totalMillis % 1_000
        return String(
            format: "%02d:%02d:%02d.%03d",
            hours, minutes, secs, millis
        )
    }

    private static func formatPercent(_ value: Double) -> String {
        if value == value.rounded() && value >= 0
            && value <= 100
        {
            return "\(Int(value))%"
        }
        return String(format: "%.2f%%", value)
    }

    private static func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
