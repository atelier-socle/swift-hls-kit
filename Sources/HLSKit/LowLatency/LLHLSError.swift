// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors emitted by the Low-Latency HLS pipeline.
///
/// These errors cover violations of LL-HLS spec constraints
/// (RFC 8216bis) such as independence requirements for the first
/// partial of a segment, duration limits, and stream lifecycle.
public enum LLHLSError: Error, Sendable, Equatable,
    CustomStringConvertible
{

    /// The stream has already ended; no more partials or segments
    /// can be added.
    case streamAlreadyEnded

    /// The first partial of a segment must have `isIndependent = true`.
    ///
    /// RFC 8216bis Section 4.4.4.9 requires the first partial of each
    /// segment to start with an independent frame (IDR/keyframe).
    case firstPartialMustBeIndependent

    /// A partial segment's duration exceeded 1.5x the target duration.
    ///
    /// While not fatal, this violates the LL-HLS spec recommendation.
    case partialDurationExceedsTarget(
        actual: TimeInterval, target: TimeInterval
    )

    /// The configuration is invalid.
    case invalidConfiguration(String)

    /// No segment is currently in progress; cannot complete.
    case segmentNotInProgress

    public var description: String {
        switch self {
        case .streamAlreadyEnded:
            "Stream has already ended"
        case .firstPartialMustBeIndependent:
            "First partial of segment must be independent (IDR)"
        case .partialDurationExceedsTarget(let actual, let target):
            "Partial duration \(actual)s exceeds 1.5× target "
                + "\(target)s"
        case .invalidConfiguration(let reason):
            "Invalid LL-HLS configuration: \(reason)"
        case .segmentNotInProgress:
            "No segment is currently in progress"
        }
    }
}
