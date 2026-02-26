// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - LivePipelineStatistics

/// Runtime statistics for a running LivePipeline.
///
/// Provides monitoring data for segments, push delivery,
/// audio quality, and pipeline health.
///
/// Usage:
/// ```swift
/// let stats = await pipeline.statistics
/// print("Uptime: \(stats.uptime)s, segments: \(stats.segmentsProduced)")
/// print("Bytes sent: \(stats.totalBytes), push errors: \(stats.pushErrors)")
/// ```
public struct LivePipelineStatistics: Sendable, Equatable {

    // MARK: - Timing

    /// Pipeline uptime in seconds since start.
    public var uptime: TimeInterval

    /// Date when pipeline started.
    public var startDate: Date?

    // MARK: - Segments

    /// Total segments produced.
    public var segmentsProduced: Int

    /// Average segment duration in seconds.
    public var averageSegmentDuration: TimeInterval

    /// Last segment duration in seconds.
    public var lastSegmentDuration: TimeInterval

    /// Last segment byte size.
    public var lastSegmentBytes: Int

    // MARK: - Data

    /// Total bytes produced across all segments.
    public var totalBytes: Int64

    /// Estimated output bitrate in bits per second.
    public var estimatedBitrate: Int

    // MARK: - Push

    /// Total bytes sent to push destinations.
    public var bytesSent: Int64

    /// Number of push errors since start.
    public var pushErrors: Int

    /// Number of currently active push destinations.
    public var activeDestinations: Int

    // MARK: - Audio Quality

    /// Last measured audio peak level in dBFS. Nil if no audio processed.
    public var audioPeakDB: Float?

    /// Last measured loudness in LUFS. Nil if no loudness measurement.
    public var loudnessLUFS: Float?

    // MARK: - LL-HLS

    /// Total partial segments produced (LL-HLS only).
    public var partialsProduced: Int

    // MARK: - Recording

    /// Whether recording is active.
    public var recordingActive: Bool

    /// Recorded segments count.
    public var recordedSegments: Int

    // MARK: - Health

    /// Number of discontinuities inserted.
    public var discontinuities: Int

    /// Dropped segments (failed to process).
    public var droppedSegments: Int

    // MARK: - Init

    /// Creates empty statistics with all zeros/nils.
    public init() {
        self.uptime = 0
        self.startDate = nil
        self.segmentsProduced = 0
        self.averageSegmentDuration = 0
        self.lastSegmentDuration = 0
        self.lastSegmentBytes = 0
        self.totalBytes = 0
        self.estimatedBitrate = 0
        self.bytesSent = 0
        self.pushErrors = 0
        self.activeDestinations = 0
        self.audioPeakDB = nil
        self.loudnessLUFS = nil
        self.partialsProduced = 0
        self.recordingActive = false
        self.recordedSegments = 0
        self.discontinuities = 0
        self.droppedSegments = 0
    }

    // MARK: - Computed

    /// Average bytes per segment. Returns 0 if no segments produced.
    public var averageBytesPerSegment: Int {
        guard segmentsProduced > 0 else { return 0 }
        return Int(totalBytes / Int64(segmentsProduced))
    }

    /// Whether any push errors have occurred.
    public var hasPushErrors: Bool {
        pushErrors > 0
    }
}
