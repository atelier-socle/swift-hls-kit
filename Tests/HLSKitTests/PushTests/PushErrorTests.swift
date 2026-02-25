// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PushError", .timeLimit(.minutes(1)))
struct PushErrorTests {

    @Test("httpError description includes status code")
    func httpError() {
        let error = PushError.httpError(
            statusCode: 503, message: "Service Unavailable"
        )
        #expect(error.description.contains("503"))
        #expect(error.description.contains("Service Unavailable"))
    }

    @Test("httpError without message")
    func httpErrorNoMessage() {
        let error = PushError.httpError(
            statusCode: 500, message: nil
        )
        #expect(error.description.contains("500"))
    }

    @Test("connectionFailed description")
    func connectionFailed() {
        let error = PushError.connectionFailed(
            underlying: "DNS resolution failed"
        )
        #expect(error.description.contains("DNS resolution"))
    }

    @Test("timeout description includes duration")
    func timeout() {
        let error = PushError.timeout(30.0)
        #expect(error.description.contains("30.0"))
    }

    @Test("retriesExhausted includes attempt count")
    func retriesExhausted() {
        let error = PushError.retriesExhausted(
            attempts: 4, lastError: "HTTP 503"
        )
        #expect(error.description.contains("4"))
        #expect(error.description.contains("HTTP 503"))
    }

    @Test("circuitBreakerOpen includes failure count")
    func circuitBreakerOpen() {
        let error = PushError.circuitBreakerOpen(failures: 10)
        #expect(error.description.contains("10"))
        #expect(error.description.contains("Circuit breaker"))
    }

    @Test("cancelled, invalidConfiguration, notConnected")
    func otherCases() {
        #expect(
            PushError.cancelled.description.contains("cancelled")
        )
        #expect(
            PushError.invalidConfiguration("bad url")
                .description.contains("bad url")
        )
        #expect(
            PushError.notConnected.description.contains(
                "not connected"
            )
        )
    }
}
