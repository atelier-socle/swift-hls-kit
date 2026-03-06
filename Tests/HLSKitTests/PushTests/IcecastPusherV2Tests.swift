// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock: Plain IcecastTransport (no QualityAwareTransport)

private actor PlainIcecastMock: IcecastTransport {
    private var connected = false
    private(set) var lastMetadata: IcecastMetadata?

    var isConnected: Bool { connected }

    func connect(
        to url: String,
        credentials: IcecastCredentials,
        mountpoint: String
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    func updateMetadata(
        _ metadata: IcecastMetadata
    ) async throws {
        lastMetadata = metadata
    }

    var serverVersion: String? { "Icecast 2.4.4" }

    var streamStatistics: IcecastStreamStatistics? {
        IcecastStreamStatistics(
            bytesSent: 10_000,
            duration: 60.0,
            currentBitrate: 128_000.0,
            metadataUpdateCount: 2,
            reconnectionCount: 0
        )
    }
}

// MARK: - Mock: QualityAware IcecastTransport

private actor QualityAwareIcecastMock: IcecastTransport,
    QualityAwareTransport
{
    private var connected = false
    private let eventsContinuation: AsyncStream<TransportEvent>.Continuation

    let transportEvents: AsyncStream<TransportEvent>

    init() {
        let (stream, continuation) = AsyncStream.makeStream(
            of: TransportEvent.self
        )
        self.transportEvents = stream
        self.eventsContinuation = continuation
    }

    var isConnected: Bool { connected }

    func connect(
        to url: String,
        credentials: IcecastCredentials,
        mountpoint: String
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    func updateMetadata(
        _ metadata: IcecastMetadata
    ) async throws {}

    var connectionQuality: TransportQuality? {
        TransportQuality(
            score: 0.92,
            grade: .excellent,
            recommendation: nil,
            timestamp: Date()
        )
    }

    var statisticsSnapshot: TransportStatisticsSnapshot? {
        TransportStatisticsSnapshot(
            bytesSent: 20_000,
            duration: 120.0,
            currentBitrate: 128_000.0,
            peakBitrate: 192_000.0,
            reconnectionCount: 0,
            timestamp: Date()
        )
    }

    func emitEvent(_ event: TransportEvent) {
        eventsContinuation.yield(event)
    }

    func finish() {
        eventsContinuation.finish()
    }
}

// MARK: - Tests

@Suite("IcecastPusher v2 — Enhanced Features")
struct IcecastPusherV2Tests {

    // MARK: - Transport Quality

    @Test("transportQuality returns nil for plain transport")
    func qualityNilForPlainTransport() async {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: PlainIcecastMock()
        )
        let quality = await pusher.transportQuality
        #expect(quality == nil)
    }

    @Test("transportQuality returns value for quality-aware transport")
    func qualityValueForQualityAwareTransport() async {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config,
            transport: QualityAwareIcecastMock()
        )
        let quality = await pusher.transportQuality
        #expect(quality != nil)
        #expect(quality?.score == 0.92)
        #expect(quality?.grade == .excellent)
    }

    // MARK: - Transport Events

    @Test("transportEvents returns empty stream for plain transport")
    func eventsEmptyForPlainTransport() async {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: PlainIcecastMock()
        )
        var count = 0
        for await _ in pusher.transportEvents {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("transportEvents forwards events for quality-aware transport")
    func eventsForwardedForQualityAwareTransport() async {
        let mock = QualityAwareIcecastMock()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: mock
        )

        await mock.emitEvent(.connected(transportType: "Icecast"))
        await mock.finish()

        var events: [TransportEvent] = []
        for await event in pusher.transportEvents {
            events.append(event)
        }
        #expect(events.count == 1)
    }

    // MARK: - v2 Delegates

    @Test("serverVersion delegates to transport")
    func serverVersionDelegates() async {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: PlainIcecastMock()
        )
        let version = await pusher.serverVersion
        #expect(version == "Icecast 2.4.4")
    }

    @Test("streamStatistics delegates to transport")
    func streamStatisticsDelegates() async {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: PlainIcecastMock()
        )
        let stats = await pusher.streamStatistics
        #expect(stats != nil)
        #expect(stats?.bytesSent == 10_000)
        #expect(stats?.currentBitrate == 128_000.0)
    }

    // MARK: - Existing Features Unchanged

    @Test("updateMetadata still works")
    func updateMetadataStillWorks() async throws {
        let mock = PlainIcecastMock()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: mock
        )
        try await pusher.connect()
        let metadata = IcecastMetadata(streamTitle: "Test Song")
        try await pusher.updateMetadata(metadata)
        let sent = await mock.lastMetadata
        #expect(sent?.streamTitle == "Test Song")
    }

    @Test("SegmentPusher connect and disconnect still work")
    func segmentPusherConnectDisconnect() async throws {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: PlainIcecastMock()
        )
        try await pusher.connect()
        let state = await pusher.connectionState
        #expect(state == .connected)

        await pusher.disconnect()
        let disconnected = await pusher.connectionState
        #expect(disconnected == .disconnected)
    }

    @Test("SegmentPusher stats accessible")
    func segmentPusherStats() async {
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "http://icecast.test:8000",
            mountpoint: "/live.mp3",
            password: "pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: PlainIcecastMock()
        )
        let stats = await pusher.stats
        #expect(stats == .zero)
    }
}
