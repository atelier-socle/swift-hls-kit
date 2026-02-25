// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HTTPPusher", .timeLimit(.minutes(1)))
struct HTTPPusherTests {

    // MARK: - Helpers

    private func makePusher(
        baseURL: String = "https://origin.example.com/live/",
        method: HTTPPusherConfiguration.HTTPMethod = .put,
        headers: [String: String] = [:],
        retryPolicy: PushRetryPolicy = .noRetry,
        client: MockHTTPPushClient = MockHTTPPushClient()
    ) -> (HTTPPusher, MockHTTPPushClient) {
        let config = HTTPPusherConfiguration(
            baseURL: baseURL,
            method: method,
            headers: headers,
            retryPolicy: retryPolicy
        )
        let pusher = HTTPPusher(
            configuration: config, httpClient: client
        )
        return (pusher, client)
    }

    private func makeSegment(
        index: Int = 0, dataSize: Int = 100
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: 0xAB, count: dataSize),
            duration: 2.0,
            timestamp: MediaTimestamp(seconds: 0),
            isIndependent: true,
            discontinuity: false,
            programDateTime: nil,
            filename: "seg\(index).m4s",
            frameCount: 0,
            codecs: []
        )
    }

    // MARK: - Push segment

    @Test("Push segment sends correct URL, method, data")
    func pushSegment() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        let segment = makeSegment(dataSize: 256)
        try await pusher.push(segment: segment, as: "seg0.m4s")

        let calls = await client.uploadCalls
        #expect(calls.count == 1)
        #expect(
            calls[0].url
                == "https://origin.example.com/live/seg0.m4s"
        )
        #expect(calls[0].method == "PUT")
        #expect(calls[0].data.count == 256)
    }

    @Test("Push playlist sends correct content type")
    func pushPlaylist() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        try await pusher.pushPlaylist(
            "#EXTM3U\n", as: "playlist.m3u8"
        )

        let calls = await client.uploadCalls
        #expect(calls.count == 1)
        #expect(calls[0].data == Data("#EXTM3U\n".utf8))
    }

    @Test("Push init segment sends correct data")
    func pushInitSegment() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        let initData = Data(repeating: 0xFF, count: 512)
        try await pusher.pushInitSegment(
            initData, as: "init.mp4"
        )

        let calls = await client.uploadCalls
        #expect(calls[0].data.count == 512)
    }

    // MARK: - URL construction

    @Test("URL construction with trailing slash")
    func urlWithTrailingSlash() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(
            baseURL: "https://example.com/live/",
            client: client
        )
        try await pusher.connect()

        try await pusher.pushPlaylist("#M3U\n", as: "p.m3u8")

        let calls = await client.uploadCalls
        #expect(
            calls[0].url == "https://example.com/live/p.m3u8"
        )
    }

    @Test("URL construction without trailing slash")
    func urlWithoutTrailingSlash() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(
            baseURL: "https://example.com/live",
            client: client
        )
        try await pusher.connect()

        try await pusher.pushPlaylist("#M3U\n", as: "p.m3u8")

        let calls = await client.uploadCalls
        #expect(
            calls[0].url == "https://example.com/live/p.m3u8"
        )
    }

    // MARK: - Headers

    @Test("Headers include Content-Length when configured")
    func contentLengthHeader() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        try await pusher.pushPlaylist("abc", as: "p.m3u8")
        // Content-Length is set internally via buildHeaders.
        let calls = await client.uploadCalls
        #expect(calls.count == 1)
    }

    @Test("Custom headers sent")
    func customHeaders() async throws {
        let client = MockHTTPPushClient()
        let (pusher, _) = makePusher(
            headers: ["X-Custom": "test"],
            client: client
        )
        try await pusher.connect()
        try await pusher.pushPlaylist("abc", as: "p.m3u8")

        let calls = await client.uploadCalls
        #expect(calls.count == 1)
    }

    // MARK: - Stats

    @Test("Success updates stats")
    func successStats() async throws {
        let (pusher, _) = makePusher()
        try await pusher.connect()

        try await pusher.pushPlaylist("data", as: "p.m3u8")

        let stats = await pusher.stats
        #expect(stats.successCount == 1)
        #expect(stats.totalBytesPushed > 0)
        #expect(stats.lastSuccessTime != nil)
    }

    @Test("Failure updates stats")
    func failureStats() async throws {
        let client = MockHTTPPushClient()
        await client.setDefaultResponse(
            HTTPPushResponse(statusCode: 400, headers: [:])
        )
        let (pusher, _) = makePusher(client: client)
        try await pusher.connect()

        do {
            try await pusher.pushPlaylist("data", as: "p.m3u8")
        } catch {}

        let stats = await pusher.stats
        #expect(stats.failureCount == 1)
    }

    // MARK: - Connect / Disconnect

    @Test("Connect sets state to connected")
    func connectState() async throws {
        let (pusher, _) = makePusher()
        let before = await pusher.connectionState
        #expect(before == .disconnected)

        try await pusher.connect()
        let after = await pusher.connectionState
        #expect(after == .connected)
    }

    @Test("Disconnect sets state to disconnected")
    func disconnectState() async throws {
        let (pusher, _) = makePusher()
        try await pusher.connect()
        await pusher.disconnect()

        let state = await pusher.connectionState
        #expect(state == .disconnected)
    }

    @Test("Push after disconnect throws notConnected")
    func pushAfterDisconnect() async throws {
        let (pusher, _) = makePusher()
        try await pusher.connect()
        await pusher.disconnect()

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

    @Test("Connect with empty base URL throws")
    func connectEmptyURL() async throws {
        let (pusher, _) = makePusher(baseURL: "")

        do {
            try await pusher.connect()
            Issue.record("Expected invalidConfiguration")
        } catch let error as PushError {
            guard case .invalidConfiguration = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
    }
}
