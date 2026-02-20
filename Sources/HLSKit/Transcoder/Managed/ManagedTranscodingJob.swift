// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Represents an in-progress or completed cloud transcoding job.
///
/// Tracks the lifecycle of a remote transcoding operation from
/// creation through completion or failure.
///
/// - SeeAlso: ``ManagedTranscoder``, ``ManagedTranscodingProvider``
public struct ManagedTranscodingJob: Sendable, Hashable {

    /// Provider-specific job identifier.
    public let jobID: String

    /// Provider-specific asset identifier.
    public let assetID: String

    /// Current job status.
    public var status: Status

    /// Transcoding progress (0.0 to 1.0), if available from provider.
    public var progress: Double?

    /// Provider-specific output URLs (populated when complete).
    public var outputURLs: [URL]

    /// Error message if failed.
    public var errorMessage: String?

    /// When the job was created.
    public let createdAt: Date

    /// When the job completed (or failed).
    public var completedAt: Date?

    /// Job status.
    public enum Status: String, Sendable, Hashable, Codable {

        /// Job is waiting to be processed.
        case queued

        /// Job is being processed.
        case processing

        /// Job completed successfully.
        case completed

        /// Job failed.
        case failed

        /// Job was cancelled.
        case cancelled
    }

    /// Creates a managed transcoding job.
    ///
    /// - Parameters:
    ///   - jobID: Provider-specific job identifier.
    ///   - assetID: Provider-specific asset identifier.
    ///   - status: Initial job status.
    ///   - progress: Initial progress value.
    ///   - outputURLs: Output URLs (usually empty initially).
    ///   - errorMessage: Error message if failed.
    ///   - createdAt: Job creation timestamp.
    ///   - completedAt: Completion timestamp.
    public init(
        jobID: String,
        assetID: String,
        status: Status = .queued,
        progress: Double? = nil,
        outputURLs: [URL] = [],
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.jobID = jobID
        self.assetID = assetID
        self.status = status
        self.progress = progress
        self.outputURLs = outputURLs
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    /// Whether the job is in a terminal state.
    public var isTerminal: Bool {
        status == .completed || status == .failed
            || status == .cancelled
    }
}
