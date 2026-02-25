// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Renders live HLS playlists from segment state.
///
/// Produces compliant M3U8 media playlists with proper tag ordering
/// as defined by RFC 8216. Works with ``LiveSegment`` objects from
/// the live pipeline rather than the VOD ``Segment`` type.
///
/// ## Tag ordering (per spec)
/// 1. `#EXTM3U`
/// 2. `#EXT-X-VERSION:<n>`
/// 3. `#EXT-X-TARGETDURATION:<n>`
/// 4. `#EXT-X-MEDIA-SEQUENCE:<n>`
/// 5. `#EXT-X-DISCONTINUITY-SEQUENCE:<n>` (if > 0)
/// 6. `#EXT-X-PLAYLIST-TYPE:EVENT` (event playlists only)
/// 7. `#EXT-X-INDEPENDENT-SEGMENTS` (if metadata.independentSegments)
/// 8. `#EXT-X-START:TIME-OFFSET=<n>` (if metadata.startOffset set)
/// 9. Custom tags from metadata
/// 10. Segment entries (DISCONTINUITY, PROGRAM-DATE-TIME, EXTINF, URI)
/// 11. `#EXT-X-ENDLIST` (when stream ends)
struct PlaylistRenderer: Sendable {

    /// Playlist type for the `EXT-X-PLAYLIST-TYPE` tag.
    enum PlaylistType: Sendable {
        /// EXT-X-PLAYLIST-TYPE:EVENT
        case event
        /// EXT-X-PLAYLIST-TYPE:VOD (used when event → VOD)
        case vod
    }

    /// Grouped input for rendering a playlist.
    struct RenderContext: Sendable {
        let segments: [LiveSegment]
        let sequenceTracker: MediaSequenceTracker
        let metadata: LivePlaylistMetadata
        let targetDuration: Int
        let playlistType: PlaylistType?
        let hasEndList: Bool
        let version: Int
        let initSegmentURI: String?

        init(
            segments: [LiveSegment],
            sequenceTracker: MediaSequenceTracker,
            metadata: LivePlaylistMetadata,
            targetDuration: Int,
            playlistType: PlaylistType?,
            hasEndList: Bool,
            version: Int,
            initSegmentURI: String? = nil
        ) {
            self.segments = segments
            self.sequenceTracker = sequenceTracker
            self.metadata = metadata
            self.targetDuration = targetDuration
            self.playlistType = playlistType
            self.hasEndList = hasEndList
            self.version = version
            self.initSegmentURI = initSegmentURI
        }
    }

    /// Render a complete M3U8 playlist from the given context.
    ///
    /// - Parameter context: All state required to render.
    /// - Returns: A complete M3U8 playlist string.
    func render(context ctx: RenderContext) -> String {
        var lines: [String] = []

        appendHeader(to: &lines, context: ctx)
        appendMetadata(to: &lines, metadata: ctx.metadata)

        if let uri = ctx.initSegmentURI {
            lines.append("#EXT-X-MAP:URI=\"\(uri)\"")
        }

        appendSegments(
            to: &lines,
            segments: ctx.segments,
            tracker: ctx.sequenceTracker
        )

        if ctx.hasEndList {
            lines.append("#EXT-X-ENDLIST")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Rendering sections

    private func appendHeader(
        to lines: inout [String],
        context ctx: RenderContext
    ) {
        lines.append("#EXTM3U")
        lines.append("#EXT-X-VERSION:\(ctx.version)")
        lines.append("#EXT-X-TARGETDURATION:\(ctx.targetDuration)")
        lines.append(
            "#EXT-X-MEDIA-SEQUENCE:"
                + "\(ctx.sequenceTracker.mediaSequence)"
        )

        if ctx.sequenceTracker.discontinuitySequence > 0 {
            lines.append(
                "#EXT-X-DISCONTINUITY-SEQUENCE:"
                    + "\(ctx.sequenceTracker.discontinuitySequence)"
            )
        }

        if let type = ctx.playlistType {
            switch type {
            case .event:
                lines.append("#EXT-X-PLAYLIST-TYPE:EVENT")
            case .vod:
                lines.append("#EXT-X-PLAYLIST-TYPE:VOD")
            }
        }
    }

    private func appendMetadata(
        to lines: inout [String],
        metadata: LivePlaylistMetadata
    ) {
        if metadata.independentSegments {
            lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
        }

        if let offset = metadata.startOffset {
            var tag =
                "#EXT-X-START:TIME-OFFSET="
                + formatDuration(offset)
            if metadata.startPrecise {
                tag += ",PRECISE=YES"
            }
            lines.append(tag)
        }

        for customTag in metadata.customTags {
            lines.append(customTag)
        }
    }

    private func appendSegments(
        to lines: inout [String],
        segments: [LiveSegment],
        tracker: MediaSequenceTracker
    ) {
        for segment in segments {
            if tracker.hasDiscontinuity(at: segment.index) {
                lines.append("#EXT-X-DISCONTINUITY")
            }
            if segment.isGap {
                lines.append("#EXT-X-GAP")
            }
            if let date = segment.programDateTime {
                lines.append(
                    "#EXT-X-PROGRAM-DATE-TIME:"
                        + formatISO8601(date)
                )
            }
            lines.append(
                "#EXTINF:\(formatDuration(segment.duration)),"
            )
            lines.append(segment.filename)
        }
    }

    // MARK: - Formatting

    /// Format a duration matching TagWriter's formatDecimal behavior.
    ///
    /// Outputs up to 3 decimal places with trailing zeros trimmed,
    /// keeping at least one decimal place (e.g., "6.006", "6.0").
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatted = String(format: "%.3f", duration)
        var result = formatted
        while result.hasSuffix("0"), !result.hasSuffix(".0") {
            result = String(result.dropLast())
        }
        return result
    }

    /// Format a Date as ISO 8601 for EXT-X-PROGRAM-DATE-TIME.
    func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter.string(from: date)
    }
}
