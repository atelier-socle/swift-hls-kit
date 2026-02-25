// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HTTPPusher Retry & Circuit Breaker", .timeLimit(.minutes(1)))
struct HTTPPusherRetryTests {

    // MARK: - Helpers

    private func makePusher(
        baseURL: String = "https://origin.example.com/live/",
        retryPolicy: PushRetryPolicy = .noRetry,
        client: MockHTTPPushClient = MockHTTPPushClient()
    ) -> (HTTPPusher, MockHTTPPushClient) {
        let config = HTTPPusherConfiguration(
            baseURL: baseURL,
            retryPolicy: retryPolicy
        )
        let pusher = HTTPPusher(
            configuration: config, httpClient: client
        )
        return (pusher, client)
    }

    // MARK: - Retry

    @Test("Retry on 500 succeeds on second attempt")
    func retryOn500() async throws {
        let client = MockHTTPPushClient()
        await client.setResponses([
            HTTPPushResponse(statusCode: 500, headers: [:]),
            HTTPPushResponse(statusCode: 200, headers: [:])
        ])
        let policy = PushRetryPolicy(
            maxRetries: 2, baseDelay: 0.01,
            backoffMultiplier: 1.0, maxDelay: 0.01
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        try await pusher.pushPlaylist("data", as: "p.m3u8")

        let calls = await client.uploadCalls
        #expect(calls.count == 2)
    }

    @Test("No retry on 400 client error")
    func noRetryOn400() async throws {
        let client = MockHTTPPushClient()
        await client.setDefaultResponse(
            HTTPPushResponse(statusCode: 400, headers: [:])
        )
        let policy = PushRetryPolicy(
            maxRetries: 3, baseDelay: 0.01
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        do {
            try await pusher.pushPlaylist("data", as: "p.m3u8")
            Issue.record("Expected error")
        } catch let error as PushError {
            guard case .httpError(let code, _) = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
            #expect(code == 400)
        }

        let calls = await client.uploadCalls
        #expect(calls.count == 1)
    }

    @Test("Retry on 429 rate limit")
    func retryOn429() async throws {
        let client = MockHTTPPushClient()
        await client.setResponses([
            HTTPPushResponse(statusCode: 429, headers: [:]),
            HTTPPushResponse(statusCode: 200, headers: [:])
        ])
        let policy = PushRetryPolicy(
            maxRetries: 2, baseDelay: 0.01,
            backoffMultiplier: 1.0, maxDelay: 0.01
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        try await pusher.pushPlaylist("data", as: "p.m3u8")

        let calls = await client.uploadCalls
        #expect(calls.count == 2)
    }

    @Test("Retries exhausted throws retriesExhausted")
    func retriesExhausted() async throws {
        let client = MockHTTPPushClient()
        await client.setDefaultResponse(
            HTTPPushResponse(statusCode: 500, headers: [:])
        )
        let policy = PushRetryPolicy(
            maxRetries: 2, baseDelay: 0.01,
            backoffMultiplier: 1.0, maxDelay: 0.01,
            circuitBreakerThreshold: 100
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        do {
            try await pusher.pushPlaylist("data", as: "p.m3u8")
            Issue.record("Expected retriesExhausted")
        } catch let error as PushError {
            guard case .retriesExhausted(let attempts, _) = error
            else {
                Issue.record("Wrong error: \(error)")
                return
            }
            #expect(attempts == 3)
        }
    }

    @Test("Retry count incremented in stats")
    func retryCountStats() async throws {
        let client = MockHTTPPushClient()
        await client.setResponses([
            HTTPPushResponse(statusCode: 500, headers: [:]),
            HTTPPushResponse(statusCode: 200, headers: [:])
        ])
        let policy = PushRetryPolicy(
            maxRetries: 2, baseDelay: 0.01,
            backoffMultiplier: 1.0, maxDelay: 0.01
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        try await pusher.pushPlaylist("data", as: "p.m3u8")

        let stats = await pusher.stats
        #expect(stats.retryCount == 1)
    }

    // MARK: - Circuit breaker

    @Test("Circuit breaker opens after threshold failures")
    func circuitBreakerOpens() async throws {
        let client = MockHTTPPushClient()
        await client.setDefaultResponse(
            HTTPPushResponse(statusCode: 400, headers: [:])
        )
        let policy = PushRetryPolicy(
            maxRetries: 0,
            circuitBreakerThreshold: 3,
            circuitBreakerResetInterval: 60.0
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        // 3 failures to open circuit breaker.
        for _ in 0..<3 {
            do {
                try await pusher.pushPlaylist("x", as: "p.m3u8")
            } catch {}
        }

        let stats = await pusher.stats
        #expect(stats.circuitBreakerOpen)

        // Next push should get circuit breaker error.
        do {
            try await pusher.pushPlaylist("x", as: "p.m3u8")
            Issue.record("Expected circuitBreakerOpen")
        } catch let error as PushError {
            guard case .circuitBreakerOpen = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
    }

    @Test("Circuit breaker resets after disconnect/reconnect")
    func circuitBreakerResetsOnReconnect() async throws {
        let client = MockHTTPPushClient()
        await client.setDefaultResponse(
            HTTPPushResponse(statusCode: 400, headers: [:])
        )
        let policy = PushRetryPolicy(
            maxRetries: 0,
            circuitBreakerThreshold: 2,
            circuitBreakerResetInterval: 60.0
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        for _ in 0..<2 {
            do {
                try await pusher.pushPlaylist("x", as: "p.m3u8")
            } catch {}
        }

        // Disconnect and reconnect resets breaker.
        await pusher.disconnect()
        try await pusher.connect()

        await client.setDefaultResponse(
            HTTPPushResponse(statusCode: 200, headers: [:])
        )
        try await pusher.pushPlaylist("ok", as: "p.m3u8")

        let stats = await pusher.stats
        #expect(stats.successCount == 1)
    }
}
