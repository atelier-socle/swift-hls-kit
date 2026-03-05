// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock Types

/// Mock transport conforming to all three transport protocols.
private actor MockQualityTransport:
    QualityAwareTransport,
    AdaptiveBitrateTransport,
    RecordingTransport
{
    private var quality: TransportQuality?
    private var stats: TransportStatisticsSnapshot?
    private var recording: TransportRecordingState?
    private let eventsContinuation: AsyncStream<TransportEvent>.Continuation
    private let recContinuation: AsyncStream<TransportBitrateRecommendation>.Continuation

    let transportEvents: AsyncStream<TransportEvent>
    let bitrateRecommendations: AsyncStream<TransportBitrateRecommendation>

    init() {
        let (eventStream, eventCont) = AsyncStream.makeStream(
            of: TransportEvent.self
        )
        self.transportEvents = eventStream
        self.eventsContinuation = eventCont

        let (recStream, recCont) = AsyncStream.makeStream(
            of: TransportBitrateRecommendation.self
        )
        self.bitrateRecommendations = recStream
        self.recContinuation = recCont
    }

    var connectionQuality: TransportQuality? { quality }
    var statisticsSnapshot: TransportStatisticsSnapshot? { stats }
    var recordingState: TransportRecordingState? { recording }

    func setQuality(_ q: TransportQuality) {
        quality = q
    }

    func setStats(_ s: TransportStatisticsSnapshot) {
        stats = s
    }

    func startRecording(directory: String) async throws {
        recording = TransportRecordingState(
            isRecording: true,
            bytesWritten: 0,
            duration: 0,
            currentFilePath: directory + "/stream.ts"
        )
    }

    func stopRecording() async throws {
        recording = TransportRecordingState(
            isRecording: false,
            bytesWritten: recording?.bytesWritten ?? 0,
            duration: recording?.duration ?? 0,
            currentFilePath: recording?.currentFilePath
        )
    }

    func emitEvent(_ event: TransportEvent) {
        eventsContinuation.yield(event)
    }

    func emitRecommendation(_ rec: TransportBitrateRecommendation) {
        recContinuation.yield(rec)
    }

    func finish() {
        eventsContinuation.finish()
        recContinuation.finish()
    }
}

// MARK: - Tests

@Suite("QualityAwareTransport — Protocol Conformance")
struct QualityAwareTransportTests {

    // MARK: - QualityAwareTransport

    @Test("QualityAwareTransport: async property access")
    func qualityAwareAsyncAccess() async {
        let transport = MockQualityTransport()
        let quality = await transport.connectionQuality
        #expect(quality == nil)

        let q = TransportQuality(
            score: 0.9, grade: .good, recommendation: nil, timestamp: Date()
        )
        await transport.setQuality(q)
        let updated = await transport.connectionQuality
        #expect(updated?.score == 0.9)
    }

    @Test("QualityAwareTransport: statistics snapshot access")
    func statisticsSnapshotAccess() async {
        let transport = MockQualityTransport()
        #expect(await transport.statisticsSnapshot == nil)

        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 1000,
            duration: 10.0,
            currentBitrate: 800.0,
            peakBitrate: 1200.0,
            reconnectionCount: 0,
            timestamp: Date()
        )
        await transport.setStats(snapshot)
        let result = await transport.statisticsSnapshot
        #expect(result?.bytesSent == 1000)
    }

    @Test("QualityAwareTransport: event stream consumption")
    func eventStreamConsumption() async {
        let transport = MockQualityTransport()

        await transport.emitEvent(.connected(transportType: "RTMP"))
        await transport.finish()

        var events: [TransportEvent] = []
        for await event in transport.transportEvents {
            events.append(event)
        }
        #expect(events.count == 1)
    }

    // MARK: - AdaptiveBitrateTransport

    @Test("AdaptiveBitrateTransport: recommendation stream")
    func bitrateRecommendationStream() async {
        let transport = MockQualityTransport()

        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentEstimatedBitrate: 3_000_000,
            direction: .decrease,
            reason: "Congestion",
            confidence: 0.7,
            timestamp: Date()
        )
        await transport.emitRecommendation(rec)
        await transport.finish()

        var recommendations: [TransportBitrateRecommendation] = []
        for await r in transport.bitrateRecommendations {
            recommendations.append(r)
        }
        #expect(recommendations.count == 1)
        #expect(recommendations.first?.direction == .decrease)
    }

    // MARK: - RecordingTransport

    @Test("RecordingTransport: start and stop cycle")
    func recordingStartStopCycle() async throws {
        let transport = MockQualityTransport()
        #expect(await transport.recordingState == nil)

        try await transport.startRecording(directory: "/tmp")
        let active = await transport.recordingState
        #expect(active?.isRecording == true)
        #expect(active?.currentFilePath == "/tmp/stream.ts")

        try await transport.stopRecording()
        let stopped = await transport.recordingState
        #expect(stopped?.isRecording == false)
    }

    @Test("RecordingTransport: initial state is nil")
    func recordingInitialState() async {
        let transport = MockQualityTransport()
        let state = await transport.recordingState
        #expect(state == nil)
    }

    // MARK: - Protocol Composition

    @Test("Protocol composition: single type conforms to all three")
    func protocolComposition() async {
        let transport = MockQualityTransport()

        // Verify conformance to all three protocols.
        let qualityAware: any QualityAwareTransport = transport
        let adaptive: any AdaptiveBitrateTransport = transport
        let recording: any RecordingTransport = transport

        #expect(await qualityAware.connectionQuality == nil)
        _ = adaptive.bitrateRecommendations
        #expect(await recording.recordingState == nil)
    }

    @Test("Sendable conformance of protocol existentials")
    func sendableExistentials() async {
        let transport = MockQualityTransport()
        let sendable: any QualityAwareTransport & Sendable = transport
        let task = Task { await sendable.connectionQuality }
        let result = await task.value
        #expect(result == nil)
    }
}
