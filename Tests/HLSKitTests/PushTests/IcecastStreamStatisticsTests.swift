// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("IcecastStreamStatistics — Stream Metrics")
struct IcecastStreamStatisticsTests {

    @Test("Init stores all properties")
    func initStoresAllProperties() {
        let stats = IcecastStreamStatistics(
            bytesSent: 1_000_000,
            duration: 300.0,
            currentBitrate: 128_000.0,
            metadataUpdateCount: 5,
            reconnectionCount: 1
        )
        #expect(stats.bytesSent == 1_000_000)
        #expect(stats.duration == 300.0)
        #expect(stats.currentBitrate == 128_000.0)
        #expect(stats.metadataUpdateCount == 5)
        #expect(stats.reconnectionCount == 1)
    }

    @Test("Equatable — equal values")
    func equatableEqual() {
        let a = IcecastStreamStatistics(
            bytesSent: 500,
            duration: 10.0,
            currentBitrate: 64_000.0,
            metadataUpdateCount: 2,
            reconnectionCount: 0
        )
        let b = IcecastStreamStatistics(
            bytesSent: 500,
            duration: 10.0,
            currentBitrate: 64_000.0,
            metadataUpdateCount: 2,
            reconnectionCount: 0
        )
        #expect(a == b)
    }

    @Test("Equatable — different values")
    func equatableNotEqual() {
        let a = IcecastStreamStatistics(
            bytesSent: 500,
            duration: 10.0,
            currentBitrate: 64_000.0,
            metadataUpdateCount: 2,
            reconnectionCount: 0
        )
        let b = IcecastStreamStatistics(
            bytesSent: 1000,
            duration: 20.0,
            currentBitrate: 128_000.0,
            metadataUpdateCount: 3,
            reconnectionCount: 1
        )
        #expect(a != b)
    }

    @Test("toTransportStatisticsSnapshot conversion")
    func toTransportStatisticsSnapshot() {
        let date = Date()
        let stats = IcecastStreamStatistics(
            bytesSent: 2_000_000,
            duration: 600.0,
            currentBitrate: 128_000.0,
            metadataUpdateCount: 10,
            reconnectionCount: 2
        )
        let snapshot = stats.toTransportStatisticsSnapshot(
            peakBitrate: 192_000.0, timestamp: date
        )
        #expect(snapshot.bytesSent == 2_000_000)
        #expect(snapshot.duration == 600.0)
        #expect(snapshot.currentBitrate == 128_000.0)
        #expect(snapshot.peakBitrate == 192_000.0)
        #expect(snapshot.reconnectionCount == 2)
        #expect(snapshot.timestamp == date)
    }

    @Test("toTransportStatisticsSnapshot uses currentBitrate as peakBitrate when nil")
    func toSnapshotDefaultPeakBitrate() {
        let stats = IcecastStreamStatistics(
            bytesSent: 100,
            duration: 1.0,
            currentBitrate: 96_000.0,
            metadataUpdateCount: 0,
            reconnectionCount: 0
        )
        let snapshot = stats.toTransportStatisticsSnapshot()
        #expect(snapshot.peakBitrate == 96_000.0)
    }

    @Test("Zero/empty state")
    func zeroState() {
        let stats = IcecastStreamStatistics(
            bytesSent: 0,
            duration: 0.0,
            currentBitrate: 0.0,
            metadataUpdateCount: 0,
            reconnectionCount: 0
        )
        #expect(stats.bytesSent == 0)
        #expect(stats.duration == 0.0)
        #expect(stats.currentBitrate == 0.0)
    }

    @Test("Sendable conformance in async context")
    func sendableConformance() async {
        let stats = IcecastStreamStatistics(
            bytesSent: 5000,
            duration: 30.0,
            currentBitrate: 128_000.0,
            metadataUpdateCount: 1,
            reconnectionCount: 0
        )
        let result = await Task { stats }.value
        #expect(result.bytesSent == 5000)
    }
}
