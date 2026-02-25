// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SRTPusher", .timeLimit(.minutes(1)))
struct SRTPusherTests {

    // MARK: - Helpers

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

    // MARK: - Connect / Disconnect

    @Test("Connect with options")
    func connectWithOptions() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.encrypted(
            host: "srt.example.com",
            port: 9001,
            passphrase: "secret"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )

        try await pusher.connect()

        let calls = await transport.connectCalls
        #expect(calls.count == 1)
        #expect(calls[0].host == "srt.example.com")
        #expect(calls[0].port == 9001)
        #expect(calls[0].options.passphrase == "secret")
        let state = await pusher.connectionState
        #expect(state == .connected)
    }

    @Test("Disconnect sets state")
    func disconnectState() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        await pusher.disconnect()

        let state = await pusher.connectionState
        #expect(state == .disconnected)
        let count = await transport.disconnectCallCount
        #expect(count == 1)
    }

    @Test("Connect with empty host throws")
    func connectEmptyHost() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration(
            host: "", port: 9000
        )
        let pusher = SRTPusher(
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
        let transport = MockSRTTransport()
        await transport.setThrow(true)
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )

        do {
            try await pusher.connect()
            Issue.record("Expected connectionFailed")
        } catch {}

        let state = await pusher.connectionState
        #expect(state == .failed)
    }

    // MARK: - Push

    @Test("Push segment sends data via transport")
    func pushSegment() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.push(
            segment: makeSegment(dataSize: 256), as: "seg.m4s"
        )

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
        #expect(calls[0].count == 256)
    }

    @Test("Push playlist sends M3U8 as UTF-8")
    func pushPlaylist() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.pushPlaylist(
            "#EXTM3U\n", as: "playlist.m3u8"
        )

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
        #expect(calls[0] == Data("#EXTM3U\n".utf8))
    }

    @Test("Push init segment sends data")
    func pushInitSegment() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let data = Data(repeating: 0xFF, count: 64)
        try await pusher.pushInitSegment(data, as: "init.mp4")

        let calls = await transport.sendCalls
        #expect(calls[0].count == 64)
    }

    @Test("Push after disconnect throws notConnected")
    func pushAfterDisconnect() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
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

    // MARK: - Stats & Network

    @Test("Success updates stats")
    func successStats() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.push(
            segment: makeSegment(dataSize: 1024), as: "seg.m4s"
        )

        let stats = await pusher.stats
        #expect(stats.successCount == 1)
        #expect(stats.totalBytesPushed == 1024)
    }

    @Test("Failure updates stats")
    func failureStats() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
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

    @Test("Network stats exposed from transport")
    func networkStatsExposed() async throws {
        let transport = MockSRTTransport()
        let expectedStats = SRTNetworkStats(
            roundTripTime: 0.025,
            bandwidth: 5_000_000,
            packetLossRate: 0.01,
            retransmitRate: 0.005
        )
        await transport.setNetworkStats(expectedStats)

        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let stats = await pusher.networkStats
        #expect(stats == expectedStats)
    }

    @Test("Network stats nil when not available")
    func networkStatsNil() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let stats = await pusher.networkStats
        #expect(stats == nil)
    }
}

// MARK: - MockSRTTransport helpers

extension MockSRTTransport {
    func setThrow(_ value: Bool) {
        shouldThrow = value
    }

    func setNetworkStats(_ stats: SRTNetworkStats) {
        _networkStats = stats
    }
}
