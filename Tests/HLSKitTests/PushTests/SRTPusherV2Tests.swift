// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock: Plain SRTTransport (no QualityAwareTransport)

private actor PlainSRTMock: SRTTransport {
    private var connected = false

    var isConnected: Bool { connected }

    func connect(
        to host: String, port: Int, options: SRTOptions
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    var networkStats: SRTNetworkStats? {
        SRTNetworkStats(
            roundTripTime: 0.020,
            bandwidth: 5_000_000.0,
            packetLossRate: 0.01,
            retransmitRate: 0.005
        )
    }

    var connectionQuality: SRTConnectionQuality? {
        SRTConnectionQuality(
            score: 0.90,
            grade: .excellent,
            rttMs: 20.0,
            packetLossRate: 0.01
        )
    }

    var isEncrypted: Bool { true }
}

// MARK: - Mock: QualityAware SRTTransport

private actor QualityAwareSRTMock: SRTTransport,
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
        to host: String, port: Int, options: SRTOptions
    ) async throws {
        connected = true
    }

    func disconnect() async {
        connected = false
    }

    func send(_ data: Data) async throws {}

    var networkStats: SRTNetworkStats? { nil }

    var connectionQuality: TransportQuality? {
        TransportQuality(
            score: 0.78,
            grade: .good,
            recommendation: nil,
            timestamp: Date()
        )
    }

    var statisticsSnapshot: TransportStatisticsSnapshot? {
        TransportStatisticsSnapshot(
            bytesSent: 10_000,
            duration: 60.0,
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

@Suite("SRTPusher v2 — Enhanced Features")
struct SRTPusherV2Tests {

    // MARK: - Transport Quality

    @Test("transportQuality uses SRT conversion for plain transport")
    func qualityConversionForPlainTransport() async {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
        )
        let quality = await pusher.transportQuality
        #expect(quality != nil)
        #expect(quality?.score == 0.90)
        #expect(quality?.grade == .excellent)
    }

    @Test("transportQuality returns value for quality-aware transport")
    func qualityValueForQualityAwareTransport() async {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config,
            transport: QualityAwareSRTMock()
        )
        let quality = await pusher.transportQuality
        #expect(quality != nil)
        #expect(quality?.score == 0.78)
        #expect(quality?.grade == .good)
    }

    // MARK: - Transport Events

    @Test("transportEvents returns empty stream for plain transport")
    func eventsEmptyForPlainTransport() async {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
        )
        var count = 0
        for await _ in pusher.transportEvents {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("transportEvents forwards events for quality-aware transport")
    func eventsForwardedForQualityAwareTransport() async {
        let mock = QualityAwareSRTMock()
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: mock
        )

        await mock.emitEvent(.connected(transportType: "SRT"))
        await mock.finish()

        var events: [TransportEvent] = []
        for await event in pusher.transportEvents {
            events.append(event)
        }
        #expect(events.count == 1)
    }

    // MARK: - SRT-specific v2

    @Test("connectionQuality delegates to transport")
    func connectionQualityDelegates() async {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
        )
        let quality = await pusher.connectionQuality
        #expect(quality != nil)
        #expect(quality?.score == 0.90)
        #expect(quality?.grade == .excellent)
    }

    @Test("isEncrypted delegates to transport")
    func isEncryptedDelegates() async {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
        )
        let encrypted = await pusher.isEncrypted
        #expect(encrypted == true)
    }

    // MARK: - Existing Features Unchanged

    @Test("networkStats still works")
    func networkStatsStillWorks() async {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
        )
        let stats = await pusher.networkStats
        #expect(stats != nil)
        #expect(stats?.roundTripTime == 0.020)
    }

    @Test("SegmentPusher connect and disconnect still work")
    func segmentPusherConnectDisconnect() async throws {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
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
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
        )
        let stats = await pusher.stats
        #expect(stats == .zero)
    }

    @Test("push segment throws when not connected")
    func pushSegmentThrowsWhenDisconnected() async {
        let config = SRTPusherConfiguration(
            host: "srt.test.com", port: 9000
        )
        let pusher = SRTPusher(
            configuration: config, transport: PlainSRTMock()
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
