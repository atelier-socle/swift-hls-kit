// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Orchestrates the Low-Latency HLS pipeline.
///
/// Manages partial segments, generates preload hints, and renders
/// LL-HLS compliant playlists. Combines ``PartialSegmentManager``
/// for partial lifecycle with ``LLHLSPlaylistRenderer`` for tag
/// rendering.
///
/// ## Usage
/// ```swift
/// let manager = LLHLSManager(
///     configuration: .lowLatency
/// )
///
/// // Add partials as encoded chunks arrive
/// try await manager.addPartial(duration: 0.33, isIndependent: true)
/// try await manager.addPartial(duration: 0.33, isIndependent: false)
///
/// // Complete the segment when target duration is reached
/// _ = await manager.completeSegment(duration: 2.0, uri: "seg0.m4s")
///
/// // Render the playlist
/// let m3u8 = await manager.renderPlaylist()
/// ```
///
/// ## Events
/// Observe ``events`` for partial additions, segment completions,
/// preload hint updates, and stream end.
public actor LLHLSManager {

    /// Configuration for this LL-HLS session.
    public let configuration: LLHLSConfiguration

    // MARK: - Dependencies

    private let partialManager: PartialSegmentManager

    // MARK: - Segment Tracking

    private var completedSegments: [LiveSegment] = []
    private var completedSegmentPartials: [Int: [LLPartialSegment]] = [:]
    private var sequenceTracker = MediaSequenceTracker()
    private var metadata = LivePlaylistMetadata()
    private var hasEnded = false

    // MARK: - Event Stream

    private let eventContinuation: AsyncStream<LLHLSEvent>.Continuation

    /// Stream of LL-HLS lifecycle events.
    nonisolated public let events: AsyncStream<LLHLSEvent>

    /// Creates an LL-HLS manager.
    ///
    /// - Parameter configuration: The LL-HLS configuration.
    public init(configuration: LLHLSConfiguration = .lowLatency) {
        self.configuration = configuration

        self.partialManager = PartialSegmentManager(
            partTargetDuration: configuration.partTargetDuration,
            maxPartialsPerSegment: configuration.maxPartialsPerSegment,
            maxRetainedSegments: configuration.retainedPartialSegments,
            uriTemplate: configuration.partialURITemplate,
            fileExtension: configuration.fileExtension
        )

        let (stream, continuation) = AsyncStream.makeStream(
            of: LLHLSEvent.self
        )
        self.events = stream
        self.eventContinuation = continuation
    }

    deinit {
        eventContinuation.finish()
    }

    // MARK: - API

    /// Add a partial segment to the current segment being built.
    ///
    /// - Parameters:
    ///   - duration: Duration in seconds.
    ///   - uri: URI for the partial. Auto-generated from template
    ///     if `nil`.
    ///   - isIndependent: Whether it starts with an IDR frame.
    ///   - isGap: Whether this is a GAP partial.
    ///   - byteRange: Optional byte range.
    /// - Returns: The created partial segment.
    /// - Throws: ``LLHLSError`` on constraint violations.
    @discardableResult
    public func addPartial(
        duration: TimeInterval,
        uri: String? = nil,
        isIndependent: Bool,
        isGap: Bool = false,
        byteRange: ByteRange? = nil
    ) async throws -> LLPartialSegment {
        guard !hasEnded else {
            throw LLHLSError.streamAlreadyEnded
        }

        let partial = try await partialManager.addPartial(
            duration: duration,
            uri: uri,
            isIndependent: isIndependent,
            isGap: isGap,
            byteRange: byteRange
        )

        eventContinuation.yield(.partialAdded(partial))

        if let hint = await partialManager.currentPreloadHint() {
            eventContinuation.yield(.preloadHintUpdated(hint))
        }

        return partial
    }

    /// Complete the current segment.
    ///
    /// All pending partials become associated with the completed
    /// segment. A new segment begins.
    ///
    /// - Parameters:
    ///   - duration: Total segment duration in seconds.
    ///   - uri: URI (filename) for the completed segment.
    ///   - hasDiscontinuity: Whether to insert a discontinuity.
    ///   - programDateTime: Optional wall-clock time.
    /// - Returns: The completed ``LiveSegment``.
    @discardableResult
    public func completeSegment(
        duration: TimeInterval,
        uri: String,
        hasDiscontinuity: Bool = false,
        programDateTime: Date? = nil
    ) async -> LiveSegment {
        let partials = await partialManager.completeSegment()
        let index = completedSegments.count

        if hasDiscontinuity {
            sequenceTracker.discontinuityInserted()
        }

        let segment = LiveSegment(
            index: index,
            data: Data(),
            duration: duration,
            timestamp: MediaTimestamp(
                seconds: Double(index)
                    * configuration.segmentTargetDuration
            ),
            isIndependent: true,
            discontinuity: hasDiscontinuity,
            programDateTime: programDateTime,
            filename: uri,
            frameCount: 0,
            codecs: []
        )

        completedSegments.append(segment)
        completedSegmentPartials[index] = partials
        sequenceTracker.segmentAdded(index: index)

        eventContinuation.yield(
            .segmentCompleted(segment, partials: partials)
        )

        return segment
    }

    /// Render the full LL-HLS media playlist as an M3U8 string.
    ///
    /// Includes: header, `EXT-X-PART-INF`, completed segments with
    /// their retained partials, current segment's partials, and
    /// preload hint.
    ///
    /// - Returns: A complete M3U8 playlist string.
    public func renderPlaylist() async -> String {
        var lines = [String]()
        appendHeader(to: &lines)
        appendMetadata(to: &lines)

        let renderingPartials =
            await partialManager.partialsForRendering()
        appendSegments(to: &lines, partials: renderingPartials)
        appendCurrentPartials(to: &lines, partials: renderingPartials)
        await appendTrailer(to: &lines)

        return lines.joined(separator: "\n") + "\n"
    }

    /// End the stream.
    ///
    /// Adds `EXT-X-ENDLIST` to subsequent renders. No more partials
    /// or segments can be added after this.
    public func endStream() async {
        hasEnded = true
        await partialManager.end()
        eventContinuation.yield(.streamEnded)
        eventContinuation.finish()
    }

    /// Update playlist-level metadata.
    ///
    /// - Parameter metadata: The metadata to apply.
    public func updateMetadata(
        _ metadata: LivePlaylistMetadata
    ) {
        self.metadata = metadata
    }

    // MARK: - Observable State

    /// Number of completed segments.
    public var segmentCount: Int {
        completedSegments.count
    }

    /// Number of partials in the current incomplete segment.
    public var currentPartialCount: Int {
        get async { await partialManager.currentPartialCount }
    }

    /// Total number of partials across all retained segments.
    public var totalPartialCount: Int {
        get async { await partialManager.totalPartialCount }
    }

    /// Whether the stream has ended.
    public var isEnded: Bool {
        hasEnded
    }

    // MARK: - Render Helpers

    private func appendHeader(to lines: inout [String]) {
        lines.append("#EXTM3U")
        lines.append("#EXT-X-VERSION:\(configuration.version)")
        lines.append(
            "#EXT-X-TARGETDURATION:\(computeTargetDuration())"
        )
        lines.append(
            "#EXT-X-MEDIA-SEQUENCE:\(sequenceTracker.mediaSequence)"
        )
        if sequenceTracker.discontinuitySequence > 0 {
            lines.append(
                "#EXT-X-DISCONTINUITY-SEQUENCE:"
                    + "\(sequenceTracker.discontinuitySequence)"
            )
        }
        lines.append(
            LLHLSPlaylistRenderer.renderPartInf(
                partTargetDuration: configuration.partTargetDuration
            ))
    }

    private func appendMetadata(to lines: inout [String]) {
        if metadata.independentSegments {
            lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
        }
    }

    private func appendSegments(
        to lines: inout [String],
        partials: [(segmentIndex: Int, partials: [LLPartialSegment])]
    ) {
        for segment in completedSegments {
            if sequenceTracker.hasDiscontinuity(at: segment.index) {
                lines.append("#EXT-X-DISCONTINUITY")
            }
            if let date = segment.programDateTime {
                lines.append(
                    "#EXT-X-PROGRAM-DATE-TIME:" + formatISO8601(date)
                )
            }
            if let entry = partials.first(where: {
                $0.segmentIndex == segment.index
            }) {
                lines.append(
                    LLHLSPlaylistRenderer.renderSegmentWithPartials(
                        segment: segment,
                        partials: entry.partials,
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
        partials: [(segmentIndex: Int, partials: [LLPartialSegment])]
    ) {
        guard let current = partials.last,
            !completedSegments.contains(where: {
                $0.index == current.segmentIndex
            })
        else { return }

        lines.append(
            LLHLSPlaylistRenderer.renderSegmentWithPartials(
                segment: nil,
                partials: current.partials,
                isCurrentSegment: true
            ))
    }

    private func appendTrailer(to lines: inout [String]) async {
        if !hasEnded,
            let hint = await partialManager.currentPreloadHint()
        {
            lines.append(
                LLHLSPlaylistRenderer.renderPreloadHint(hint)
            )
        }
        if hasEnded {
            lines.append("#EXT-X-ENDLIST")
        }
    }

    // MARK: - Private

    private func computeTargetDuration() -> Int {
        if let max = completedSegments.map(\.duration).max() {
            return Int(ceil(max))
        }
        return Int(ceil(configuration.segmentTargetDuration))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatted = String(format: "%.5f", duration)
        var result = formatted
        while result.hasSuffix("0"), !result.hasSuffix(".0") {
            result = String(result.dropLast())
        }
        return result
    }

    private func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter.string(from: date)
    }
}

// MARK: - LLHLSConfiguration + Version

extension LLHLSConfiguration {

    /// HLS version for LL-HLS playlists (always 7+).
    var version: Int { 7 }
}
