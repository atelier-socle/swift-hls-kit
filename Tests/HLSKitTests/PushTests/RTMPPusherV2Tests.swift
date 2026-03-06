// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock: Plain RTMPTransport (no QualityAwareTransport)

private actor PlainRTMPMock: RTMPTransport {
    private var connected = false
    private(set) var sentMetadata: [String: String]?

    var isConnected: Bool { connected }

    func connect(to url: String) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(
        data: Data, timestamp: UInt32, type: FLVTagType
    ) async throws {}

    func sendMetadata(_ metadata: [String: String]) async throws {
        sentMetadata = metadata
    }
}

// MARK: - Mock: QualityAware RTMPTransport

private actor QualityAwareRTMPMock: RTMPTransport, QualityAwareTransport {
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

    func connect(to url: String) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(
        data: Data, timestamp: UInt32, type: FLVTagType
    ) async throws {}

    var connectionQuality: TransportQuality? {
        TransportQuality(
            score: 0.85,
            grade: .good,
            recommendation: nil,
            timestamp: Date()
        )
    }

    var statisticsSnapshot: TransportStatisticsSnapshot? {
        TransportStatisticsSnapshot(
            bytesSent: 5000,
            duration: 30.0,
            currentBitrate: 1_333.0,
            peakBitrate: 2_000.0,
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

@Suite("RTMPPusher v2 — Enhanced Features")
struct RTMPPusherV2Tests {

    // MARK: - Transport Quality

    @Test("transportQuality returns nil for plain transport")
    func qualityNilForPlainTransport() async {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
        )
        let quality = await pusher.transportQuality
        #expect(quality == nil)
    }

    @Test("transportQuality returns value for quality-aware transport")
    func qualityValueForQualityAwareTransport() async {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: QualityAwareRTMPMock()
        )
        let quality = await pusher.transportQuality
        #expect(quality != nil)
        #expect(quality?.score == 0.85)
        #expect(quality?.grade == .good)
    }

    // MARK: - Transport Events

    @Test("transportEvents returns empty stream for plain transport")
    func eventsEmptyForPlainTransport() async {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
        )
        var count = 0
        for await _ in pusher.transportEvents {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("transportEvents forwards events for quality-aware transport")
    func eventsForwardedForQualityAwareTransport() async {
        let mock = QualityAwareRTMPMock()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(configuration: config, transport: mock)

        await mock.emitEvent(.connected(transportType: "RTMP"))
        await mock.finish()

        var events: [TransportEvent] = []
        for await event in pusher.transportEvents {
            events.append(event)
        }
        #expect(events.count == 1)
    }

    // MARK: - Update Stream Metadata

    @Test("updateStreamMetadata delegates to transport")
    func updateMetadataDelegatesToTransport() async throws {
        let mock = PlainRTMPMock()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(configuration: config, transport: mock)
        try await pusher.connect()
        try await pusher.updateStreamMetadata(["title": "My Stream"])
        let sent = await mock.sentMetadata
        #expect(sent == ["title": "My Stream"])
    }

    @Test("updateStreamMetadata throws when not connected")
    func updateMetadataThrowsWhenDisconnected() async {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
        )
        await #expect(throws: PushError.self) {
            try await pusher.updateStreamMetadata(["title": "Test"])
        }
    }

    // MARK: - Existing SegmentPusher Conformance

    @Test("SegmentPusher connect and disconnect still work")
    func segmentPusherConnectDisconnect() async throws {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
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
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
        )
        let stats = await pusher.stats
        #expect(stats == .zero)
    }

    @Test("Configuration accessible on pusher")
    func configurationAccessible() async {
        let config = RTMPPusherConfiguration.twitch(streamKey: "abc123")
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
        )
        let pusherConfig = await pusher.configuration
        #expect(pusherConfig.streamKey == "abc123")
        #expect(
            pusherConfig.serverURL == "rtmps://live.twitch.tv/app"
        )
    }

    @Test("pushPlaylist is no-op for RTMP")
    func pushPlaylistNoOp() async throws {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
        )
        try await pusher.connect()
        try await pusher.pushPlaylist("#EXTM3U\n", as: "live.m3u8")
        // No error = success.
    }

    @Test("push segment throws when not connected")
    func pushSegmentThrowsWhenDisconnected() async {
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://test", streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: PlainRTMPMock()
        )
        let segment = LiveSegment(
            index: 0,
            data: Data([0x00]),
            duration: 6.0,
            timestamp: .zero,
            isIndependent: true,
            filename: "seg0.ts",
            frameCount: 0,
            codecs: []
        )
        await #expect(throws: PushError.self) {
            try await pusher.push(segment: segment, as: "seg0.ts")
        }
    }
}
