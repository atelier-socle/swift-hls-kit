// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("IcecastPusher", .timeLimit(.minutes(1)))
struct IcecastPusherTests {

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

    @Test("Connect calls transport with credentials and mountpoint")
    func connectCallsTransport() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.mp3",
            password: "hackme"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: transport
        )

        try await pusher.connect()

        let calls = await transport.connectCalls
        #expect(calls.count == 1)
        #expect(
            calls[0].url == "https://icecast.example.com"
        )
        #expect(calls[0].credentials.password == "hackme")
        #expect(calls[0].mountpoint == "/live.mp3")
        let state = await pusher.connectionState
        #expect(state == .connected)
    }

    @Test("Disconnect sets state")
    func disconnectState() async throws {
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

        await pusher.disconnect()

        let state = await pusher.connectionState
        #expect(state == .disconnected)
        let count = await transport.disconnectCallCount
        #expect(count == 1)
    }

    @Test("Connect with empty URL throws")
    func connectEmptyURL() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration(
            serverURL: "",
            mountpoint: "/live.mp3",
            credentials: IcecastCredentials(password: "pass")
        )
        let pusher = IcecastPusher(
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
        let transport = MockIcecastTransport()
        await transport.setThrow(true)
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
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

    @Test("Push segment sends audio data")
    func pushSegment() async throws {
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
            segment: makeSegment(dataSize: 512), as: "seg.m4s"
        )

        let calls = await transport.sendCalls
        #expect(calls.count == 1)
        #expect(calls[0].count == 512)
    }

    @Test("Push playlist is no-op")
    func pushPlaylistNoOp() async throws {
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

        try await pusher.pushPlaylist(
            "#EXTM3U\n", as: "playlist.m3u8"
        )

        let calls = await transport.sendCalls
        #expect(calls.isEmpty)
    }

    @Test("Push init segment is no-op")
    func pushInitSegmentNoOp() async throws {
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

        try await pusher.pushInitSegment(
            Data(repeating: 0xFF, count: 64), as: "init.mp4"
        )

        let calls = await transport.sendCalls
        #expect(calls.isEmpty)
    }

    @Test("Push after disconnect throws notConnected")
    func pushAfterDisconnect() async throws {
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

    // MARK: - Metadata

    @Test("Update metadata calls transport")
    func updateMetadata() async throws {
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

        let meta = IcecastMetadata(streamTitle: "My Song")
        try await pusher.updateMetadata(meta)

        let calls = await transport.metadataCalls
        #expect(calls.count == 1)
        #expect(calls[0].streamTitle == "My Song")
    }

    @Test("Update metadata when not connected throws")
    func updateMetadataNotConnected() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://icecast.example.com",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: transport
        )

        do {
            try await pusher.updateMetadata(
                IcecastMetadata(streamTitle: "test")
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
            segment: makeSegment(dataSize: 1024), as: "seg.m4s"
        )

        let stats = await pusher.stats
        #expect(stats.successCount == 1)
        #expect(stats.totalBytesPushed == 1024)
    }

    @Test("Failure updates stats")
    func failureStats() async throws {
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
        await transport.setThrow(true)

        do {
            try await pusher.push(
                segment: makeSegment(), as: "seg.m4s"
            )
        } catch {}

        let stats = await pusher.stats
        #expect(stats.failureCount == 1)
    }
}

// MARK: - MockIcecastTransport helpers

extension MockIcecastTransport {
    func setThrow(_ value: Bool) {
        shouldThrow = value
    }
}
