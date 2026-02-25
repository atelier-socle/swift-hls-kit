// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Event playlist that retains all segments since the stream began.
///
/// Renders `EXT-X-PLAYLIST-TYPE:EVENT` in the M3U8 output.
/// No segments are ever evicted — the playlist grows continuously.
/// When the stream ends (``endStream()``), `EXT-X-ENDLIST` is added,
/// effectively converting the playlist to a VOD asset.
///
/// ## Use cases
/// - Live events where rewind-to-start is needed
/// - Recording a live stream for later on-demand playback
/// - Streams that convert from live to VOD when complete
///
/// ## Usage
/// ```swift
/// let playlist = EventPlaylist(
///     configuration: .init(targetDuration: 6.0)
/// )
/// for await segment in segmenter.segments {
///     try await playlist.addSegment(segment)
///     let m3u8 = await playlist.renderPlaylist()
///     // Serve m3u8 to clients...
/// }
/// let vod = await playlist.endStream() // Now a VOD playlist
/// ```
public actor EventPlaylist: LivePlaylistManager {

    /// Configuration for this playlist.
    public let configuration: EventPlaylistConfiguration

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

    /// Creates an event playlist.
    ///
    /// - Parameter configuration: Playlist configuration.
    public init(
        configuration: EventPlaylistConfiguration = .init()
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
                playlistType: .event,
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
                playlistType: .event,
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

    /// All segments since stream start.
    public var allSegments: [LiveSegment] {
        segments
    }

    /// Total duration of all segments.
    public var totalDuration: TimeInterval {
        segments.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Private

    private func computeTargetDuration() -> Int {
        if let maxDuration = segments.map(\.duration).max() {
            return Int(ceil(maxDuration))
        }
        return Int(ceil(configuration.targetDuration))
    }
}
