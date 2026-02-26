// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Policy for rotating encryption keys during live streaming.
///
/// Key rotation enhances security by limiting the window of exposure
/// if a key is compromised. Different policies trade off security
/// against key server load.
///
/// ```swift
/// let policy = KeyRotationPolicy.everyNSegments(10)
/// print(policy.shouldRotate(segmentIndex: 10, elapsed: 60))  // true
/// ```
public enum KeyRotationPolicy: Sendable, Equatable {

    /// Rotate the key for every segment (maximum security, highest key server load).
    case everySegment

    /// Rotate every N seconds of stream time.
    case interval(TimeInterval)

    /// Rotate every N segments.
    case everyNSegments(Int)

    /// No automatic rotation — app calls `forceRotation()` manually.
    case manual

    /// No rotation — same key for the entire stream.
    case none

    // MARK: - Decision

    /// Determine if a key rotation should occur.
    ///
    /// - Parameters:
    ///   - segmentIndex: Current segment index (0-based).
    ///   - elapsed: Time elapsed since last rotation in seconds.
    ///   - lastRotationSegment: Segment index of last rotation.
    /// - Returns: Whether to rotate the key now.
    public func shouldRotate(
        segmentIndex: Int,
        elapsed: TimeInterval,
        lastRotationSegment: Int = 0
    ) -> Bool {
        switch self {
        case .everySegment:
            return segmentIndex > lastRotationSegment
        case .interval(let seconds):
            return elapsed >= seconds
        case .everyNSegments(let count):
            let segmentsSinceLast = segmentIndex - lastRotationSegment
            return segmentsSinceLast >= count
        case .manual:
            return false
        case .none:
            return false
        }
    }

    // MARK: - Description

    /// Human-readable description of the policy.
    public var policyDescription: String {
        switch self {
        case .everySegment:
            return "Rotate every segment"
        case .interval(let seconds):
            return "Rotate every \(Int(seconds)) seconds"
        case .everyNSegments(let count):
            return "Rotate every \(count) segments"
        case .manual:
            return "Manual rotation"
        case .none:
            return "No rotation"
        }
    }
}
