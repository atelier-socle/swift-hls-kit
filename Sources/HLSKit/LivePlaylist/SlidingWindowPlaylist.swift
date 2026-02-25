// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Live playlist with a sliding window of recent segments.
///
/// As new segments are added, old segments beyond the window size
/// are evicted. `EXT-X-MEDIA-SEQUENCE` increments with each eviction.
///
/// This produces a standard live HLS playlist WITHOUT
/// `EXT-X-PLAYLIST-TYPE` (the absence of this tag indicates a live,
/// sliding-window playlist).
///
/// ## Window behavior
/// The window size is defined by `windowSize` (number of segments
/// to keep). When a new segment is added and the playlist exceeds
/// `windowSize`, the oldest segment is evicted.
///
/// ## Target duration
/// `EXT-X-TARGETDURATION` is set to the ceiling of the maximum
/// segment duration currently in the playlist (per HLS spec
/// requirement).
///
/// ## Usage
/// ```swift
/// let playlist = SlidingWindowPlaylist(configuration: .init(
///     windowSize: 5,
///     targetDuration: 6.0
/// ))
/// for await segment in segmenter.segments {
///     try await playlist.addSegment(segment)
///     let m3u8 = await playlist.renderPlaylist()
///     // Serve m3u8 to clients...
/// }
/// let final = await playlist.endStream()
/// ```
public actor SlidingWindowPlaylist: LivePlaylistManager {

    /// Configuration for this playlist.
    public let configuration: SlidingWindowConfiguration

    // MARK: - State

    private var segments: [LiveSegment] = []
    private var sequenceTracker = MediaSequenceTracker()
    private var metadata = LivePlaylistMetadata()
    private var hasEnded = false
    private let renderer = PlaylistRenderer()

    // MARK: - Event Stream

    private let eventContinuation: AsyncStream<LivePlaylistEvent>.Continuation

    /// Stream of playlist lifecycle events.
    nonisolated public let events: AsyncStream<LivePlaylistEvent>

    /// Creates a sliding window playlist.
    ///
    /// - Parameter configuration: Playlist configuration.
    public init(
        configuration: SlidingWindowConfiguration = .init()
    ) {
        self.configuration = configuration

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

        segments.append(segment)
        sequenceTracker.segmentAdded(index: segment.index)
        eventContinuation.yield(
            .segmentAdded(
                index: segment.index,
                duration: segment.duration
            )
        )

        // Evict if over window size
        while segments.count > configuration.windowSize {
            let evicted = segments.removeFirst()
            sequenceTracker.segmentEvicted(index: evicted.index)
            eventContinuation.yield(
                .segmentRemoved(index: evicted.index)
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
        // Phase 11 (LL-HLS) will fully implement partial segments.
        // For now, validate the parent exists.
        guard segments.contains(where: { $0.index == index }) else {
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
                segments: segments,
                sequenceTracker: sequenceTracker,
                metadata: metadata,
                targetDuration: computeTargetDuration(),
                playlistType: nil,
                hasEndList: false,
                version: configuration.version
            ))
    }

    public func endStream() async -> String {
        hasEnded = true
        let m3u8 = renderer.render(
            context: .init(
                segments: segments,
                sequenceTracker: sequenceTracker,
                metadata: metadata,
                targetDuration: computeTargetDuration(),
                playlistType: nil,
                hasEndList: true,
                version: configuration.version
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
        segments.count
    }

    // MARK: - Extra Accessors

    /// All segments currently in the playlist window.
    public var currentSegments: [LiveSegment] {
        segments
    }

    /// The computed EXT-X-TARGETDURATION value.
    public var targetDuration: Int {
        computeTargetDuration()
    }

    // MARK: - Private

    /// Compute EXT-X-TARGETDURATION: ceiling of the maximum segment
    /// duration. Falls back to configuration target if no segments.
    private func computeTargetDuration() -> Int {
        if let maxDuration = segments.map(\.duration).max() {
            return Int(ceil(maxDuration))
        }
        return Int(ceil(configuration.targetDuration))
    }
}
