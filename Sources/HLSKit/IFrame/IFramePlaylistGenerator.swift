// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates `EXT-X-I-FRAMES-ONLY` playlists for trick play (scrubbing, fast-forward).
///
/// An I-Frame playlist contains only the keyframes from a media stream,
/// referenced via byte-range within existing segments. This enables fast
/// seeking and thumbnail scrubbing without downloading full segments.
///
/// ```swift
/// var generator = IFramePlaylistGenerator()
/// generator.addKeyframe(
///     segmentURI: "seg0.ts",
///     byteOffset: 0,
///     byteLength: 18432,
///     duration: 6.006
/// )
/// let playlist = generator.generate()
/// // → #EXTM3U
/// // → #EXT-X-VERSION:7
/// // → #EXT-X-TARGETDURATION:7
/// // → #EXT-X-I-FRAMES-ONLY
/// // → #EXTINF:6.006,
/// // → #EXT-X-BYTERANGE:18432@0
/// // → seg0.ts
/// // → #EXT-X-ENDLIST
/// ```
public struct IFramePlaylistGenerator: Sendable {

    // MARK: - Types

    /// A keyframe reference within a segment.
    public struct KeyframeReference: Sendable, Equatable {

        /// URI of the segment containing this keyframe.
        public var segmentURI: String

        /// Byte offset within the segment.
        public var byteOffset: Int

        /// Length in bytes of the keyframe data.
        public var byteLength: Int

        /// Duration this keyframe represents (time until next keyframe).
        public var duration: TimeInterval

        /// Optional program date-time for this keyframe.
        public var programDateTime: Date?

        /// Whether this keyframe is at a discontinuity boundary.
        public var isDiscontinuity: Bool

        /// Creates a keyframe reference.
        public init(
            segmentURI: String,
            byteOffset: Int,
            byteLength: Int,
            duration: TimeInterval,
            programDateTime: Date? = nil,
            isDiscontinuity: Bool = false
        ) {
            self.segmentURI = segmentURI
            self.byteOffset = byteOffset
            self.byteLength = byteLength
            self.duration = duration
            self.programDateTime = programDateTime
            self.isDiscontinuity = isDiscontinuity
        }
    }

    /// Configuration for I-Frame playlist generation.
    public struct Configuration: Sendable, Equatable {

        /// HLS version to declare.
        public var version: Int

        /// Whether to include EXT-X-PROGRAM-DATE-TIME.
        public var includeDateTime: Bool

        /// Init segment URI for fMP4 (nil = TS segments).
        public var initSegmentURI: String?

        /// Creates a configuration.
        public init(
            version: Int = 7,
            includeDateTime: Bool = false,
            initSegmentURI: String? = nil
        ) {
            self.version = version
            self.includeDateTime = includeDateTime
            self.initSegmentURI = initSegmentURI
        }

        /// Standard configuration.
        public static let standard = Configuration()

        /// fMP4 configuration (with init segment).
        public static let fmp4 = Configuration(initSegmentURI: "init.mp4")
    }

    // MARK: - Properties

    /// Accumulated keyframe references.
    public private(set) var keyframes: [KeyframeReference]

    /// Configuration.
    public var configuration: Configuration

    /// Creates an I-Frame playlist generator.
    ///
    /// - Parameter configuration: Generation configuration.
    public init(configuration: Configuration = .standard) {
        self.keyframes = []
        self.configuration = configuration
    }

    // MARK: - Building

    /// Add a keyframe reference.
    ///
    /// - Parameters:
    ///   - segmentURI: URI of the segment containing this keyframe.
    ///   - byteOffset: Byte offset within the segment.
    ///   - byteLength: Length in bytes of the keyframe data.
    ///   - duration: Duration this keyframe represents.
    ///   - programDateTime: Optional program date-time.
    ///   - isDiscontinuity: Whether this is at a discontinuity boundary.
    public mutating func addKeyframe(
        segmentURI: String,
        byteOffset: Int,
        byteLength: Int,
        duration: TimeInterval,
        programDateTime: Date? = nil,
        isDiscontinuity: Bool = false
    ) {
        let ref = KeyframeReference(
            segmentURI: segmentURI,
            byteOffset: byteOffset,
            byteLength: byteLength,
            duration: duration,
            programDateTime: programDateTime,
            isDiscontinuity: isDiscontinuity
        )
        keyframes.append(ref)
    }

    /// Add keyframes from recorded segments (integration with SimultaneousRecorder).
    ///
    /// Generates synthetic byte ranges based on segment sizes and keyframe ratio.
    /// - Parameters:
    ///   - segments: Recorded segment metadata.
    ///   - keyframeRatio: Ratio of keyframe size to total segment size (default 0.1).
    public mutating func addFromRecordedSegments(
        _ segments: [SimultaneousRecorder.RecordedSegment],
        keyframeRatio: Double = 0.1
    ) {
        for segment in segments {
            let kfSize = max(1, Int(Double(segment.byteSize) * keyframeRatio))
            addKeyframe(
                segmentURI: segment.filename,
                byteOffset: 0,
                byteLength: kfSize,
                duration: segment.duration,
                programDateTime: segment.programDateTime,
                isDiscontinuity: segment.isDiscontinuity
            )
        }
    }

    // MARK: - Generation

    /// Generate the `EXT-X-I-FRAMES-ONLY` playlist.
    ///
    /// - Returns: Complete M3U8 I-Frames-Only playlist string.
    public func generate() -> String {
        var lines = [String]()
        lines.append("#EXTM3U")
        lines.append("#EXT-X-VERSION:\(configuration.version)")
        lines.append("#EXT-X-TARGETDURATION:\(calculateTargetDuration())")
        lines.append("#EXT-X-I-FRAMES-ONLY")
        if let initURI = configuration.initSegmentURI {
            lines.append("#EXT-X-MAP:URI=\"\(initURI)\"")
        }
        appendKeyframeLines(to: &lines)
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n") + "\n"
    }

    /// Calculate target duration from keyframes.
    ///
    /// - Returns: Ceiling of the maximum keyframe duration.
    public func calculateTargetDuration() -> Int {
        guard let maxDur = keyframes.map(\.duration).max() else { return 6 }
        return Int(ceil(maxDur))
    }

    /// Number of keyframes.
    public var keyframeCount: Int { keyframes.count }

    /// Total byte size of all keyframes.
    public var totalByteSize: Int {
        keyframes.reduce(0) { $0 + $1.byteLength }
    }

    /// Reset all keyframes.
    public mutating func reset() {
        keyframes = []
    }

    // MARK: - Private

    private func appendKeyframeLines(to lines: inout [String]) {
        let formatter = ISO8601DateFormatter()
        for kf in keyframes {
            if kf.isDiscontinuity {
                lines.append("#EXT-X-DISCONTINUITY")
            }
            if configuration.includeDateTime, let date = kf.programDateTime {
                lines.append(
                    "#EXT-X-PROGRAM-DATE-TIME:\(formatter.string(from: date))"
                )
            }
            lines.append(
                "#EXTINF:\(String(format: "%.3f", kf.duration)),"
            )
            lines.append(
                "#EXT-X-BYTERANGE:\(kf.byteLength)@\(kf.byteOffset)"
            )
            lines.append(kf.segmentURI)
        }
    }
}
