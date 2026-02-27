// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("BandwidthMonitor", .timeLimit(.minutes(1)))
struct BandwidthMonitorTests {

    // MARK: - Initial State

    @Test("Initial state: 0 bandwidth, sufficient, no alert")
    func initialState() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 5_000_000)
        )
        let bps = await monitor.estimatedBandwidthBps
        #expect(bps == 0)
        let sufficient = await monitor.isSufficient
        #expect(sufficient)
        let alert = await monitor.currentAlert
        #expect(alert == nil)
        let total = await monitor.totalBytesMonitored
        #expect(total == 0)
        let count = await monitor.sampleCount
        #expect(count == 0)
    }

    // MARK: - Recording

    @Test("Record single push estimates bandwidth")
    func singlePush() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 1_000_000)
        )
        await monitor.recordPush(bytes: 125_000, duration: 1.0)
        let bps = await monitor.estimatedBandwidthBps
        #expect(bps == 1_000_000)
        let total = await monitor.totalBytesMonitored
        #expect(total == 125_000)
        let count = await monitor.sampleCount
        #expect(count == 1)
    }

    @Test("Multiple pushes calculate sliding window average")
    func multiplePushes() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 1_000_000)
        )
        await monitor.recordPush(bytes: 100_000, duration: 0.5)
        await monitor.recordPush(bytes: 100_000, duration: 0.5)
        let bps = await monitor.estimatedBandwidthBps
        #expect(bps == 1_600_000)
    }

    @Test("totalBytesMonitored accumulates")
    func totalAccumulates() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 1_000_000)
        )
        await monitor.recordPush(bytes: 1000, duration: 0.1)
        await monitor.recordPush(bytes: 2000, duration: 0.2)
        let total = await monitor.totalBytesMonitored
        #expect(total == 3000)
    }

    @Test("sampleCount tracks correctly")
    func sampleCountTracks() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 1_000_000)
        )
        for _ in 0..<5 {
            await monitor.recordPush(bytes: 1000, duration: 0.1)
        }
        let count = await monitor.sampleCount
        #expect(count == 5)
    }

    @Test("Zero duration handled gracefully")
    func zeroDuration() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 1_000_000)
        )
        await monitor.recordPush(bytes: 1000, duration: 0.0)
        let bps = await monitor.estimatedBandwidthBps
        #expect(bps > 0)
    }

    @Test("Large byte count does not overflow")
    func largeByteCount() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 1_000_000)
        )
        await monitor.recordPush(bytes: 1_000_000_000, duration: 1.0)
        let total = await monitor.totalBytesMonitored
        #expect(total == 1_000_000_000)
    }

    // MARK: - Alert State Machine

    @Test("Insufficient bandwidth fires alert")
    func insufficientAlert() async {
        let alerts = LockedState(
            initialState: [BandwidthMonitor.BandwidthAlert]()
        )
        let config = BandwidthMonitor.Configuration(
            windowDuration: 10,
            requiredBitrate: 10_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 2
        )
        let monitor = BandwidthMonitor(configuration: config)
        await monitor.setOnBandwidthAlert { alert in
            alerts.withLock { $0.append(alert) }
        }

        await monitor.recordPush(bytes: 100_000, duration: 0.1)
        await monitor.recordPush(bytes: 100_000, duration: 0.1)

        let sufficient = await monitor.isSufficient
        #expect(!sufficient)
        let count = alerts.withLock { $0.count }
        #expect(count == 1)
        let first = alerts.withLock { $0.first }
        if case .insufficient = first {
            // Expected
        } else {
            Issue.record("Expected insufficient alert")
        }
    }

    @Test("Critical bandwidth fires critical alert")
    func criticalAlert() async {
        let alerts = LockedState(
            initialState: [BandwidthMonitor.BandwidthAlert]()
        )
        let config = BandwidthMonitor.Configuration(
            windowDuration: 10,
            requiredBitrate: 10_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 2
        )
        let monitor = BandwidthMonitor(configuration: config)
        await monitor.setOnBandwidthAlert { alert in
            alerts.withLock { $0.append(alert) }
        }

        await monitor.recordPush(bytes: 37_500, duration: 1.0)
        await monitor.recordPush(bytes: 37_500, duration: 1.0)

        let alert = await monitor.currentAlert
        if case .critical = alert {
            // Expected
        } else {
            Issue.record(
                "Expected critical, got: \(String(describing: alert))"
            )
        }
    }

    @Test("Recovery fires recovered alert")
    func recoveryAlert() async {
        let alerts = LockedState(
            initialState: [BandwidthMonitor.BandwidthAlert]()
        )
        let config = BandwidthMonitor.Configuration(
            windowDuration: 60,
            requiredBitrate: 1_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 1
        )
        let monitor = BandwidthMonitor(configuration: config)
        await monitor.setOnBandwidthAlert { alert in
            alerts.withLock { $0.append(alert) }
        }

        await monitor.recordPush(bytes: 10_000, duration: 1.0)
        await monitor.recordPush(bytes: 500_000, duration: 1.0)

        let hasRecovered = alerts.withLock { list in
            list.contains {
                if case .recovered = $0 { return true }
                return false
            }
        }
        #expect(hasRecovered)
    }

    @Test("Alert only fires on transitions")
    func alertOnTransitionsOnly() async {
        let alertCount = LockedState(initialState: 0)
        let config = BandwidthMonitor.Configuration(
            windowDuration: 60,
            requiredBitrate: 10_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 1
        )
        let monitor = BandwidthMonitor(configuration: config)
        await monitor.setOnBandwidthAlert { _ in
            alertCount.withLock { $0 += 1 }
        }

        await monitor.recordPush(bytes: 10_000, duration: 1.0)
        await monitor.recordPush(bytes: 10_000, duration: 1.0)
        await monitor.recordPush(bytes: 10_000, duration: 1.0)

        let count = alertCount.withLock { $0 }
        #expect(count == 1)
    }

    @Test("Minimum samples prevents early alerts")
    func minimumSamples() async {
        let alertCount = LockedState(initialState: 0)
        let config = BandwidthMonitor.Configuration(
            windowDuration: 10,
            requiredBitrate: 10_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 3
        )
        let monitor = BandwidthMonitor(configuration: config)
        await monitor.setOnBandwidthAlert { _ in
            alertCount.withLock { $0 += 1 }
        }

        await monitor.recordPush(bytes: 1000, duration: 1.0)
        await monitor.recordPush(bytes: 1000, duration: 1.0)

        let beforeThird = alertCount.withLock { $0 }
        #expect(beforeThird == 0)

        await monitor.recordPush(bytes: 1000, duration: 1.0)
        let afterThird = alertCount.withLock { $0 }
        #expect(afterThird == 1)
    }

    // MARK: - Configuration Presets

    @Test("Standard configuration preset")
    func standardPreset() {
        let config = BandwidthMonitor.Configuration.standard(
            requiredBitrate: 5_000_000
        )
        #expect(config.windowDuration == 10)
        #expect(config.requiredBitrate == 5_000_000)
        #expect(config.alertThreshold == 0.9)
        #expect(config.criticalThreshold == 0.5)
        #expect(config.minimumSamples == 3)
    }

    @Test("Aggressive configuration preset")
    func aggressivePreset() {
        let config = BandwidthMonitor.Configuration.aggressive(
            requiredBitrate: 5_000_000
        )
        #expect(config.windowDuration == 5)
        #expect(config.alertThreshold == 0.95)
        #expect(config.minimumSamples == 2)
    }

    @Test("Conservative configuration preset")
    func conservativePreset() {
        let config = BandwidthMonitor.Configuration.conservative(
            requiredBitrate: 5_000_000
        )
        #expect(config.windowDuration == 30)
        #expect(config.alertThreshold == 0.8)
        #expect(config.criticalThreshold == 0.4)
        #expect(config.minimumSamples == 5)
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func resetClearsState() async {
        let monitor = BandwidthMonitor(
            configuration: .standard(requiredBitrate: 1_000_000)
        )
        await monitor.recordPush(bytes: 100_000, duration: 1.0)
        await monitor.recordPush(bytes: 100_000, duration: 1.0)

        await monitor.reset()

        let bps = await monitor.estimatedBandwidthBps
        #expect(bps == 0)
        let total = await monitor.totalBytesMonitored
        #expect(total == 0)
        let count = await monitor.sampleCount
        #expect(count == 0)
        let sufficient = await monitor.isSufficient
        #expect(sufficient)
    }

    // MARK: - isSufficient

    @Test("isSufficient reflects current state")
    func isSufficientReflects() async {
        let config = BandwidthMonitor.Configuration(
            windowDuration: 60,
            requiredBitrate: 1_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 1
        )
        let monitor = BandwidthMonitor(configuration: config)

        await monitor.recordPush(bytes: 500_000, duration: 1.0)
        let sufficient = await monitor.isSufficient
        #expect(sufficient)
    }
}

// MARK: - BandwidthMonitor helpers

extension BandwidthMonitor {

    func setOnBandwidthAlert(
        _ handler: @escaping @Sendable (BandwidthAlert) -> Void
    ) {
        onBandwidthAlert = handler
    }
}
