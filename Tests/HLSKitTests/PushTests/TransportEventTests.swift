// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TransportEvent — Unified Transport Events")
struct TransportEventTests {

    // MARK: - Case Construction

    @Test("Connected event carries transport type")
    func connectedEvent() {
        let event = TransportEvent.connected(transportType: "RTMP")
        if case .connected(let transportType) = event {
            #expect(transportType == "RTMP")
        } else {
            Issue.record("Expected .connected case")
        }
    }

    @Test("Disconnected event with error")
    func disconnectedWithError() {
        let error = PushError.connectionFailed(underlying: "timeout")
        let event = TransportEvent.disconnected(
            transportType: "SRT", error: error
        )
        if case .disconnected(let type, let err) = event {
            #expect(type == "SRT")
            #expect(err != nil)
        } else {
            Issue.record("Expected .disconnected case")
        }
    }

    @Test("Disconnected event with nil error")
    func disconnectedWithNilError() {
        let event = TransportEvent.disconnected(
            transportType: "Icecast", error: nil
        )
        if case .disconnected(let type, let err) = event {
            #expect(type == "Icecast")
            #expect(err == nil)
        } else {
            Issue.record("Expected .disconnected case")
        }
    }

    @Test("Reconnecting event carries attempt number")
    func reconnectingEvent() {
        let event = TransportEvent.reconnecting(
            transportType: "RTMP", attempt: 3
        )
        if case .reconnecting(let type, let attempt) = event {
            #expect(type == "RTMP")
            #expect(attempt == 3)
        } else {
            Issue.record("Expected .reconnecting case")
        }
    }

    // MARK: - Events with Associated Values

    @Test("Quality changed event carries quality data")
    func qualityChangedEvent() {
        let quality = TransportQuality(
            score: 0.75, grade: .good, recommendation: nil, timestamp: Date()
        )
        let event = TransportEvent.qualityChanged(quality)
        if case .qualityChanged(let q) = event {
            #expect(q.score == 0.75)
            #expect(q.grade == .good)
        } else {
            Issue.record("Expected .qualityChanged case")
        }
    }

    @Test("Bitrate recommendation event carries recommendation")
    func bitrateRecommendationEvent() {
        let rec = TransportBitrateRecommendation(
            recommendedBitrate: 1_500_000,
            currentEstimatedBitrate: 2_000_000,
            direction: .decrease,
            reason: "Congestion",
            confidence: 0.8,
            timestamp: Date()
        )
        let event = TransportEvent.bitrateRecommendation(rec)
        if case .bitrateRecommendation(let r) = event {
            #expect(r.recommendedBitrate == 1_500_000)
            #expect(r.direction == .decrease)
        } else {
            Issue.record("Expected .bitrateRecommendation case")
        }
    }

    @Test("Statistics updated event carries snapshot")
    func statisticsUpdatedEvent() {
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 10_000,
            duration: 60.0,
            currentBitrate: 1_333.0,
            peakBitrate: 2_000.0,
            reconnectionCount: 1,
            timestamp: Date()
        )
        let event = TransportEvent.statisticsUpdated(snapshot)
        if case .statisticsUpdated(let s) = event {
            #expect(s.bytesSent == 10_000)
        } else {
            Issue.record("Expected .statisticsUpdated case")
        }
    }

    @Test("Recording state changed event carries state")
    func recordingStateChangedEvent() {
        let state = TransportRecordingState(
            isRecording: true,
            bytesWritten: 2048,
            duration: 30.0,
            currentFilePath: "/tmp/rec.ts"
        )
        let event = TransportEvent.recordingStateChanged(state)
        if case .recordingStateChanged(let s) = event {
            #expect(s.isRecording)
            #expect(s.bytesWritten == 2048)
        } else {
            Issue.record("Expected .recordingStateChanged case")
        }
    }

    // MARK: - Sendable

    @Test("Sendable conformance in async context")
    func sendableInAsyncContext() async {
        let event = TransportEvent.connected(transportType: "SRT")
        let task = Task { event }
        let result = await task.value
        if case .connected(let type) = result {
            #expect(type == "SRT")
        } else {
            Issue.record("Expected .connected case")
        }
    }
}
