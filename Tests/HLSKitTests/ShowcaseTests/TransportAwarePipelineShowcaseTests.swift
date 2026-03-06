// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Transport-Aware Pipeline Showcase

@Suite("Transport-Aware Pipeline Showcase — Policy, Health & Events")
struct TransportAwarePipelineShowcaseTests {

    // MARK: - Policy Presets

    @Test("Default policy enables auto-adjust with responsive ABR")
    func defaultPolicy() {
        let policy = TransportAwarePipelinePolicy.default

        #expect(policy.autoAdjustBitrate == true)
        #expect(policy.minimumQualityGrade == .poor)
        #expect(policy.abrResponsiveness == .responsive)
    }

    @Test("Disabled policy turns off auto-adjust with conservative ABR")
    func disabledPolicy() {
        let policy = TransportAwarePipelinePolicy.disabled

        #expect(policy.autoAdjustBitrate == false)
        #expect(policy.minimumQualityGrade == .critical)
        #expect(policy.abrResponsiveness == .conservative)
    }

    // MARK: - ABR Responsiveness

    @Test("ABRResponsiveness has three levels: conservative, responsive, immediate")
    func abrResponsivenessLevels() {
        let allCases = TransportAwarePipelinePolicy.ABRResponsiveness.allCases

        #expect(allCases.count == 3)
        #expect(allCases.contains(.conservative))
        #expect(allCases.contains(.responsive))
        #expect(allCases.contains(.immediate))

        // Verify raw values are meaningful strings.
        #expect(
            TransportAwarePipelinePolicy.ABRResponsiveness.conservative.rawValue
                == "conservative"
        )
        #expect(
            TransportAwarePipelinePolicy.ABRResponsiveness.responsive.rawValue
                == "responsive"
        )
        #expect(
            TransportAwarePipelinePolicy.ABRResponsiveness.immediate.rawValue
                == "immediate"
        )
    }

    // MARK: - Health Dashboard (Mixed)

    @Test(
        "Health dashboard with mixed destinations reports correct counts and critical overall grade"
    )
    func mixedDestinationsDashboard() {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let rtmpHealth = TransportDestinationHealth(
            label: "Twitch",
            transportType: "RTMP",
            quality: TransportQuality(
                score: 0.95,
                grade: .excellent,
                recommendation: nil,
                timestamp: timestamp
            ),
            connectionState: .connected,
            statistics: TransportStatisticsSnapshot(
                bytesSent: 10_000_000,
                duration: 600.0,
                currentBitrate: 3_500_000,
                peakBitrate: 4_000_000,
                reconnectionCount: 0,
                timestamp: timestamp
            )
        )

        let srtHealth = TransportDestinationHealth(
            label: "SRT-Backup",
            transportType: "SRT",
            quality: TransportQuality(
                score: 0.6,
                grade: .fair,
                recommendation: "Reduce bitrate",
                timestamp: timestamp
            ),
            connectionState: .connected,
            statistics: nil
        )

        let icecastHealth = TransportDestinationHealth(
            label: "Icecast-Radio",
            transportType: "Icecast",
            quality: nil,
            connectionState: .disconnected,
            statistics: nil
        )

        let dashboard = TransportHealthDashboard(
            destinations: [rtmpHealth, srtHealth, icecastHealth]
        )

        #expect(dashboard.destinations.count == 3)
        #expect(dashboard.healthyCount == 1)
        #expect(dashboard.degradedCount == 1)
        #expect(dashboard.failedCount == 1)
        #expect(dashboard.overallGrade == .critical)
    }

    // MARK: - Health Dashboard (All Healthy)

    @Test("Health dashboard with all healthy destinations reports good or better overall grade")
    func allHealthyDashboard() {
        let timestamp = Date()

        let dest1 = TransportDestinationHealth(
            label: "YouTube",
            transportType: "RTMP",
            quality: TransportQuality(
                score: 0.92,
                grade: .excellent,
                recommendation: nil,
                timestamp: timestamp
            ),
            connectionState: .connected,
            statistics: nil
        )

        let dest2 = TransportDestinationHealth(
            label: "Backup-SRT",
            transportType: "SRT",
            quality: TransportQuality(
                score: 0.85,
                grade: .good,
                recommendation: nil,
                timestamp: timestamp
            ),
            connectionState: .connected,
            statistics: nil
        )

        let dashboard = TransportHealthDashboard(
            destinations: [dest1, dest2]
        )

        #expect(dashboard.healthyCount == 2)
        #expect(dashboard.degradedCount == 0)
        #expect(dashboard.failedCount == 0)
        #expect(dashboard.overallGrade >= .good)
    }

    // MARK: - Pipeline Configuration Integration

    @Test("LivePipelineConfiguration accepts transport policy")
    func pipelineConfigWithTransportPolicy() {
        var config = LivePipelineConfiguration()
        #expect(config.transportPolicy == nil)

        config.transportPolicy = .default
        #expect(config.transportPolicy?.autoAdjustBitrate == true)
        #expect(config.transportPolicy?.abrResponsiveness == .responsive)

        // Custom policy.
        let custom = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .fair,
            abrResponsiveness: .immediate
        )
        config.transportPolicy = custom
        #expect(config.transportPolicy?.minimumQualityGrade == .fair)
        #expect(config.transportPolicy?.abrResponsiveness == .immediate)
    }

    // MARK: - Pipeline Events

    @Test("LivePipelineEvent.transportQualityDegraded carries destination and quality")
    func transportQualityDegradedEvent() {
        let quality = TransportQuality(
            score: 0.25,
            grade: .critical,
            recommendation: "Switch to backup",
            timestamp: Date()
        )
        let event = LivePipelineEvent.transportQualityDegraded(
            destination: "Primary-RTMP",
            quality: quality
        )

        if case let .transportQualityDegraded(dest, q) = event {
            #expect(dest == "Primary-RTMP")
            #expect(q.score == 0.25)
            #expect(q.grade == .critical)
            #expect(q.recommendation == "Switch to backup")
        } else {
            Issue.record("Expected .transportQualityDegraded event")
        }
    }

    @Test("LivePipelineEvent.transportBitrateAdjusted carries old/new bitrate and reason")
    func transportBitrateAdjustedEvent() {
        let event = LivePipelineEvent.transportBitrateAdjusted(
            oldBitrate: 3_500_000,
            newBitrate: 2_000_000,
            reason: "Transport quality below threshold"
        )

        if case let .transportBitrateAdjusted(old, new, reason) = event {
            #expect(old == 3_500_000)
            #expect(new == 2_000_000)
            #expect(reason == "Transport quality below threshold")
        } else {
            Issue.record("Expected .transportBitrateAdjusted event")
        }
    }

    @Test("LivePipelineEvent.transportDestinationFailed carries destination and error")
    func transportDestinationFailedEvent() {
        let event = LivePipelineEvent.transportDestinationFailed(
            destination: "Icecast-Main",
            error: "Connection refused: ECONNREFUSED"
        )

        if case let .transportDestinationFailed(dest, err) = event {
            #expect(dest == "Icecast-Main")
            #expect(err == "Connection refused: ECONNREFUSED")
        } else {
            Issue.record("Expected .transportDestinationFailed event")
        }
    }

    @Test("LivePipelineEvent.transportHealthUpdate carries a full dashboard")
    func transportHealthUpdateEvent() {
        let dashboard = TransportHealthDashboard(destinations: [])
        let event = LivePipelineEvent.transportHealthUpdate(dashboard)

        if case let .transportHealthUpdate(d) = event {
            #expect(d.destinations.isEmpty)
            #expect(d.overallGrade == .critical)
            #expect(d.healthyCount == 0)
        } else {
            Issue.record("Expected .transportHealthUpdate event")
        }
    }
}
