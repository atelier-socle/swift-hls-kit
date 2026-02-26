// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - LivePipelineState

/// Represents the lifecycle state of a LivePipeline.
///
/// State transitions:
/// ```
/// idle → starting → running ──→ stopping → stopped
///              │                     │
///              └─────→ failed ←──────┘
/// ```
public enum LivePipelineState: Sendable {
    /// Pipeline is idle and ready to start.
    case idle
    /// Pipeline is initializing components.
    case starting
    /// Pipeline is actively streaming.
    case running(since: Date)
    /// Pipeline is shutting down gracefully.
    case stopping
    /// Pipeline stopped normally with a summary.
    case stopped(summary: LivePipelineSummary)
    /// Pipeline failed with an error.
    case failed(LivePipelineError)
}

extension LivePipelineState: Equatable {
    public static func == (lhs: LivePipelineState, rhs: LivePipelineState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            true
        case (.starting, .starting):
            true
        case (.running, .running):
            true
        case (.stopping, .stopping):
            true
        case let (.stopped(lhsSummary), .stopped(rhsSummary)):
            lhsSummary == rhsSummary
        case let (.failed(lhsError), .failed(rhsError)):
            lhsError == rhsError
        default:
            false
        }
    }
}

// MARK: - LivePipelineSummary

/// Summary produced when a pipeline stops normally.
public struct LivePipelineSummary: Sendable, Equatable {
    /// Total stream duration in seconds.
    public let duration: TimeInterval
    /// Total segments produced during the session.
    public let segmentsProduced: Int
    /// Total bytes generated across all segments.
    public let totalBytes: Int64
    /// Date when the pipeline started.
    public let startDate: Date
    /// Date when the pipeline stopped.
    public let stopDate: Date
    /// Reason for stopping.
    public let reason: StopReason

    /// Reason why the pipeline stopped.
    public enum StopReason: String, Sendable, Equatable {
        /// User explicitly requested stop.
        case userRequested
        /// Source stream ended naturally.
        case sourceEnded
        /// An error caused the stop.
        case error
    }

    /// Creates a new pipeline summary.
    public init(
        duration: TimeInterval,
        segmentsProduced: Int,
        totalBytes: Int64,
        startDate: Date,
        stopDate: Date,
        reason: StopReason
    ) {
        self.duration = duration
        self.segmentsProduced = segmentsProduced
        self.totalBytes = totalBytes
        self.startDate = startDate
        self.stopDate = stopDate
        self.reason = reason
    }
}

// MARK: - LivePipelineError

/// Errors specific to the LivePipeline.
public enum LivePipelineError: Error, Sendable, Equatable {
    /// Pipeline is not currently running.
    case notRunning
    /// Pipeline is already running.
    case alreadyRunning
    /// Configuration is invalid.
    case invalidConfiguration(String)
    /// Encoding stage failed.
    case encodingFailed(String)
    /// Segmentation stage failed.
    case segmentationFailed(String)
    /// Push delivery failed.
    case pushFailed(String)
    /// Source stream error.
    case sourceError(String)
    /// A required component group is not configured.
    case componentNotConfigured(String)
}

// MARK: - LivePipelineEvent

/// Events emitted by the LivePipeline during operation.
public enum LivePipelineEvent: Sendable {
    /// Pipeline state changed.
    case stateChanged(LivePipelineState)
    /// A new segment was produced.
    case segmentProduced(index: Int, duration: TimeInterval, byteSize: Int)
    /// A segment was successfully pushed to a destination.
    case pushCompleted(destination: String, segmentIndex: Int, latency: TimeInterval)
    /// A push to a destination failed.
    case pushFailed(destination: String, error: String)
    /// A push to a destination succeeded.
    case pushSucceeded(destination: String, bytesSent: Int)
    /// Metadata was inserted into the stream.
    case metadataInserted(type: String)
    /// Timed metadata was injected via components.
    case metadataInjected
    /// An HLS Interstitial was scheduled.
    case interstitialScheduled(String)
    /// A SCTE-35 splice point was inserted.
    case scte35Inserted
    /// A discontinuity marker was inserted.
    case discontinuityInserted
    /// A recording segment was saved to disk.
    case recordingSegmentSaved(filename: String)
    /// Recording was finalized into a VOD playlist.
    case recordingFinalized
    /// Silence was detected in the audio stream.
    case silenceDetected(duration: TimeInterval)
    /// Loudness measurement update.
    case loudnessUpdate(lufs: Double)
    /// A non-fatal warning occurred.
    case warning(String)
    /// A component configuration warning (non-fatal).
    case componentWarning(String)
}

// MARK: - LivePipelineStateTransition

/// Validates state transitions for the LivePipeline state machine.
public struct LivePipelineStateTransition: Sendable {

    /// Checks if a transition from `current` to `next` is valid.
    ///
    /// Valid transitions:
    /// - idle → starting
    /// - starting → running
    /// - starting → failed
    /// - running → stopping
    /// - running → failed
    /// - stopping → stopped
    /// - stopping → failed
    ///
    /// - Parameters:
    ///   - current: The current pipeline state.
    ///   - next: The desired next state.
    /// - Returns: `true` if the transition is valid.
    public static func isValid(
        from current: LivePipelineState,
        to next: LivePipelineState
    ) -> Bool {
        switch (current, next) {
        case (.idle, .starting):
            true
        case (.starting, .running):
            true
        case (.starting, .failed):
            true
        case (.running, .stopping):
            true
        case (.running, .failed):
            true
        case (.stopping, .stopped):
            true
        case (.stopping, .failed):
            true
        default:
            false
        }
    }

    /// All valid transitions as (from, to) string pairs.
    public static var validTransitions: [(from: String, to: String)] {
        [
            (from: "idle", to: "starting"),
            (from: "starting", to: "running"),
            (from: "starting", to: "failed"),
            (from: "running", to: "stopping"),
            (from: "running", to: "failed"),
            (from: "stopping", to: "stopped"),
            (from: "stopping", to: "failed")
        ]
    }
}
