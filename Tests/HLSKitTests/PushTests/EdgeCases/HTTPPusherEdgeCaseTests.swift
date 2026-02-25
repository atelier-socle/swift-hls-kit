// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HTTPPusherEdgeCases", .timeLimit(.minutes(1)))
struct HTTPPusherEdgeCaseTests {

    // MARK: - Helpers

    private func makePusher(
        baseURL: String = "https://example.com/live/",
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

    @Test("Push with empty data")
    func emptyData() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        try await pusher.pushInitSegment(Data(), as: "empty.mp4")

        let calls = await client.uploadCalls
        #expect(calls[0].data.isEmpty)
    }

    @Test("Push with large data (1MB)")
    func largeData() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        let bigData = Data(
            repeating: 0xAA, count: 1_000_000
        )
        try await pusher.pushInitSegment(
            bigData, as: "big.mp4"
        )

        let calls = await client.uploadCalls
        #expect(calls[0].data.count == 1_000_000)
    }

    @Test("Base URL with path components")
    func baseURLWithPath() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(
            baseURL: "https://cdn.example.com/origin/stream1/hls",
            client: client
        )
        try await pusher.connect()

        try await pusher.pushPlaylist("#M3U\n", as: "live.m3u8")

        let calls = await client.uploadCalls
        #expect(
            calls[0].url
                == "https://cdn.example.com/origin/stream1/hls/live.m3u8"
        )
    }

    @Test("Concurrent pushes")
    func concurrentPushes() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<5 {
                group.addTask {
                    try await pusher.pushPlaylist(
                        "#M3U\n", as: "seg\(i).m3u8"
                    )
                }
            }
            try await group.waitForAll()
        }

        let calls = await client.uploadCalls
        #expect(calls.count == 5)
    }

    @Test("Zero-retry policy fails immediately")
    func zeroRetryFails() async throws {
        let client = MockHTTPPushClient()
        await client.setDefaultResponse(
            HTTPPushResponse(statusCode: 500, headers: [:])
        )
        let (pusher, _) = makePusher(
            retryPolicy: .noRetry, client: client
        )
        try await pusher.connect()

        do {
            try await pusher.pushPlaylist("x", as: "p.m3u8")
            Issue.record("Expected error")
        } catch let error as PushError {
            guard case .retriesExhausted(let attempts, _) = error
            else {
                Issue.record("Wrong error: \(error)")
                return
            }
            #expect(attempts == 1)
        }

        let calls = await client.uploadCalls
        #expect(calls.count == 1)
    }

    @Test("Push without connect throws notConnected")
    func pushWithoutConnect() async throws {
        let (pusher, _) = makePusher()

        do {
            try await pusher.pushPlaylist("x", as: "p.m3u8")
            Issue.record("Expected notConnected")
        } catch let error as PushError {
            guard case .notConnected = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
    }

    @Test("Connection failure throws on upload")
    func connectionFailure() async throws {
        let client = MockHTTPPushClient()
        await client.setShouldThrow(true)
        let policy = PushRetryPolicy(
            maxRetries: 0,
            circuitBreakerThreshold: 100
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        do {
            try await pusher.pushPlaylist("x", as: "p.m3u8")
            Issue.record("Expected error")
        } catch {
            // Expected connection error.
        }
    }

    @Test("Retry count incremented on retries")
    func retryCountIncremented() async throws {
        let client = MockHTTPPushClient()
        await client.setResponses([
            HTTPPushResponse(statusCode: 503, headers: [:]),
            HTTPPushResponse(statusCode: 503, headers: [:]),
            HTTPPushResponse(statusCode: 200, headers: [:])
        ])
        let policy = PushRetryPolicy(
            maxRetries: 3, baseDelay: 0.01,
            backoffMultiplier: 1.0, maxDelay: 0.01,
            circuitBreakerThreshold: 100
        )
        let (pusher, _) = makePusher(
            retryPolicy: policy, client: client
        )
        try await pusher.connect()

        try await pusher.pushPlaylist("data", as: "p.m3u8")

        let stats = await pusher.stats
        #expect(stats.retryCount == 2)
    }
}
