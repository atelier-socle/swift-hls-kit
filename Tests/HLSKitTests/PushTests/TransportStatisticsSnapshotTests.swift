// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TransportStatisticsSnapshot — Transport Statistics")
struct TransportStatisticsSnapshotTests {

    // MARK: - Init

    @Test("Init stores all parameters")
    func initStoresAllParameters() {
        let now = Date()
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 1_000_000,
            duration: 3600.0,
            currentBitrate: 2_000_000.0,
            peakBitrate: 3_500_000.0,
            reconnectionCount: 2,
            timestamp: now
        )
        #expect(snapshot.bytesSent == 1_000_000)
        #expect(snapshot.duration == 3600.0)
        #expect(snapshot.currentBitrate == 2_000_000.0)
        #expect(snapshot.peakBitrate == 3_500_000.0)
        #expect(snapshot.reconnectionCount == 2)
        #expect(snapshot.timestamp == now)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatableConformance() {
        let now = Date()
        let a = TransportStatisticsSnapshot(
            bytesSent: 500,
            duration: 10.0,
            currentBitrate: 400.0,
            peakBitrate: 600.0,
            reconnectionCount: 0,
            timestamp: now
        )
        let b = TransportStatisticsSnapshot(
            bytesSent: 500,
            duration: 10.0,
            currentBitrate: 400.0,
            peakBitrate: 600.0,
            reconnectionCount: 0,
            timestamp: now
        )
        #expect(a == b)
    }

    // MARK: - Edge Cases

    @Test("Zero state snapshot")
    func zeroState() {
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 0,
            duration: 0,
            currentBitrate: 0,
            peakBitrate: 0,
            reconnectionCount: 0,
            timestamp: Date()
        )
        #expect(snapshot.bytesSent == 0)
        #expect(snapshot.reconnectionCount == 0)
    }

    @Test("Realistic long streaming session")
    func realisticLongSession() {
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 54_000_000_000,
            duration: 36000.0,
            currentBitrate: 12_000_000.0,
            peakBitrate: 15_000_000.0,
            reconnectionCount: 5,
            timestamp: Date()
        )
        #expect(snapshot.bytesSent == 54_000_000_000)
        #expect(snapshot.duration == 36000.0)
    }

    @Test("Peak bitrate can equal current bitrate")
    func peakEqualsCurrentBitrate() {
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 1000,
            duration: 1.0,
            currentBitrate: 8000.0,
            peakBitrate: 8000.0,
            reconnectionCount: 0,
            timestamp: Date()
        )
        #expect(snapshot.peakBitrate == snapshot.currentBitrate)
    }

    @Test("Sendable conformance in async context")
    func sendableInAsyncContext() async {
        let snapshot = TransportStatisticsSnapshot(
            bytesSent: 42,
            duration: 1.0,
            currentBitrate: 336.0,
            peakBitrate: 336.0,
            reconnectionCount: 0,
            timestamp: Date()
        )
        let task = Task { snapshot }
        let result = await task.value
        #expect(result.bytesSent == 42)
    }
}
