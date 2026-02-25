// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Retry policy for push operations with exponential backoff
/// and circuit breaker.
///
/// Controls how failed push operations are retried, including
/// delay computation, maximum attempts, and circuit breaker
/// thresholds.
public struct PushRetryPolicy: Sendable, Equatable {

    /// Maximum number of retry attempts per push operation.
    public var maxRetries: Int

    /// Base delay between retries in seconds.
    public var baseDelay: TimeInterval

    /// Backoff multiplier applied to delay after each retry.
    public var backoffMultiplier: Double

    /// Maximum delay cap in seconds.
    public var maxDelay: TimeInterval

    /// Timeout for each individual push request in seconds.
    public var requestTimeout: TimeInterval

    /// Consecutive failures before the circuit breaker opens.
    public var circuitBreakerThreshold: Int

    /// How long to wait before attempting to close the circuit
    /// breaker in seconds.
    public var circuitBreakerResetInterval: TimeInterval

    /// HTTP status codes that should trigger a retry.
    public var retryableStatusCodes: Set<Int>

    /// Creates a retry policy.
    ///
    /// - Parameters:
    ///   - maxRetries: Maximum retry attempts. Default `3`.
    ///   - baseDelay: Base delay in seconds. Default `1.0`.
    ///   - backoffMultiplier: Backoff factor. Default `2.0`.
    ///   - maxDelay: Maximum delay cap. Default `30.0`.
    ///   - requestTimeout: Per-request timeout. Default `30.0`.
    ///   - circuitBreakerThreshold: Failures to open. Default `5`.
    ///   - circuitBreakerResetInterval: Reset wait. Default `60.0`.
    ///   - retryableStatusCodes: Retryable HTTP codes.
    public init(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        maxDelay: TimeInterval = 30.0,
        requestTimeout: TimeInterval = 30.0,
        circuitBreakerThreshold: Int = 5,
        circuitBreakerResetInterval: TimeInterval = 60.0,
        retryableStatusCodes: Set<Int> = [429, 500, 502, 503, 504]
    ) {
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.backoffMultiplier = backoffMultiplier
        self.maxDelay = maxDelay
        self.requestTimeout = requestTimeout
        self.circuitBreakerThreshold = circuitBreakerThreshold
        self.circuitBreakerResetInterval = circuitBreakerResetInterval
        self.retryableStatusCodes = retryableStatusCodes
    }

    /// Compute delay for a given retry attempt (0-based).
    ///
    /// Returns `min(baseDelay * backoffMultiplier^attempt, maxDelay)`.
    ///
    /// - Parameter attempt: The retry attempt number (0-based).
    /// - Returns: Delay in seconds.
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let computed =
            baseDelay
            * pow(backoffMultiplier, Double(attempt))
        return min(computed, maxDelay)
    }

    // MARK: - Presets

    /// Default policy: 3 retries, 1s base, 2x backoff, 30s max.
    public static let `default` = PushRetryPolicy()

    /// Aggressive: 5 retries, 0.5s base, 1.5x backoff, 10s max.
    public static let aggressive = PushRetryPolicy(
        maxRetries: 5,
        baseDelay: 0.5,
        backoffMultiplier: 1.5,
        maxDelay: 10.0,
        requestTimeout: 15.0
    )

    /// Conservative: 2 retries, 2s base, 3x backoff, 60s max.
    public static let conservative = PushRetryPolicy(
        maxRetries: 2,
        baseDelay: 2.0,
        backoffMultiplier: 3.0,
        maxDelay: 60.0,
        requestTimeout: 60.0
    )

    /// No retry: fails immediately on first error.
    public static let noRetry = PushRetryPolicy(
        maxRetries: 0,
        baseDelay: 0,
        backoffMultiplier: 1.0,
        maxDelay: 0,
        requestTimeout: 30.0,
        circuitBreakerThreshold: Int.max,
        circuitBreakerResetInterval: 0
    )
}
