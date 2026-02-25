// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates delta update playlists for LL-HLS.
///
/// When a client sends `_HLS_skip=YES`, the server responds with a
/// playlist that replaces old segments with
/// `EXT-X-SKIP:SKIPPED-SEGMENTS=N`, dramatically reducing playlist
/// transfer size from O(total_segments) to O(recent_segments).
///
/// ## Spec reference
/// RFC 8216bis §4.4.5.2 — `EXT-X-SKIP`
public struct DeltaUpdateGenerator: Sendable {

    /// The skip boundary: segments older than this duration from the
    /// live edge can be replaced with `EXT-X-SKIP`.
    public let canSkipUntil: TimeInterval

    /// Whether to also skip `EXT-X-DATERANGE` tags (`_HLS_skip=v2`).
    public let canSkipDateRanges: Bool

    /// Creates a delta update generator.
    ///
    /// - Parameters:
    ///   - canSkipUntil: Maximum skippable duration in seconds.
    ///   - canSkipDateRanges: Support date-range skipping.
    ///     Default `false`.
    public init(
        canSkipUntil: TimeInterval,
        canSkipDateRanges: Bool = false
    ) {
        self.canSkipUntil = canSkipUntil
        self.canSkipDateRanges = canSkipDateRanges
    }

    // MARK: - Skip Calculation

    /// Determines how many segments can be skipped in a delta update.
    ///
    /// Segments whose cumulative duration from the start exceeds the
    /// skip window (`totalPlaylistDuration - canSkipUntil`) are
    /// skippable.
    ///
    /// - Parameters:
    ///   - segments: All segments in the playlist (oldest first).
    ///   - targetDuration: The `EXT-X-TARGETDURATION` value.
    /// - Returns: The number of segments that can be skipped
    ///   (from the start).
    public func skippableSegmentCount(
        segments: [LiveSegment],
        targetDuration: TimeInterval
    ) -> Int {
        guard !segments.isEmpty else { return 0 }

        let totalDuration = segments.reduce(0.0) { $0 + $1.duration }
        let skipBoundary = totalDuration - canSkipUntil

        guard skipBoundary > 0 else { return 0 }

        var cumulative = 0.0
        var count = 0

        for segment in segments {
            cumulative += segment.duration
            if cumulative <= skipBoundary {
                count += 1
            } else {
                break
            }
        }

        return count
    }

    // MARK: - Tag Rendering

    /// Generate the `EXT-X-SKIP` tag.
    ///
    /// - Parameters:
    ///   - skippedCount: Number of segments being skipped.
    ///   - recentlyRemovedDateRanges: IDs of recently removed
    ///     date ranges (for `_HLS_skip=v2`).
    /// - Returns: A formatted `EXT-X-SKIP` line.
    public func renderSkipTag(
        skippedCount: Int,
        recentlyRemovedDateRanges: [String]? = nil
    ) -> String {
        var attrs = "SKIPPED-SEGMENTS=\(skippedCount)"

        if let dateRanges = recentlyRemovedDateRanges,
            !dateRanges.isEmpty
        {
            let joined = dateRanges.joined(separator: "\t")
            attrs += ",RECENTLY-REMOVED-DATERANGES=\"\(joined)\""
        }

        return "#EXT-X-SKIP:\(attrs)"
    }

    // MARK: - Delta Playlist Generation

    /// Context for delta playlist generation.
    public struct DeltaContext: Sendable {
        /// All segments (oldest first).
        public let segments: [LiveSegment]
        /// Partial segments grouped by segment index.
        public let partials: [Int: [LLPartialSegment]]
        /// Partials for the incomplete current segment.
        public let currentPartials: [LLPartialSegment]
        /// Current preload hint.
        public let preloadHint: PreloadHint?
        /// Server control configuration.
        public let serverControl: ServerControlConfig
        /// LL-HLS configuration.
        public let configuration: LLHLSConfiguration
        /// Current media sequence number.
        public let mediaSequence: Int
        /// Current discontinuity sequence.
        public let discontinuitySequence: Int
        /// Whether the client requested v2 skip.
        public let skipDateRanges: Bool
        /// IDs of removed date ranges.
        public let recentlyRemovedDateRanges: [String]?

        /// Creates a delta context.
        public init(
            segments: [LiveSegment],
            partials: [Int: [LLPartialSegment]],
            currentPartials: [LLPartialSegment],
            preloadHint: PreloadHint?,
            serverControl: ServerControlConfig,
            configuration: LLHLSConfiguration,
            mediaSequence: Int,
            discontinuitySequence: Int,
            skipDateRanges: Bool = false,
            recentlyRemovedDateRanges: [String]? = nil
        ) {
            self.segments = segments
            self.partials = partials
            self.currentPartials = currentPartials
            self.preloadHint = preloadHint
            self.serverControl = serverControl
            self.configuration = configuration
            self.mediaSequence = mediaSequence
            self.discontinuitySequence = discontinuitySequence
            self.skipDateRanges = skipDateRanges
            self.recentlyRemovedDateRanges = recentlyRemovedDateRanges
        }
    }

    /// Generate a complete delta update playlist from context.
    ///
    /// Replaces old segments with an `EXT-X-SKIP` tag and renders
    /// only recent segments with their partials.
    ///
    /// - Parameter context: The delta generation context.
    /// - Returns: Complete delta update M3U8 string.
    public func generateDeltaPlaylist(
        context: DeltaContext
    ) -> String {
        let targetDuration = computeTargetDuration(
            segments: context.segments,
            defaultDuration: context.configuration.segmentTargetDuration
        )

        var lines = [String]()
        appendHeader(
            to: &lines, context: context,
            targetDuration: targetDuration
        )

        let skipCount = skippableSegmentCount(
            segments: context.segments,
            targetDuration: TimeInterval(targetDuration)
        )

        if skipCount > 0 {
            let dateRanges =
                context.skipDateRanges
                ? context.recentlyRemovedDateRanges : nil
            lines.append(
                renderSkipTag(
                    skippedCount: skipCount,
                    recentlyRemovedDateRanges: dateRanges
                ))
        }

        appendNonSkippedSegments(
            to: &lines,
            segments: context.segments,
            partials: context.partials,
            skipCount: skipCount
        )

        appendCurrentPartials(
            to: &lines,
            currentPartials: context.currentPartials,
            segments: context.segments
        )

        if let hint = context.preloadHint {
            lines.append(
                LLHLSPlaylistRenderer.renderPreloadHint(hint)
            )
        }

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Private Helpers

    private func appendHeader(
        to lines: inout [String],
        context: DeltaContext,
        targetDuration: Int
    ) {
        let config = context.configuration
        lines.append("#EXTM3U")
        lines.append("#EXT-X-VERSION:\(config.version)")
        lines.append("#EXT-X-TARGETDURATION:\(targetDuration)")
        lines.append(
            "#EXT-X-MEDIA-SEQUENCE:\(context.mediaSequence)"
        )

        if context.discontinuitySequence > 0 {
            lines.append(
                "#EXT-X-DISCONTINUITY-SEQUENCE:"
                    + "\(context.discontinuitySequence)"
            )
        }

        lines.append(
            LLHLSPlaylistRenderer.renderPartInf(
                partTargetDuration: config.partTargetDuration
            ))
        lines.append(
            LLHLSPlaylistRenderer.renderServerControl(
                config: context.serverControl,
                targetDuration: config.segmentTargetDuration,
                partTargetDuration: config.partTargetDuration
            ))
    }

    private func appendNonSkippedSegments(
        to lines: inout [String],
        segments: [LiveSegment],
        partials: [Int: [LLPartialSegment]],
        skipCount: Int
    ) {
        for segment in segments.dropFirst(skipCount) {
            if segment.discontinuity {
                lines.append("#EXT-X-DISCONTINUITY")
            }

            if let segPartials = partials[segment.index] {
                lines.append(
                    LLHLSPlaylistRenderer.renderSegmentWithPartials(
                        segment: segment,
                        partials: segPartials,
                        isCurrentSegment: false
                    ))
            } else {
                lines.append(
                    "#EXTINF:\(formatDuration(segment.duration)),"
                )
                lines.append(segment.filename)
            }
        }
    }

    private func appendCurrentPartials(
        to lines: inout [String],
        currentPartials: [LLPartialSegment],
        segments: [LiveSegment]
    ) {
        guard !currentPartials.isEmpty else { return }

        let isCompleted =
            currentPartials.first.map { partial in
                segments.contains { $0.index == partial.segmentIndex }
            } ?? false

        guard !isCompleted else { return }

        lines.append(
            LLHLSPlaylistRenderer.renderSegmentWithPartials(
                segment: nil,
                partials: currentPartials,
                isCurrentSegment: true
            ))
    }

    private func computeTargetDuration(
        segments: [LiveSegment],
        defaultDuration: TimeInterval
    ) -> Int {
        let maxDur = segments.map(\.duration).max()
        return Int(ceil(maxDur ?? defaultDuration))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        var result = String(format: "%.5f", duration)
        while result.hasSuffix("0"), !result.hasSuffix(".0") {
            result = String(result.dropLast())
        }
        return result
    }
}
