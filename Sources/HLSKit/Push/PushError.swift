// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors that can occur during push operations.
///
/// Covers HTTP errors, connection failures, timeouts, retry
/// exhaustion, circuit breaker activation, and configuration issues.
public enum PushError: Error, Sendable, CustomStringConvertible {

    /// HTTP error response.
    case httpError(statusCode: Int, message: String?)

    /// Connection failed.
    case connectionFailed(underlying: String)

    /// Request timed out.
    case timeout(TimeInterval)

    /// All retries exhausted.
    case retriesExhausted(attempts: Int, lastError: String)

    /// Circuit breaker is open (too many consecutive failures).
    case circuitBreakerOpen(failures: Int)

    /// Push operation was cancelled.
    case cancelled

    /// Invalid configuration.
    case invalidConfiguration(String)

    /// The pusher is not connected.
    case notConnected

    public var description: String {
        switch self {
        case .httpError(let code, let message):
            "HTTP error \(code)"
                + (message.map { ": \($0)" } ?? "")
        case .connectionFailed(let underlying):
            "Connection failed: \(underlying)"
        case .timeout(let duration):
            "Push timed out after \(duration)s"
        case .retriesExhausted(let attempts, let lastError):
            "All \(attempts) retries exhausted, last error: "
                + lastError
        case .circuitBreakerOpen(let failures):
            "Circuit breaker open after \(failures) "
                + "consecutive failures"
        case .cancelled:
            "Push operation cancelled"
        case .invalidConfiguration(let reason):
            "Invalid push configuration: \(reason)"
        case .notConnected:
            "Pusher is not connected"
        }
    }
}
