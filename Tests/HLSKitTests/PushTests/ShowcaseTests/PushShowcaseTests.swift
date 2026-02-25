// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PushShowcase", .timeLimit(.minutes(1)))
struct PushShowcaseTests {

    // MARK: - Helpers

    private func makeSegment(index: Int) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: UInt8(index % 256), count: 1024),
            duration: 2.0,
            timestamp: MediaTimestamp(
                seconds: Double(index) * 2.0
            ),
            isIndependent: true,
            discontinuity: false,
            programDateTime: nil,
            filename: "seg\(index).m4s",
            frameCount: 0,
            codecs: []
        )
    }

    // MARK: - Showcase

    @Test("Live stream push: 10 segments + playlists")
    func liveStreamPush() async throws {
        let client = MockHTTPPushClient()
        let config = HTTPPusherConfiguration.httpPut(
            baseURL: "https://origin.example.com/live/"
        )
        let pusher = HTTPPusher(
            configuration: config, httpClient: client
        )
        try await pusher.connect()

        for i in 0..<10 {
            let segment = makeSegment(index: i)
            try await pusher.push(
                segment: segment, as: "seg\(i).m4s"
            )
            try await pusher.pushPlaylist(
                "#EXTM3U\n", as: "playlist.m3u8"
            )
        }

        let stats = await pusher.stats
        #expect(stats.successCount == 20)
        #expect(stats.totalBytesPushed > 0)
        #expect(stats.failureCount == 0)
    }

    @Test("LL-HLS push: partials + segments + playlist")
    func llhlsPush() async throws {
        let client = MockHTTPPushClient()
        let config = HTTPPusherConfiguration.httpPut(
            baseURL: "https://origin.example.com/ll/"
        )
        let pusher = HTTPPusher(
            configuration: config, httpClient: client
        )
        try await pusher.connect()

        // Push init segment.
        try await pusher.pushInitSegment(
            Data(repeating: 0x00, count: 256), as: "init.mp4"
        )

        // Push partials.
        let partial = LLPartialSegment(
            duration: 0.33,
            uri: "seg0_part0.m4s",
            isIndependent: true,
            segmentIndex: 0,
            partialIndex: 0
        )
        try await pusher.push(
            partial: partial, as: "seg0_part0.m4s"
        )

        // Push full segment.
        try await pusher.push(
            segment: makeSegment(index: 0), as: "seg0.m4s"
        )

        // Push playlist.
        try await pusher.pushPlaylist(
            "#EXTM3U\n", as: "ll.m3u8"
        )

        let stats = await pusher.stats
        #expect(stats.successCount == 4)
    }

    @Test("CDN failover: retry behavior")
    func cdnFailover() async throws {
        let client = MockHTTPPushClient()
        await client.setResponses([
            HTTPPushResponse(statusCode: 502, headers: [:]),
            HTTPPushResponse(statusCode: 502, headers: [:]),
            HTTPPushResponse(statusCode: 200, headers: [:])
        ])
        let policy = PushRetryPolicy(
            maxRetries: 3, baseDelay: 0.01,
            backoffMultiplier: 1.0, maxDelay: 0.01,
            circuitBreakerThreshold: 100
        )
        let config = HTTPPusherConfiguration(
            baseURL: "https://cdn.example.com/",
            retryPolicy: policy
        )
        let pusher = HTTPPusher(
            configuration: config, httpClient: client
        )
        try await pusher.connect()

        try await pusher.push(
            segment: makeSegment(index: 0), as: "seg0.m4s"
        )

        let stats = await pusher.stats
        #expect(stats.successCount == 1)
        #expect(stats.retryCount == 2)
    }

    @Test("Stats tracking: bandwidth estimation")
    func bandwidthEstimation() async throws {
        let client = MockHTTPPushClient()
        let config = HTTPPusherConfiguration.httpPut(
            baseURL: "https://origin.example.com/"
        )
        let pusher = HTTPPusher(
            configuration: config, httpClient: client
        )
        try await pusher.connect()

        for i in 0..<5 {
            try await pusher.push(
                segment: makeSegment(index: i),
                as: "seg\(i).m4s"
            )
        }

        let stats = await pusher.stats
        #expect(stats.successCount == 5)
        #expect(stats.estimatedBandwidth > 0)
        #expect(stats.averageLatency >= 0)
    }

    @Test("S3-compatible push: correct headers and URL")
    func s3Push() async throws {
        let client = MockHTTPPushClient()
        let config = HTTPPusherConfiguration.s3Compatible(
            bucket: "my-bucket",
            prefix: "live/stream1",
            region: "eu-west-1"
        )
        let pusher = HTTPPusher(
            configuration: config, httpClient: client
        )
        try await pusher.connect()

        try await pusher.push(
            segment: makeSegment(index: 0), as: "seg0.m4s"
        )

        let calls = await client.uploadCalls
        #expect(calls.count == 1)
        #expect(
            calls[0].url.contains(
                "my-bucket.s3.eu-west-1.amazonaws.com"
            )
        )
        #expect(calls[0].url.contains("live/stream1/seg0.m4s"))
        #expect(calls[0].method == "PUT")
    }
}
