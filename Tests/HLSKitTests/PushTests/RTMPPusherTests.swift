// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("RTMPPusher", .timeLimit(.minutes(1)))
struct RTMPPusherTests {

    // MARK: - Helpers

    private func makeSegment(
        index: Int = 0, dataSize: Int = 100,
        duration: Double = 2.0
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: 0xAB, count: dataSize),
            duration: duration,
            timestamp: MediaTimestamp(seconds: 0),
            isIndependent: true,
            discontinuity: false,
            programDateTime: nil,
            filename: "seg\(index).m4s",
            frameCount: 0,
            codecs: []
        )
    }

    // MARK: - Connect / Disconnect

    @Test("Connect calls transport with fullURL")
    func connectCallsTransport() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key123"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )

        try await pusher.connect()

        let calls = await transport.connectCalls
        #expect(calls.count == 1)
        #expect(calls[0] == "rtmp://server.com/app/key123")
        let state = await pusher.connectionState
        #expect(state == .connected)
    }

    @Test("Disconnect calls transport")
    func disconnectCallsTransport() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        await pusher.disconnect()

        let count = await transport.disconnectCallCount
        #expect(count == 1)
        let state = await pusher.connectionState
        #expect(state == .disconnected)
    }

    @Test("Connect with empty URL throws invalidConfiguration")
    func connectEmptyURL() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration(
            serverURL: "", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )

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

    @Test("Connect failure sets state to failed")
    func connectFailure() async throws {
        let transport = MockRTMPTransport()
        await transport.setThrow(true)
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )

        do {
            try await pusher.connect()
            Issue.record("Expected connectionFailed")
        } catch let error as PushError {
            guard case .connectionFailed = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
        let state = await pusher.connectionState
        #expect(state == .failed)
    }

    // MARK: - Push segment

    @Test("Push segment sends FLV video data")
    func pushSegmentSendsVideo() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let segment = makeSegment(dataSize: 256)
        try await pusher.push(segment: segment, as: "seg0.m4s")

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
        #expect(calls[0].data.count == 256)
        #expect(calls[0].type == .video)
        #expect(calls[0].timestamp == 0)
    }

    @Test("Timestamps accumulate across segments")
    func timestampsAccumulate() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let seg1 = makeSegment(index: 0, duration: 2.0)
        let seg2 = makeSegment(index: 1, duration: 3.0)
        try await pusher.push(segment: seg1, as: "seg0.m4s")
        try await pusher.push(segment: seg2, as: "seg1.m4s")

        let calls = await transport.sendCalls
        #expect(calls[0].timestamp == 0)
        #expect(calls[1].timestamp == 2000)
    }

    @Test("Push init segment sends FLV script data")
    func pushInitSegmentSendsScript() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let data = Data(repeating: 0xFF, count: 64)
        try await pusher.pushInitSegment(data, as: "init.mp4")

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
        #expect(calls[0].type == .scriptData)
        #expect(calls[0].timestamp == 0)
    }

    @Test("Push playlist is no-op")
    func pushPlaylistNoOp() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.pushPlaylist(
            "#EXTM3U\n", as: "playlist.m3u8"
        )

        let calls = await transport.sendCalls
        #expect(calls.isEmpty)
    }

    @Test("Push after disconnect throws notConnected")
    func pushAfterDisconnect() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()
        await pusher.disconnect()

        do {
            try await pusher.push(
                segment: makeSegment(), as: "seg.m4s"
            )
            Issue.record("Expected notConnected")
        } catch let error as PushError {
            guard case .notConnected = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
    }

    // MARK: - Stats

    @Test("Success updates stats")
    func successStats() async throws {
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
            segment: makeSegment(dataSize: 512), as: "seg.m4s"
        )

        let stats = await pusher.stats
        #expect(stats.successCount == 1)
        #expect(stats.totalBytesPushed == 512)
    }

    @Test("Failure updates stats")
    func failureStats() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()
        await transport.setThrow(true)

        do {
            try await pusher.push(
                segment: makeSegment(), as: "seg.m4s"
            )
        } catch {}

        let stats = await pusher.stats
        #expect(stats.failureCount == 1)
    }

    @Test("FLVTagType raw values")
    func flvTagTypeRawValues() {
        #expect(FLVTagType.audio.rawValue == 8)
        #expect(FLVTagType.video.rawValue == 9)
        #expect(FLVTagType.scriptData.rawValue == 18)
    }

}

// MARK: - MockRTMPTransport helpers

extension MockRTMPTransport {
    func setThrow(_ value: Bool) {
        shouldThrow = value
    }
}
