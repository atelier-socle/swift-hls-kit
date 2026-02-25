// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PushStats", .timeLimit(.minutes(1)))
struct PushStatsTests {

    @Test("zero has all zeros")
    func zero() {
        let stats = PushStats.zero
        #expect(stats.totalBytesPushed == 0)
        #expect(stats.successCount == 0)
        #expect(stats.failureCount == 0)
        #expect(stats.averageLatency == 0)
        #expect(stats.lastLatency == 0)
        #expect(stats.estimatedBandwidth == 0)
        #expect(stats.lastSuccessTime == nil)
        #expect(stats.lastFailureTime == nil)
        #expect(stats.retryCount == 0)
        #expect(!stats.circuitBreakerOpen)
    }

    @Test("recordSuccess updates bytes, count, latency, bandwidth")
    func recordSuccess() {
        var stats = PushStats.zero
        stats.recordSuccess(bytes: 1024, latency: 0.5)

        #expect(stats.totalBytesPushed == 1024)
        #expect(stats.successCount == 1)
        #expect(stats.lastLatency == 0.5)
        #expect(stats.averageLatency == 0.5)
        #expect(stats.estimatedBandwidth == 2048.0)
        #expect(stats.lastSuccessTime != nil)
    }

    @Test("recordSuccess computes running average latency")
    func runningAverageLatency() {
        var stats = PushStats.zero
        stats.recordSuccess(bytes: 100, latency: 1.0)
        stats.recordSuccess(bytes: 100, latency: 3.0)

        #expect(stats.averageLatency == 2.0)
        #expect(stats.successCount == 2)
    }

    @Test("recordFailure increments count and sets time")
    func recordFailure() {
        var stats = PushStats.zero
        stats.recordFailure()

        #expect(stats.failureCount == 1)
        #expect(stats.lastFailureTime != nil)
    }

    @Test("Multiple successes update bandwidth")
    func multipleBandwidth() {
        var stats = PushStats.zero
        stats.recordSuccess(bytes: 1000, latency: 1.0)
        #expect(stats.estimatedBandwidth == 1000.0)

        stats.recordSuccess(bytes: 2000, latency: 0.5)
        #expect(stats.estimatedBandwidth == 4000.0)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = PushStats.zero
        let b = PushStats.zero
        #expect(a == b)
    }

    @Test("Stats after mixed success/failure sequence")
    func mixedSequence() {
        var stats = PushStats.zero
        stats.recordSuccess(bytes: 500, latency: 0.2)
        stats.recordFailure()
        stats.recordSuccess(bytes: 1000, latency: 0.3)
        stats.recordFailure()

        #expect(stats.successCount == 2)
        #expect(stats.failureCount == 2)
        #expect(stats.totalBytesPushed == 1500)
    }

    @Test("Zero latency does not update bandwidth")
    func zeroLatency() {
        var stats = PushStats.zero
        stats.recordSuccess(bytes: 1000, latency: 0)
        #expect(stats.estimatedBandwidth == 0)
    }
}
