// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Statistics for push operations.
///
/// Tracks bytes pushed, success/failure counts, latency, estimated
/// bandwidth, and circuit breaker state. Updated after each push
/// attempt.
public struct PushStats: Sendable, Equatable {

    /// Total bytes pushed since start.
    public var totalBytesPushed: Int64

    /// Total number of successful push operations.
    public var successCount: Int

    /// Total number of failed push operations.
    public var failureCount: Int

    /// Average push latency in seconds.
    public var averageLatency: TimeInterval

    /// Last push latency in seconds.
    public var lastLatency: TimeInterval

    /// Current estimated upload bandwidth in bytes/second.
    public var estimatedBandwidth: Double

    /// Timestamp of last successful push.
    public var lastSuccessTime: Date?

    /// Timestamp of last failure.
    public var lastFailureTime: Date?

    /// Number of retries performed.
    public var retryCount: Int

    /// Whether the circuit breaker is currently open.
    public var circuitBreakerOpen: Bool

    /// A stats instance with all values at zero.
    public static let zero = PushStats(
        totalBytesPushed: 0,
        successCount: 0,
        failureCount: 0,
        averageLatency: 0,
        lastLatency: 0,
        estimatedBandwidth: 0,
        lastSuccessTime: nil,
        lastFailureTime: nil,
        retryCount: 0,
        circuitBreakerOpen: false
    )

    /// Update stats with a successful push.
    ///
    /// - Parameters:
    ///   - bytes: Number of bytes pushed.
    ///   - latency: Time taken for the push in seconds.
    public mutating func recordSuccess(
        bytes: Int64, latency: TimeInterval
    ) {
        totalBytesPushed += bytes
        successCount += 1
        lastLatency = latency
        lastSuccessTime = Date()

        // Running average latency.
        let total = averageLatency * Double(successCount - 1)
        averageLatency = (total + latency) / Double(successCount)

        // Estimate bandwidth from last push.
        if latency > 0 {
            estimatedBandwidth = Double(bytes) / latency
        }
    }

    /// Update stats with a failed push.
    public mutating func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
    }
}
