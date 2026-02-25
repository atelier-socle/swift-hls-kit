// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Live playlist with time-based DVR (Digital Video Recorder) windowing.
///
/// Unlike ``SlidingWindowPlaylist`` which keeps a fixed count of segments,
/// this playlist keeps all segments within a configurable temporal window.
///
/// ## Use cases
/// - Sports broadcasts with 2-hour rewind
/// - News channels with 30-minute DVR
/// - Long-running events where the DVR window is measured in time,
///   not segments
///
/// ## Usage
/// ```swift
/// let playlist = DVRPlaylist(configuration: .init(
///     dvrWindowDuration: 7200, // 2 hours
///     targetDuration: 6.0
/// ))
/// for await segment in segmenter.segments {
///     try await playlist.addSegment(segment)
///     let m3u8 = await playlist.renderPlaylist()
/// }
/// let final = await playlist.endStream()
/// ```
public actor DVRPlaylist: LivePlaylistManager {

    /// Configuration for this playlist.
    public let configuration: DVRPlaylistConfiguration

    // MARK: - State

    private var dvrBuffer: DVRBuffer
    private var sequenceTracker = MediaSequenceTracker()
    private var metadata = LivePlaylistMetadata()
    private var hasEnded = false
    private let renderer = PlaylistRenderer()

    // MARK: - Event Stream

    private let eventContinuation: AsyncStream<LivePlaylistEvent>.Continuation

    /// Stream of playlist lifecycle events.
    nonisolated public let events: AsyncStream<LivePlaylistEvent>

    /// Creates a DVR playlist.
    ///
    /// - Parameter configuration: Playlist configuration.
    public init(
        configuration: DVRPlaylistConfiguration = .init()
    ) {
        self.configuration = configuration
        self.dvrBuffer = DVRBuffer(
            windowDuration: configuration.dvrWindowDuration
        )

        let (stream, continuation) = AsyncStream.makeStream(
            of: LivePlaylistEvent.self
        )
        self.events = stream
        self.eventContinuation = continuation
    }

    deinit {
        eventContinuation.finish()
    }

    // MARK: - LivePlaylistManager

    public func addSegment(
        _ segment: LiveSegment
    ) async throws {
        guard !hasEnded else {
            throw LivePlaylistError.streamEnded
        }

        dvrBuffer.append(segment)
        sequenceTracker.segmentAdded(index: segment.index)
        eventContinuation.yield(
            .segmentAdded(
                index: segment.index,
                duration: segment.duration
            )
        )

        // Evict expired segments
        let evicted = dvrBuffer.evictExpired()
        for seg in evicted {
            sequenceTracker.segmentEvicted(index: seg.index)
            eventContinuation.yield(
                .segmentRemoved(index: seg.index)
            )
        }

        eventContinuation.yield(
            .playlistUpdated(
                mediaSequence: sequenceTracker.mediaSequence
            )
        )
    }

    public func addPartialSegment(
        _ partial: LivePartialSegment,
        forSegment index: Int
    ) async throws {
        guard !hasEnded else {
            throw LivePlaylistError.streamEnded
        }
        guard dvrBuffer.segment(at: index) != nil else {
            throw LivePlaylistError.parentSegmentNotFound(index)
        }
    }

    public func insertDiscontinuity() async {
        sequenceTracker.discontinuityInserted()
    }

    public func updateMetadata(
        _ metadata: LivePlaylistMetadata
    ) async {
        self.metadata = metadata
    }

    public func renderPlaylist() async -> String {
        renderer.render(
            context: .init(
                segments: dvrBuffer.allSegments,
                sequenceTracker: sequenceTracker,
                metadata: metadata,
                targetDuration: computeTargetDuration(),
                playlistType: nil,
                hasEndList: false,
                version: configuration.version,
                initSegmentURI: configuration.initSegmentURI
            ))
    }

    /// Render a DVR playlist starting from a temporal offset.
    ///
    /// - Parameter offset: Seconds from the live edge
    ///   (negative = rewind).
    /// - Returns: M3U8 playlist starting from the offset.
    public func renderPlaylistFromOffset(
        _ offset: TimeInterval
    ) async -> String {
        let segments = dvrBuffer.segmentsFromOffset(offset)
        return renderer.render(
            context: .init(
                segments: segments,
                sequenceTracker: sequenceTracker,
                metadata: metadata,
                targetDuration: computeTargetDuration(),
                playlistType: nil,
                hasEndList: false,
                version: configuration.version,
                initSegmentURI: configuration.initSegmentURI
            ))
    }

    public func endStream() async -> String {
        hasEnded = true
        let m3u8 = renderer.render(
            context: .init(
                segments: dvrBuffer.allSegments,
                sequenceTracker: sequenceTracker,
                metadata: metadata,
                targetDuration: computeTargetDuration(),
                playlistType: nil,
                hasEndList: true,
                version: configuration.version,
                initSegmentURI: configuration.initSegmentURI
            ))
        eventContinuation.yield(.streamEnded)
        eventContinuation.finish()
        return m3u8
    }

    public var mediaSequence: Int {
        sequenceTracker.mediaSequence
    }

    public var discontinuitySequence: Int {
        sequenceTracker.discontinuitySequence
    }

    public var segmentCount: Int {
        dvrBuffer.count
    }

    // MARK: - DVR Accessors

    /// Total duration of buffered content.
    public var totalDuration: TimeInterval {
        dvrBuffer.totalDuration
    }

    /// Total data size of buffered content (bytes).
    public var totalDataSize: Int {
        dvrBuffer.totalDataSize
    }

    /// All segments in the DVR buffer.
    public var allSegments: [LiveSegment] {
        dvrBuffer.allSegments
    }

    // MARK: - Private

    private func computeTargetDuration() -> Int {
        if let maxDuration = dvrBuffer.allSegments.map(\.duration).max() {
            return Int(ceil(maxDuration))
        }
        return Int(ceil(configuration.targetDuration))
    }
}
