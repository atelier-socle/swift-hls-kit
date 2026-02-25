// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Records all segments during a live stream for later VOD conversion.
///
/// Runs alongside the live pipeline with zero overhead on the live path.
/// Segments are written to storage as they arrive. When the stream ends,
/// the recording can be converted to a VOD playlist.
///
/// ```swift
/// let storage = FileRecordingStorage(basePath: "/recordings/stream-42")
/// let recorder = SimultaneousRecorder(storage: storage, configuration: .standard)
///
/// // During live stream — called for each segment:
/// try await recorder.recordSegment(
///     data: segmentData, filename: "seg0.ts", duration: 6.006
/// )
///
/// // When live ends:
/// let vodPlaylist = try await recorder.finalize()
/// ```
public actor SimultaneousRecorder {

    // MARK: - Types

    /// Recording configuration.
    public struct Configuration: Sendable, Equatable {

        /// Directory name for this recording.
        public var directory: String

        /// Playlist filename.
        public var playlistFilename: String

        /// Whether to write the playlist incrementally (after each segment).
        public var incrementalPlaylist: Bool

        /// Whether to include EXT-X-PROGRAM-DATE-TIME tags.
        public var includeProgramDateTime: Bool

        /// Whether to generate chapters automatically.
        public var autoChapters: Bool

        /// Maximum recording duration (nil = unlimited).
        public var maxDuration: TimeInterval?

        /// Creates a recording configuration.
        ///
        /// - Parameters:
        ///   - directory: Directory name for this recording.
        ///   - playlistFilename: Playlist filename.
        ///   - incrementalPlaylist: Write playlist after each segment.
        ///   - includeProgramDateTime: Include PROGRAM-DATE-TIME tags.
        ///   - autoChapters: Generate chapters automatically.
        ///   - maxDuration: Maximum recording duration.
        public init(
            directory: String = "recording",
            playlistFilename: String = "playlist.m3u8",
            incrementalPlaylist: Bool = true,
            includeProgramDateTime: Bool = false,
            autoChapters: Bool = false,
            maxDuration: TimeInterval? = nil
        ) {
            self.directory = directory
            self.playlistFilename = playlistFilename
            self.incrementalPlaylist = incrementalPlaylist
            self.includeProgramDateTime = includeProgramDateTime
            self.autoChapters = autoChapters
            self.maxDuration = maxDuration
        }

        /// Standard configuration.
        public static let standard = Configuration()

        /// Podcast recording (with chapters, unlimited duration).
        public static let podcast = Configuration(
            directory: "podcast",
            playlistFilename: "episode.m3u8",
            incrementalPlaylist: true,
            includeProgramDateTime: false,
            autoChapters: true
        )

        /// Event recording (with date-time, no auto-chapters).
        public static let event = Configuration(
            directory: "event",
            playlistFilename: "event.m3u8",
            incrementalPlaylist: true,
            includeProgramDateTime: true,
            autoChapters: false
        )
    }

    /// Recording state.
    public enum State: Sendable, Equatable {
        /// Ready to start recording.
        case idle
        /// Currently recording segments.
        case recording
        /// Building final playlist.
        case finalizing
        /// Recording completed successfully.
        case completed
        /// Recording failed with an error message.
        case failed(String)
    }

    /// Recording statistics.
    public struct Stats: Sendable, Equatable {

        /// Number of segments recorded.
        public var segmentCount: Int

        /// Total bytes written.
        public var totalBytes: Int

        /// Total duration of all segments.
        public var totalDuration: TimeInterval

        /// When recording started.
        public var startDate: Date?

        /// When recording ended.
        public var endDate: Date?

        /// Elapsed wall-clock time since start.
        public var elapsedTime: TimeInterval {
            guard let start = startDate else { return 0 }
            let end = endDate ?? Date()
            return end.timeIntervalSince(start)
        }

        /// Creates empty stats.
        public init() {
            self.segmentCount = 0
            self.totalBytes = 0
            self.totalDuration = 0
            self.startDate = nil
            self.endDate = nil
        }
    }

    /// Metadata for a single recorded segment.
    public struct RecordedSegment: Sendable, Equatable {

        /// Segment filename.
        public var filename: String

        /// Segment duration in seconds.
        public var duration: TimeInterval

        /// Whether this segment follows a discontinuity.
        public var isDiscontinuity: Bool

        /// Program date-time for this segment.
        public var programDateTime: Date?

        /// Segment byte size.
        public var byteSize: Int
    }

    /// Error thrown by recording operations.
    public enum RecorderError: Error, Sendable, Equatable {
        /// Attempted to record when not in recording state.
        case notRecording
        /// Maximum duration reached.
        case maxDurationReached
    }

    // MARK: - Properties

    /// Current recording state.
    public private(set) var state: State

    /// Recording statistics.
    public private(set) var stats: Stats

    /// Configuration.
    public let configuration: Configuration

    /// Recorded segment metadata in order.
    public private(set) var segmentMetadata: [RecordedSegment]

    /// All recorded segment filenames in order.
    public var recordedSegments: [String] {
        segmentMetadata.map(\.filename)
    }

    private let storage: RecordingStorage
    private var initSegmentFilename: String?

    // MARK: - Init

    /// Creates a simultaneous recorder.
    ///
    /// - Parameters:
    ///   - storage: Storage backend for writing segments and playlists.
    ///   - configuration: Recording configuration.
    public init(
        storage: RecordingStorage,
        configuration: Configuration = .standard
    ) {
        self.storage = storage
        self.configuration = configuration
        self.state = .idle
        self.stats = Stats()
        self.segmentMetadata = []
    }

    // MARK: - Recording Operations

    /// Start recording.
    ///
    /// Transitions from `.idle` to `.recording`.
    /// - Throws: `RecorderError.notRecording` if not in `.idle` state.
    public func start() throws {
        guard state == .idle else { throw RecorderError.notRecording }
        state = .recording
        stats.startDate = Date()
    }

    /// Record a segment.
    ///
    /// Called by the live pipeline for each new segment.
    /// - Parameters:
    ///   - data: Segment binary data.
    ///   - filename: Segment filename.
    ///   - duration: Segment duration in seconds.
    ///   - isDiscontinuity: Whether this segment follows a discontinuity.
    ///   - programDateTime: Optional program date-time for this segment.
    public func recordSegment(
        data: Data,
        filename: String,
        duration: TimeInterval,
        isDiscontinuity: Bool = false,
        programDateTime: Date? = nil
    ) async throws {
        guard state == .recording else { throw RecorderError.notRecording }
        if let maxDur = configuration.maxDuration,
            stats.totalDuration + duration > maxDur
        {
            throw RecorderError.maxDurationReached
        }
        try await storage.writeSegment(
            data: data,
            filename: filename,
            directory: configuration.directory
        )
        let segment = RecordedSegment(
            filename: filename,
            duration: duration,
            isDiscontinuity: isDiscontinuity,
            programDateTime: programDateTime,
            byteSize: data.count
        )
        segmentMetadata.append(segment)
        stats.segmentCount += 1
        stats.totalBytes += data.count
        stats.totalDuration += duration
        if configuration.incrementalPlaylist {
            let playlist = currentEventPlaylist
            try await storage.writePlaylist(
                content: playlist,
                filename: configuration.playlistFilename,
                directory: configuration.directory
            )
        }
    }

    /// Record an init segment (for fMP4).
    ///
    /// - Parameters:
    ///   - data: Init segment binary data.
    ///   - filename: Init segment filename.
    public func recordInitSegment(
        data: Data,
        filename: String
    ) async throws {
        guard state == .recording else { throw RecorderError.notRecording }
        try await storage.writeSegment(
            data: data,
            filename: filename,
            directory: configuration.directory
        )
        initSegmentFilename = filename
        stats.totalBytes += data.count
    }

    /// Finalize the recording.
    ///
    /// Writes the final playlist with EXT-X-ENDLIST.
    /// - Returns: The complete VOD playlist as M3U8 string.
    public func finalize() async throws -> String {
        guard state == .recording else { throw RecorderError.notRecording }
        state = .finalizing
        stats.endDate = Date()
        let playlist = buildFinalPlaylist()
        try await storage.writePlaylist(
            content: playlist,
            filename: configuration.playlistFilename,
            directory: configuration.directory
        )
        state = .completed
        return playlist
    }

    /// Cancel the recording.
    public func cancel() {
        state = .failed("Cancelled")
        stats.endDate = Date()
    }

    // MARK: - Playlist Access

    /// Get current event playlist (all segments so far, no ENDLIST).
    public var currentEventPlaylist: String {
        buildPlaylist(includeEndList: false)
    }

    // MARK: - Private

    private func buildFinalPlaylist() -> String {
        buildPlaylist(includeEndList: true)
    }

    private func buildPlaylist(includeEndList: Bool) -> String {
        var lines = [String]()
        lines.append("#EXTM3U")
        lines.append("#EXT-X-VERSION:7")
        let target = calculateTargetDuration()
        lines.append("#EXT-X-TARGETDURATION:\(target)")
        if includeEndList {
            lines.append("#EXT-X-PLAYLIST-TYPE:VOD")
        } else {
            lines.append("#EXT-X-PLAYLIST-TYPE:EVENT")
        }
        if let initFile = initSegmentFilename {
            lines.append("#EXT-X-MAP:URI=\"\(initFile)\"")
        }
        appendSegmentLines(to: &lines)
        if includeEndList {
            lines.append("#EXT-X-ENDLIST")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func appendSegmentLines(to lines: inout [String]) {
        let formatter = ISO8601DateFormatter()
        for segment in segmentMetadata {
            if segment.isDiscontinuity {
                lines.append("#EXT-X-DISCONTINUITY")
            }
            if configuration.includeProgramDateTime,
                let date = segment.programDateTime
            {
                lines.append(
                    "#EXT-X-PROGRAM-DATE-TIME:\(formatter.string(from: date))"
                )
            }
            lines.append("#EXTINF:\(formatDuration(segment.duration)),")
            lines.append(segment.filename)
        }
    }

    private func calculateTargetDuration() -> Int {
        guard let maxDur = segmentMetadata.map(\.duration).max() else {
            return 6
        }
        return Int(ceil(maxDur))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        String(format: "%.3f", duration)
    }
}
