// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PushRetryPolicy", .timeLimit(.minutes(1)))
struct PushRetryPolicyTests {

    @Test("delay for attempt 0 equals baseDelay")
    func delayAttemptZero() {
        let policy = PushRetryPolicy(
            baseDelay: 1.0, backoffMultiplier: 2.0
        )
        #expect(policy.delay(forAttempt: 0) == 1.0)
    }

    @Test("delay grows exponentially")
    func exponentialGrowth() {
        let policy = PushRetryPolicy(
            baseDelay: 1.0, backoffMultiplier: 2.0,
            maxDelay: 100.0
        )
        #expect(policy.delay(forAttempt: 0) == 1.0)
        #expect(policy.delay(forAttempt: 1) == 2.0)
        #expect(policy.delay(forAttempt: 2) == 4.0)
        #expect(policy.delay(forAttempt: 3) == 8.0)
    }

    @Test("delay capped at maxDelay")
    func delayCapped() {
        let policy = PushRetryPolicy(
            baseDelay: 1.0, backoffMultiplier: 10.0,
            maxDelay: 5.0
        )
        #expect(policy.delay(forAttempt: 0) == 1.0)
        #expect(policy.delay(forAttempt: 1) == 5.0)
        #expect(policy.delay(forAttempt: 5) == 5.0)
    }

    @Test("default preset values")
    func defaultPreset() {
        let policy = PushRetryPolicy.default
        #expect(policy.maxRetries == 3)
        #expect(policy.baseDelay == 1.0)
        #expect(policy.backoffMultiplier == 2.0)
        #expect(policy.maxDelay == 30.0)
    }

    @Test("aggressive preset values")
    func aggressivePreset() {
        let policy = PushRetryPolicy.aggressive
        #expect(policy.maxRetries == 5)
        #expect(policy.baseDelay == 0.5)
        #expect(policy.backoffMultiplier == 1.5)
        #expect(policy.maxDelay == 10.0)
    }

    @Test("conservative preset values")
    func conservativePreset() {
        let policy = PushRetryPolicy.conservative
        #expect(policy.maxRetries == 2)
        #expect(policy.baseDelay == 2.0)
        #expect(policy.backoffMultiplier == 3.0)
        #expect(policy.maxDelay == 60.0)
    }

    @Test("noRetry has maxRetries = 0")
    func noRetryPreset() {
        let policy = PushRetryPolicy.noRetry
        #expect(policy.maxRetries == 0)
    }

    @Test("Retryable status codes include standard codes")
    func retryableStatusCodes() {
        let policy = PushRetryPolicy.default
        #expect(policy.retryableStatusCodes.contains(429))
        #expect(policy.retryableStatusCodes.contains(500))
        #expect(policy.retryableStatusCodes.contains(502))
        #expect(policy.retryableStatusCodes.contains(503))
        #expect(policy.retryableStatusCodes.contains(504))
        #expect(!policy.retryableStatusCodes.contains(400))
        #expect(!policy.retryableStatusCodes.contains(404))
    }

    @Test("Custom policy creation")
    func customPolicy() {
        let policy = PushRetryPolicy(
            maxRetries: 10,
            baseDelay: 0.1,
            backoffMultiplier: 1.5,
            maxDelay: 5.0,
            requestTimeout: 10.0,
            circuitBreakerThreshold: 3,
            circuitBreakerResetInterval: 30.0,
            retryableStatusCodes: [500]
        )
        #expect(policy.maxRetries == 10)
        #expect(policy.circuitBreakerThreshold == 3)
        #expect(policy.retryableStatusCodes == [500])
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(PushRetryPolicy.default == PushRetryPolicy.default)
        #expect(
            PushRetryPolicy.default != PushRetryPolicy.aggressive
        )
    }
}
