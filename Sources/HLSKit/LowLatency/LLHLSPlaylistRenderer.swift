// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Renders LL-HLS specific tags for Low-Latency HLS playlists.
///
/// Produces `EXT-X-PART-INF`, `EXT-X-PART`, and `EXT-X-PRELOAD-HINT`
/// tags compliant with RFC 8216bis Section 4.4.4.9.
///
/// ## Tag ordering (per RFC 8216bis)
/// 1. `EXT-X-PART-INF` — before any `EXT-X-PART` tags
/// 2. `EXT-X-PART` for completed segments — before their `EXTINF`
/// 3. `EXT-X-PART` for the current incomplete segment — after the last
///    completed segment
/// 4. `EXT-X-PRELOAD-HINT` — after all `EXT-X-PART` tags
///
/// ## Duration precision
/// Partial durations use 5 decimal places (e.g., `0.33334`).
public struct LLHLSPlaylistRenderer: Sendable {

    /// Render `EXT-X-PART-INF` tag.
    ///
    /// - Parameter partTargetDuration: The target partial duration.
    /// - Returns: A formatted `EXT-X-PART-INF` line.
    public static func renderPartInf(
        partTargetDuration: TimeInterval
    ) -> String {
        let formatted = formatDuration(partTargetDuration)
        return "#EXT-X-PART-INF:PART-TARGET=\(formatted)"
    }

    /// Render a single `EXT-X-PART` line.
    ///
    /// - Parameter partial: The partial segment to render.
    /// - Returns: A formatted `EXT-X-PART` line.
    public static func renderPart(
        _ partial: LLPartialSegment
    ) -> String {
        var attrs = [String]()
        attrs.append(
            "DURATION=\(formatDuration(partial.duration))"
        )
        attrs.append("URI=\"\(partial.uri)\"")

        if partial.isIndependent {
            attrs.append("INDEPENDENT=YES")
        }

        if partial.isGap {
            attrs.append("GAP=YES")
        }

        if let range = partial.byteRange {
            var rangeStr = "\(range.length)"
            if let offset = range.offset {
                rangeStr += "@\(offset)"
            }
            attrs.append("BYTERANGE=\"\(rangeStr)\"")
        }

        return "#EXT-X-PART:\(attrs.joined(separator: ","))"
    }

    /// Render `EXT-X-PRELOAD-HINT` line.
    ///
    /// - Parameter hint: The preload hint to render.
    /// - Returns: A formatted `EXT-X-PRELOAD-HINT` line.
    public static func renderPreloadHint(
        _ hint: PreloadHint
    ) -> String {
        var attrs = [String]()
        attrs.append("TYPE=\(hint.type.rawValue)")
        attrs.append("URI=\"\(hint.uri)\"")

        if let start = hint.byteRangeStart {
            attrs.append("BYTERANGE-START=\(start)")
        }

        if let length = hint.byteRangeLength {
            attrs.append("BYTERANGE-LENGTH=\(length)")
        }

        return "#EXT-X-PRELOAD-HINT:\(attrs.joined(separator: ","))"
    }

    /// Render EXT-X-PART lines for a segment's partials.
    ///
    /// For completed segments, partials appear BEFORE the `EXTINF` line.
    /// For the current incomplete segment, partials appear alone (no
    /// `EXTINF`).
    ///
    /// - Parameters:
    ///   - segment: The completed segment, or `nil` if still in progress.
    ///   - partials: The partials for this segment.
    ///   - isCurrentSegment: Whether this is the current incomplete segment.
    /// - Returns: Rendered lines joined by newline.
    public static func renderSegmentWithPartials(
        segment: LiveSegment?,
        partials: [LLPartialSegment],
        isCurrentSegment: Bool
    ) -> String {
        var lines = [String]()

        for partial in partials {
            lines.append(renderPart(partial))
        }

        if let seg = segment, !isCurrentSegment {
            let duration = formatDuration(seg.duration)
            lines.append("#EXTINF:\(duration),")
            lines.append(seg.filename)
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Rendition Reports

    /// Render `EXT-X-RENDITION-REPORT` tags for alternate renditions.
    ///
    /// Called after all segments/parts in the playlist, before
    /// `EXT-X-ENDLIST` if present.
    ///
    /// - Parameter reports: Rendition reports for alternate playlists.
    /// - Returns: M3U8 lines for all rendition reports.
    public static func renderRenditionReports(
        _ reports: [RenditionReport]
    ) -> String {
        guard !reports.isEmpty else { return "" }
        let writer = TagWriter()
        return reports.map { writer.writeRenditionReport($0) }
            .joined(separator: "\n")
    }

    // MARK: - Server Control

    /// Render `EXT-X-SERVER-CONTROL` line.
    ///
    /// Delegates to ``ServerControlRenderer`` but provides a unified
    /// API on the playlist renderer.
    ///
    /// - Parameters:
    ///   - config: The server control configuration.
    ///   - targetDuration: The `EXT-X-TARGETDURATION` value.
    ///   - partTargetDuration: The `PART-TARGET` value.
    /// - Returns: A formatted `EXT-X-SERVER-CONTROL` line.
    public static func renderServerControl(
        config: ServerControlConfig,
        targetDuration: TimeInterval,
        partTargetDuration: TimeInterval
    ) -> String {
        ServerControlRenderer.render(
            config: config,
            targetDuration: targetDuration,
            partTargetDuration: partTargetDuration
        )
    }

    // MARK: - Private

    private static func formatDuration(
        _ duration: TimeInterval
    ) -> String {
        String(format: "%.5f", duration)
    }
}
