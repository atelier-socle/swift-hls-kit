// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Transport Quality Showcase

@Suite("Transport Quality Showcase — Quality Monitoring & ABR")
struct TransportQualityShowcaseTests {

    // MARK: - Quality Score & Grade

    @Test("Excellent quality — score 0.95 yields .excellent grade")
    func excellentQualityGrade() {
        let now = Date()
        let quality = TransportQuality(
            score: 0.95,
            grade: .excellent,
            recommendation: nil,
            timestamp: now
        )

        #expect(quality.score == 0.95)
        #expect(quality.grade == .excellent)
        #expect(quality.recommendation == nil)
        #expect(quality.timestamp == now)
    }

    @Test("Critical quality — score 0.2 yields .critical grade")
    func criticalQualityGrade() {
        let quality = TransportQuality(
            score: 0.2,
            grade: .critical,
            recommendation: "Consider reducing bitrate",
            timestamp: Date()
        )

        #expect(quality.score == 0.2)
        #expect(quality.grade == .critical)
        #expect(quality.recommendation == "Consider reducing bitrate")
    }

    @Test("TransportQualityGrade.init(score:) maps all ranges correctly")
    func gradeFromScoreRanges() {
        // >0.9 = excellent
        #expect(TransportQualityGrade(score: 0.95) == .excellent)
        #expect(TransportQualityGrade(score: 0.91) == .excellent)

        // >0.7 = good
        #expect(TransportQualityGrade(score: 0.85) == .good)
        #expect(TransportQualityGrade(score: 0.71) == .good)

        // >0.5 = fair
        #expect(TransportQualityGrade(score: 0.65) == .fair)
        #expect(TransportQualityGrade(score: 0.51) == .fair)

        // >0.3 = poor
        #expect(TransportQualityGrade(score: 0.45) == .poor)
        #expect(TransportQualityGrade(score: 0.31) == .poor)

        // <=0.3 = critical
        #expect(TransportQualityGrade(score: 0.3) == .critical)
        #expect(TransportQualityGrade(score: 0.1) == .critical)
        #expect(TransportQualityGrade(score: 0.0) == .critical)

        // Boundary values
        #expect(TransportQualityGrade(score: 0.9) == .good)
        #expect(TransportQualityGrade(score: 0.7) == .fair)
        #expect(TransportQualityGrade(score: 0.5) == .poor)
    }

    @Test("TransportQualityGrade is Comparable — critical < poor < fair < good < excellent")
    func gradeComparable() {
        #expect(TransportQualityGrade.critical < .poor)
        #expect(TransportQualityGrade.poor < .fair)
        #expect(TransportQualityGrade.fair < .good)
        #expect(TransportQualityGrade.good < .excellent)

        // Transitive ordering
        #expect(TransportQualityGrade.critical < .excellent)
        #expect(TransportQualityGrade.excellent > .critical)

        // Equality
        #expect(TransportQualityGrade.fair >= .fair)
        #expect(TransportQualityGrade.fair <= .fair)
    }

    // MARK: - Bitrate Recommendation

    @Test("TransportBitrateRecommendation with .decrease direction")
    func bitrateRecommendationDecrease() {
        let now = Date()
        let recommendation = TransportBitrateRecommendation(
            recommendedBitrate: 2_000_000,
            currentEstimatedBitrate: 3_500_000,
            direction: .decrease,
            reason: "Congestion detected on RTMP link",
            confidence: 0.87,
            timestamp: now
        )

        #expect(recommendation.recommendedBitrate == 2_000_000)
        #expect(recommendation.currentEstimatedBitrate == 3_500_000)
        #expect(recommendation.direction == .decrease)
        #expect(recommendation.reason == "Congestion detected on RTMP link")
        #expect(recommendation.confidence == 0.87)
        #expect(recommendation.timestamp == now)

        // Verify all direction cases exist
        #expect(TransportBitrateRecommendation.Direction.allCases.count == 3)
        #expect(TransportBitrateRecommendation.Direction.increase.rawValue == "increase")
        #expect(TransportBitrateRecommendation.Direction.decrease.rawValue == "decrease")
        #expect(TransportBitrateRecommendation.Direction.maintain.rawValue == "maintain")
    }

    // MARK: - Statistics Snapshot

    @Test("TransportStatisticsSnapshot captures transport metrics")
    func statisticsSnapshot() {
        let now = Date()
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 52_428_800,
            duration: 120.5,
            currentBitrate: 3_500_000.0,
            peakBitrate: 4_200_000.0,
            reconnectionCount: 1,
            timestamp: now
        )

        #expect(snapshot.bytesSent == 52_428_800)
        #expect(snapshot.duration == 120.5)
        #expect(snapshot.currentBitrate == 3_500_000.0)
        #expect(snapshot.peakBitrate == 4_200_000.0)
        #expect(snapshot.reconnectionCount == 1)
        #expect(snapshot.timestamp == now)
    }

    // MARK: - Recording State

    @Test("TransportRecordingState tracks active recording")
    func recordingStateActive() {
        let state = TransportRecordingState(
            isRecording: true,
            bytesWritten: 10_485_760,
            duration: 45.0,
            currentFilePath: "/tmp/recording_001.ts"
        )

        #expect(state.isRecording == true)
        #expect(state.bytesWritten == 10_485_760)
        #expect(state.duration == 45.0)
        #expect(state.currentFilePath == "/tmp/recording_001.ts")

        // Inactive recording has nil path
        let idle = TransportRecordingState(
            isRecording: false,
            bytesWritten: 0,
            duration: 0,
            currentFilePath: nil
        )

        #expect(idle.isRecording == false)
        #expect(idle.currentFilePath == nil)
    }

    // MARK: - Transport Events

    @Test("TransportEvent covers all event cases via switch")
    func transportEventCases() {
        let now = Date()

        let quality = TransportQuality(
            score: 0.8,
            grade: .good,
            recommendation: nil,
            timestamp: now
        )
        let recommendation = TransportBitrateRecommendation(
            recommendedBitrate: 3_000_000,
            currentEstimatedBitrate: 3_500_000,
            direction: .maintain,
            reason: "Stable",
            confidence: 0.9,
            timestamp: now
        )
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 1024,
            duration: 10.0,
            currentBitrate: 2_000_000.0,
            peakBitrate: 2_000_000.0,
            reconnectionCount: 0,
            timestamp: now
        )
        let recording = TransportRecordingState(
            isRecording: true,
            bytesWritten: 512,
            duration: 5.0,
            currentFilePath: "/tmp/rec.ts"
        )

        let events: [TransportEvent] = [
            .connected(transportType: "RTMP"),
            .disconnected(transportType: "SRT", error: nil),
            .reconnecting(transportType: "Icecast", attempt: 2),
            .qualityChanged(quality),
            .bitrateRecommendation(recommendation),
            .statisticsUpdated(snapshot),
            .recordingStateChanged(recording)
        ]

        #expect(events.count == 7)

        for event in events {
            switch event {
            case .connected(let transportType):
                #expect(transportType == "RTMP")
            case .disconnected(let transportType, let error):
                #expect(transportType == "SRT")
                #expect(error == nil)
            case .reconnecting(let transportType, let attempt):
                #expect(transportType == "Icecast")
                #expect(attempt == 2)
            case .qualityChanged(let q):
                #expect(q.grade == .good)
            case .bitrateRecommendation(let r):
                #expect(r.direction == .maintain)
            case .statisticsUpdated(let s):
                #expect(s.bytesSent == 1024)
            case .recordingStateChanged(let r):
                #expect(r.isRecording == true)
            }
        }
    }

    // MARK: - Protocol Conformance

    @Test("Mock struct conforms to QualityAwareTransport, AdaptiveBitrateTransport, RecordingTransport")
    func protocolConformanceMock() async throws {
        let mock = MockQualityTransport()

        // QualityAwareTransport
        let quality = await mock.connectionQuality
        let qualityValue = try #require(quality)
        #expect(qualityValue.grade == .excellent)

        let stats = await mock.statisticsSnapshot
        let statsValue = try #require(stats)
        #expect(statsValue.bytesSent == 0)

        // AdaptiveBitrateTransport — stream exists
        _ = mock.bitrateRecommendations

        // RecordingTransport
        let recordingState = await mock.recordingState
        #expect(recordingState == nil)
    }
}

// MARK: - Mock Transport

/// Mock transport conforming to all three quality-aware protocols.
private actor MockQualityTransport:
    QualityAwareTransport,
    AdaptiveBitrateTransport,
    RecordingTransport
{

    var connectionQuality: TransportQuality? {
        TransportQuality(
            score: 0.95,
            grade: .excellent,
            recommendation: nil,
            timestamp: Date()
        )
    }

    nonisolated var transportEvents: AsyncStream<TransportEvent> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    var statisticsSnapshot: TransportStatisticsSnapshot? {
        TransportStatisticsSnapshot(
            bytesSent: 0,
            duration: 0,
            currentBitrate: 0,
            peakBitrate: 0,
            reconnectionCount: 0,
            timestamp: Date()
        )
    }

    nonisolated var bitrateRecommendations: AsyncStream<TransportBitrateRecommendation> {
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    var recordingState: TransportRecordingState? {
        nil
    }

    func startRecording(directory: String) async throws {
        // No-op for mock
    }

    func stopRecording() async throws {
        // No-op for mock
    }
}
