// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "TransportHealthDashboard",
    .timeLimit(.minutes(1))
)
struct TransportHealthDashboardTests {

    // MARK: - Helpers

    private func makeHealth(
        label: String = "Test",
        transportType: String = "RTMP",
        grade: TransportQualityGrade = .excellent,
        state: PushConnectionState = .connected,
        hasStats: Bool = false
    ) -> TransportDestinationHealth {
        let quality = TransportQuality(
            score: 0.95,
            grade: grade,
            recommendation: nil,
            timestamp: Date()
        )
        let stats: TransportStatisticsSnapshot? =
            hasStats
            ? TransportStatisticsSnapshot(
                bytesSent: 1000,
                duration: 60.0,
                currentBitrate: 128_000,
                peakBitrate: 256_000,
                reconnectionCount: 0,
                timestamp: Date()
            ) : nil
        return TransportDestinationHealth(
            label: label,
            transportType: transportType,
            quality: quality,
            connectionState: state,
            statistics: stats
        )
    }

    // MARK: - All Healthy

    @Test("All healthy destinations")
    func allHealthy() {
        let dashboard = TransportHealthDashboard(
            destinations: [
                makeHealth(label: "Twitch", grade: .excellent),
                makeHealth(label: "YouTube", grade: .good)
            ]
        )
        #expect(dashboard.overallGrade == .good)
        #expect(dashboard.healthyCount == 2)
        #expect(dashboard.degradedCount == 0)
        #expect(dashboard.failedCount == 0)
    }

    // MARK: - Mixed Destinations

    @Test("Mixed destinations — correct counts and worst-case grade")
    func mixedDestinations() {
        let dashboard = TransportHealthDashboard(
            destinations: [
                makeHealth(label: "Twitch", grade: .excellent),
                makeHealth(label: "YouTube", grade: .fair),
                makeHealth(
                    label: "SRT", grade: .critical,
                    state: .connected
                )
            ]
        )
        #expect(dashboard.overallGrade == .critical)
        #expect(dashboard.healthyCount == 1)
        #expect(dashboard.degradedCount == 1)
        #expect(dashboard.failedCount == 1)
    }

    // MARK: - All Failed

    @Test("All failed destinations")
    func allFailed() {
        let dashboard = TransportHealthDashboard(
            destinations: [
                makeHealth(
                    label: "A", grade: .critical,
                    state: .failed
                ),
                makeHealth(
                    label: "B", grade: .critical,
                    state: .disconnected
                )
            ]
        )
        #expect(dashboard.overallGrade == .critical)
        #expect(dashboard.healthyCount == 0)
        #expect(dashboard.degradedCount == 0)
        #expect(dashboard.failedCount == 2)
    }

    // MARK: - Empty Destinations

    @Test("Empty destinations array")
    func emptyDestinations() {
        let dashboard = TransportHealthDashboard(destinations: [])
        #expect(dashboard.overallGrade == .critical)
        #expect(dashboard.healthyCount == 0)
        #expect(dashboard.degradedCount == 0)
        #expect(dashboard.failedCount == 0)
    }

    // MARK: - Single Destination

    @Test("Single destination")
    func singleDestination() {
        let dashboard = TransportHealthDashboard(
            destinations: [
                makeHealth(label: "Twitch", grade: .good)
            ]
        )
        #expect(dashboard.overallGrade == .good)
        #expect(dashboard.healthyCount == 1)
        #expect(dashboard.degradedCount == 0)
        #expect(dashboard.failedCount == 0)
    }

    // MARK: - TransportDestinationHealth

    @Test("TransportDestinationHealth init with all params")
    func destinationHealthInit() {
        let quality = TransportQuality(
            score: 0.75,
            grade: .good,
            recommendation: "stable",
            timestamp: Date()
        )
        let stats = TransportStatisticsSnapshot(
            bytesSent: 5000,
            duration: 30.0,
            currentBitrate: 128_000,
            peakBitrate: 192_000,
            reconnectionCount: 1,
            timestamp: Date()
        )
        let health = TransportDestinationHealth(
            label: "Twitch",
            transportType: "RTMP",
            quality: quality,
            connectionState: .connected,
            statistics: stats
        )
        #expect(health.label == "Twitch")
        #expect(health.transportType == "RTMP")
        #expect(health.quality?.score == 0.75)
        #expect(health.connectionState == .connected)
        #expect(health.statistics?.bytesSent == 5000)
    }

    @Test("TransportDestinationHealth with nil quality")
    func destinationHealthNilQuality() {
        let health = TransportDestinationHealth(
            label: "SRT-Backup",
            transportType: "SRT",
            quality: nil,
            connectionState: .connecting,
            statistics: nil
        )
        #expect(health.quality == nil)
        #expect(health.connectionState == .connecting)
    }

    @Test("TransportDestinationHealth with nil statistics")
    func destinationHealthNilStats() {
        let quality = TransportQuality(
            score: 0.9,
            grade: .good,
            recommendation: nil,
            timestamp: Date()
        )
        let health = TransportDestinationHealth(
            label: "Icecast",
            transportType: "Icecast",
            quality: quality,
            connectionState: .connected,
            statistics: nil
        )
        #expect(health.statistics == nil)
        #expect(health.quality != nil)
    }

    // MARK: - Equatable

    @Test("Dashboard Equatable conformance")
    func dashboardEquatable() {
        let a = TransportHealthDashboard(destinations: [])
        let b = TransportHealthDashboard(destinations: [])
        #expect(a == b)
    }

    @Test("DestinationHealth Equatable conformance")
    func destinationHealthEquatable() {
        let now = Date()
        let quality = TransportQuality(
            score: 0.8, grade: .good,
            recommendation: nil, timestamp: now
        )
        let a = TransportDestinationHealth(
            label: "A", transportType: "RTMP",
            quality: quality,
            connectionState: .connected,
            statistics: nil
        )
        let b = TransportDestinationHealth(
            label: "A", transportType: "RTMP",
            quality: quality,
            connectionState: .connected,
            statistics: nil
        )
        #expect(a == b)
    }

    // MARK: - Grade Computation

    @Test("Disconnected destination counts as failed")
    func disconnectedCountsAsFailed() {
        let dashboard = TransportHealthDashboard(
            destinations: [
                makeHealth(
                    label: "A", grade: .excellent,
                    state: .disconnected
                )
            ]
        )
        #expect(dashboard.failedCount == 1)
        #expect(dashboard.overallGrade == .critical)
    }

    @Test("Critical quality counts as failed")
    func criticalQualityCountsAsFailed() {
        let dashboard = TransportHealthDashboard(
            destinations: [
                makeHealth(
                    label: "A", grade: .critical,
                    state: .connected
                )
            ]
        )
        #expect(dashboard.failedCount == 1)
    }

    @Test("Fair and poor count as degraded")
    func fairAndPoorAreDegraded() {
        let dashboard = TransportHealthDashboard(
            destinations: [
                makeHealth(label: "A", grade: .fair),
                makeHealth(label: "B", grade: .poor)
            ]
        )
        #expect(dashboard.degradedCount == 2)
        #expect(dashboard.healthyCount == 0)
        #expect(dashboard.failedCount == 0)
    }

    @Test("Reconnecting with no quality uses poor grade")
    func reconnectingNoQuality() {
        let health = TransportDestinationHealth(
            label: "A",
            transportType: "SRT",
            quality: nil,
            connectionState: .reconnecting,
            statistics: nil
        )
        let dashboard = TransportHealthDashboard(
            destinations: [health]
        )
        #expect(dashboard.degradedCount == 1)
    }
}
