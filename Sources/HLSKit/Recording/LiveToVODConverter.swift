// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Converts recorded live/event stream segments into a clean VOD playlist.
///
/// Takes recorded segment metadata and produces a proper VOD playlist
/// with correct target duration, optional segment re-numbering,
/// and total duration calculation.
///
/// ```swift
/// let converter = LiveToVODConverter()
/// let vodPlaylist = converter.convert(
///     segments: recorder.segmentMetadata,
///     options: .init(renumberSegments: true, includeDateTime: false)
/// )
/// // → #EXTM3U
/// // → #EXT-X-VERSION:7
/// // → #EXT-X-TARGETDURATION:7
/// // → #EXT-X-PLAYLIST-TYPE:VOD
/// // → #EXTINF:6.006,
/// // → seg0.ts
/// // → ...
/// // → #EXT-X-ENDLIST
/// ```
public struct LiveToVODConverter: Sendable {

    // MARK: - Types

    /// Conversion options.
    public struct Options: Sendable, Equatable {

        /// Re-number segments from 0 (removes original sequence numbers).
        public var renumberSegments: Bool

        /// Include EXT-X-PROGRAM-DATE-TIME tags.
        public var includeDateTime: Bool

        /// Include EXT-X-DISCONTINUITY tags.
        public var preserveDiscontinuities: Bool

        /// Custom segment filename template (e.g., "episode42-{index}.ts").
        /// `{index}` is replaced with the segment index.
        public var filenameTemplate: String?

        /// Init segment filename (for fMP4). nil = no EXT-X-MAP.
        public var initSegmentFilename: String?

        /// HLS version to declare.
        public var version: Int

        /// Creates conversion options.
        ///
        /// - Parameters:
        ///   - renumberSegments: Re-number segments from 0.
        ///   - includeDateTime: Include PROGRAM-DATE-TIME tags.
        ///   - preserveDiscontinuities: Preserve discontinuity markers.
        ///   - filenameTemplate: Custom filename template.
        ///   - initSegmentFilename: Init segment filename for fMP4.
        ///   - version: HLS version to declare.
        public init(
            renumberSegments: Bool = false,
            includeDateTime: Bool = false,
            preserveDiscontinuities: Bool = true,
            filenameTemplate: String? = nil,
            initSegmentFilename: String? = nil,
            version: Int = 7
        ) {
            self.renumberSegments = renumberSegments
            self.includeDateTime = includeDateTime
            self.preserveDiscontinuities = preserveDiscontinuities
            self.filenameTemplate = filenameTemplate
            self.initSegmentFilename = initSegmentFilename
            self.version = version
        }

        /// Standard options.
        public static let standard = Options()

        /// Podcast VOD (clean, re-numbered, no date-time).
        public static let podcast = Options(
            renumberSegments: true,
            includeDateTime: false,
            preserveDiscontinuities: false
        )

        /// Archive (preserve everything, including discontinuities and date-time).
        public static let archive = Options(
            renumberSegments: false,
            includeDateTime: true,
            preserveDiscontinuities: true
        )
    }

    /// Creates a live-to-VOD converter.
    public init() {}

    // MARK: - Conversion

    /// Convert recorded segments to a VOD playlist.
    ///
    /// - Parameters:
    ///   - segments: Recorded segment metadata (from SimultaneousRecorder).
    ///   - options: Conversion options.
    /// - Returns: Complete M3U8 VOD playlist string.
    public func convert(
        segments: [SimultaneousRecorder.RecordedSegment],
        options: Options = .standard
    ) -> String {
        var lines = [String]()
        lines.append("#EXTM3U")
        lines.append("#EXT-X-VERSION:\(options.version)")
        let target = calculateTargetDuration(from: segments)
        lines.append("#EXT-X-TARGETDURATION:\(target)")
        lines.append("#EXT-X-PLAYLIST-TYPE:VOD")
        if let initFile = options.initSegmentFilename {
            lines.append("#EXT-X-MAP:URI=\"\(initFile)\"")
        }
        appendSegmentLines(
            segments: segments,
            options: options,
            to: &lines
        )
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Calculate the target duration (max segment duration, rounded up).
    ///
    /// - Parameter segments: Recorded segments.
    /// - Returns: Target duration as an integer (ceiling of max duration).
    public func calculateTargetDuration(
        from segments: [SimultaneousRecorder.RecordedSegment]
    ) -> Int {
        guard let maxDur = segments.map(\.duration).max() else { return 6 }
        return Int(ceil(maxDur))
    }

    /// Calculate total stream duration.
    ///
    /// - Parameter segments: Recorded segments.
    /// - Returns: Sum of all segment durations.
    public func calculateTotalDuration(
        from segments: [SimultaneousRecorder.RecordedSegment]
    ) -> TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Private

    private func appendSegmentLines(
        segments: [SimultaneousRecorder.RecordedSegment],
        options: Options,
        to lines: inout [String]
    ) {
        let formatter = ISO8601DateFormatter()
        for (index, segment) in segments.enumerated() {
            if segment.isDiscontinuity && options.preserveDiscontinuities {
                lines.append("#EXT-X-DISCONTINUITY")
            }
            if options.includeDateTime, let date = segment.programDateTime {
                lines.append(
                    "#EXT-X-PROGRAM-DATE-TIME:\(formatter.string(from: date))"
                )
            }
            lines.append(
                "#EXTINF:\(String(format: "%.3f", segment.duration)),"
            )
            let filename = resolveFilename(
                segment: segment, index: index, options: options
            )
            lines.append(filename)
        }
    }

    private func resolveFilename(
        segment: SimultaneousRecorder.RecordedSegment,
        index: Int,
        options: Options
    ) -> String {
        if let template = options.filenameTemplate {
            return template.replacingOccurrences(
                of: "{index}", with: String(index)
            )
        }
        if options.renumberSegments {
            let ext = fileExtension(from: segment.filename)
            return "seg\(index).\(ext)"
        }
        return segment.filename
    }

    private func fileExtension(from filename: String) -> String {
        let parts = filename.split(separator: ".")
        guard parts.count > 1, let ext = parts.last else { return "ts" }
        return String(ext)
    }
}
