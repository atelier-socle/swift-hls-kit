// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock: Plain SegmentPusher (no quality/ABR)

private actor MockSegmentPusher: SegmentPusher {
    private var _connectionState: PushConnectionState = .disconnected
    private var _stats: PushStats = .zero
    private(set) var pushSegmentCalled = false
    private(set) var pushPartialCalled = false
    private(set) var pushPlaylistCalled = false
    private(set) var pushInitSegmentCalled = false
    private(set) var connectCalled = false
    private(set) var disconnectCalled = false

    var connectionState: PushConnectionState { _connectionState }
    var stats: PushStats { _stats }

    func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        pushSegmentCalled = true
    }

    func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        pushPartialCalled = true
    }

    func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        pushPlaylistCalled = true
    }

    func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        pushInitSegmentCalled = true
    }

    func connect() async throws {
        _connectionState = .connected
        connectCalled = true
    }

    func disconnect() async {
        _connectionState = .disconnected
        disconnectCalled = true
    }
}

// MARK: - Mock: QualityAwareTransport

private actor MockQualityTransport: QualityAwareTransport {
    let transportEvents: AsyncStream<TransportEvent>
    private let continuation: AsyncStream<TransportEvent>.Continuation

    init() {
        let (stream, cont) = AsyncStream.makeStream(
            of: TransportEvent.self
        )
        self.transportEvents = stream
        self.continuation = cont
    }

    var connectionQuality: TransportQuality? {
        TransportQuality(
            score: 0.85,
            grade: .good,
            recommendation: nil,
            timestamp: Date()
        )
    }

    var statisticsSnapshot: TransportStatisticsSnapshot? { nil }

    func emitEvent(_ event: TransportEvent) {
        continuation.yield(event)
    }

    func finish() {
        continuation.finish()
    }
}

// MARK: - Mock: AdaptiveBitrateTransport

private actor MockABRTransport: AdaptiveBitrateTransport {
    let bitrateRecommendations: AsyncStream<TransportBitrateRecommendation>
    private let continuation: AsyncStream<TransportBitrateRecommendation>.Continuation

    init() {
        let (stream, cont) = AsyncStream.makeStream(
            of: TransportBitrateRecommendation.self
        )
        self.bitrateRecommendations = stream
        self.continuation = cont
    }

    func emitRecommendation(
        _ rec: TransportBitrateRecommendation
    ) {
        continuation.yield(rec)
    }

    func finish() {
        continuation.finish()
    }
}

// MARK: - Tests

@Suite(
    "TransportAwarePusher",
    .timeLimit(.minutes(1))
)
struct TransportAwarePusherTests {

    // MARK: - Init & Transport Signals

    @Test("Init with plain pusher — transportQuality nil")
    func plainPusherQualityNil() async {
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher()
        )
        let quality = await pusher.transportQuality
        #expect(quality == nil)
    }

    @Test("Init with plain pusher — events empty")
    func plainPusherEventsEmpty() async {
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher()
        )
        var count = 0
        for await _ in pusher.transportEvents {
            count += 1
        }
        #expect(count == 0)
    }

    @Test("Init with plain pusher — recommendation nil")
    func plainPusherRecommendationNil() async {
        let abr = MockABRTransport()
        await abr.finish()
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher()
        )
        let rec = await pusher.latestBitrateRecommendation
        #expect(rec == nil)
    }

    @Test("Init with quality transport — quality returns value")
    func qualityTransportReturnsValue() async {
        let qt = MockQualityTransport()
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher(),
            qualityTransport: qt
        )
        let quality = await pusher.transportQuality
        #expect(quality != nil)
        #expect(quality?.score == 0.85)
        #expect(quality?.grade == .good)
    }

    @Test("Init with ABR transport — recommendation returns value")
    func abrTransportReturnsValue() async {
        let abr = MockABRTransport()
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher(),
            abrTransport: abr
        )
        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 256_000,
            currentEstimatedBitrate: 300_000,
            direction: .decrease,
            reason: "congestion",
            confidence: 0.9,
            timestamp: Date()
        )
        await abr.emitRecommendation(rec)
        await abr.finish()
        let latest = await pusher.latestBitrateRecommendation
        #expect(latest?.recommendedBitrate == 256_000)
    }

    @Test("Init with both quality + ABR — all signals available")
    func bothTransportsAvailable() async {
        let qt = MockQualityTransport()
        let abr = MockABRTransport()
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher(),
            qualityTransport: qt,
            abrTransport: abr
        )
        let quality = await pusher.transportQuality
        #expect(quality != nil)
        await abr.finish()
        let rec = await pusher.latestBitrateRecommendation
        #expect(rec == nil)
    }

    // MARK: - SegmentPusher Delegation

    @Test("push(segment:) delegates to inner")
    func pushSegmentDelegates() async throws {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        try await inner.connect()
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
        try await pusher.push(segment: segment, as: "seg0.ts")
        let called = await inner.pushSegmentCalled
        #expect(called)
    }

    @Test("push(partial:) delegates to inner")
    func pushPartialDelegates() async throws {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        let partial = LLPartialSegment(
            duration: 0.5,
            uri: "part0.0.mp4",
            isIndependent: true,
            segmentIndex: 0,
            partialIndex: 0
        )
        try await pusher.push(partial: partial, as: "part0.0.mp4")
        let called = await inner.pushPartialCalled
        #expect(called)
    }

    @Test("pushPlaylist delegates to inner")
    func pushPlaylistDelegates() async throws {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        try await pusher.pushPlaylist("#EXTM3U\n", as: "live.m3u8")
        let called = await inner.pushPlaylistCalled
        #expect(called)
    }

    @Test("pushInitSegment delegates to inner")
    func pushInitSegmentDelegates() async throws {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        try await pusher.pushInitSegment(
            Data([0x00, 0x01]), as: "init.mp4"
        )
        let called = await inner.pushInitSegmentCalled
        #expect(called)
    }

    @Test("connect delegates to inner")
    func connectDelegates() async throws {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        try await pusher.connect()
        let called = await inner.connectCalled
        #expect(called)
    }

    @Test("disconnect delegates to inner")
    func disconnectDelegates() async {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        await pusher.disconnect()
        let called = await inner.disconnectCalled
        #expect(called)
    }

    @Test("connectionState delegates to inner")
    func connectionStateDelegates() async throws {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        let before = await pusher.connectionState
        #expect(before == .disconnected)
        try await pusher.connect()
        let after = await pusher.connectionState
        #expect(after == .connected)
    }

    @Test("stats delegates to inner")
    func statsDelegates() async {
        let inner = MockSegmentPusher()
        let pusher = TransportAwarePusher(pusher: inner)
        let stats = await pusher.stats
        #expect(stats == .zero)
    }

    @Test("transportEvents forwards from quality transport")
    func eventsForwarded() async {
        let qt = MockQualityTransport()
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher(),
            qualityTransport: qt
        )
        await qt.emitEvent(.connected(transportType: "RTMP"))
        await qt.finish()
        var events: [TransportEvent] = []
        for await event in pusher.transportEvents {
            events.append(event)
        }
        #expect(events.count == 1)
    }

    @Test("Sendable conformance in async context")
    func sendableConformance() async {
        let pusher = TransportAwarePusher(
            pusher: MockSegmentPusher()
        )
        let state = await pusher.connectionState
        #expect(state == .disconnected)
    }
}
