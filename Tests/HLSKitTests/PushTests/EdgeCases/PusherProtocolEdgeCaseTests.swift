// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "Pusher Protocol Edge Cases", .timeLimit(.minutes(1))
)
struct PusherProtocolEdgeCaseTests {

    // MARK: - Helpers

    private func makeSegment(
        dataSize: Int = 0
    ) -> LiveSegment {
        LiveSegment(
            index: 0,
            data: Data(repeating: 0xAB, count: dataSize),
            duration: 2.0,
            timestamp: MediaTimestamp(seconds: 0),
            isIndependent: true,
            discontinuity: false,
            programDateTime: nil,
            filename: "seg0.m4s",
            frameCount: 0,
            codecs: []
        )
    }

    // MARK: - Empty data

    @Test("RTMP handles empty segment data")
    func rtmpEmptyData() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.push(
            segment: makeSegment(dataSize: 0), as: "seg.m4s"
        )

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
        #expect(calls[0].data.isEmpty)
    }

    @Test("SRT handles empty segment data")
    func srtEmptyData() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.push(
            segment: makeSegment(dataSize: 0), as: "seg.m4s"
        )

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
        #expect(calls[0].isEmpty)
    }

    @Test("Icecast handles empty segment data")
    func icecastEmptyData() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.push(
            segment: makeSegment(dataSize: 0), as: "seg.m4s"
        )

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
    }

    // MARK: - Large data

    @Test("RTMP handles large data")
    func rtmpLargeData() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let segment = makeSegment(dataSize: 1_000_000)
        try await pusher.push(segment: segment, as: "seg.m4s")

        let stats = await pusher.stats
        #expect(stats.totalBytesPushed == 1_000_000)
    }

    @Test("SRT handles large data")
    func srtLargeData() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let segment = makeSegment(dataSize: 1_000_000)
        try await pusher.push(segment: segment, as: "seg.m4s")

        let stats = await pusher.stats
        #expect(stats.totalBytesPushed == 1_000_000)
    }

    @Test("Icecast handles large data")
    func icecastLargeData() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let segment = makeSegment(dataSize: 1_000_000)
        try await pusher.push(segment: segment, as: "seg.m4s")

        let stats = await pusher.stats
        #expect(stats.totalBytesPushed == 1_000_000)
    }

    // MARK: - Disconnect when already disconnected

    @Test("RTMP disconnect when already disconnected is no-op")
    func rtmpDoubleDisconnect() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )

        await pusher.disconnect()
        await pusher.disconnect()

        let state = await pusher.connectionState
        #expect(state == .disconnected)
    }

    @Test("SRT disconnect when already disconnected is no-op")
    func srtDoubleDisconnect() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )

        await pusher.disconnect()
        await pusher.disconnect()

        let state = await pusher.connectionState
        #expect(state == .disconnected)
    }

    @Test("Icecast disconnect when already disconnected is no-op")
    func icecastDoubleDisconnect() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: transport
        )

        await pusher.disconnect()
        await pusher.disconnect()

        let state = await pusher.connectionState
        #expect(state == .disconnected)
    }
}
