// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors thrown by ``LiveSegmenter`` implementations.
public enum LiveSegmenterError: Error, Sendable, Equatable {

    /// The segmenter has not been started or has already finished.
    case notActive

    /// No frames have been ingested (cannot force boundary
    /// or finish).
    case noFramesPending

    /// A frame has a non-monotonic timestamp (earlier than
    /// previous).
    case nonMonotonicTimestamp(String)

    /// The segment exceeded the maximum allowed duration.
    case maxDurationExceeded(String)

    /// A configuration error.
    case invalidConfiguration(String)
}
