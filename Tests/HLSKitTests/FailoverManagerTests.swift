// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - FailoverManager

@Suite("FailoverManager — Failover Logic")
struct FailoverManagerTests {

    static let testConfig = RedundantStreamConfig(backups: [
        .init(
            primaryURI: "https://cdn-a.com/1080p.m3u8",
            backupURIs: [
                "https://cdn-b.com/1080p.m3u8",
                "https://cdn-c.com/1080p.m3u8"
            ]
        ),
        .init(
            primaryURI: "https://cdn-a.com/720p.m3u8",
            backupURIs: ["https://cdn-b.com/720p.m3u8"]
        )
    ])

    @Test("Init has no active failovers")
    func initClean() {
        let manager = FailoverManager(config: Self.testConfig)
        #expect(!manager.hasActiveFailovers)
        #expect(manager.activeFailoverCount == 0)
    }

    @Test("activeURI returns primary when no failure")
    func activeURIPrimary() {
        let manager = FailoverManager(config: Self.testConfig)
        let uri = manager.activeURI(for: "https://cdn-a.com/1080p.m3u8")
        #expect(uri == "https://cdn-a.com/1080p.m3u8")
    }

    @Test("reportFailure switches to first backup")
    func reportFailureSwitchesToBackup() {
        var manager = FailoverManager(config: Self.testConfig)
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        let uri = manager.activeURI(for: "https://cdn-a.com/1080p.m3u8")
        #expect(uri == "https://cdn-b.com/1080p.m3u8")
        #expect(manager.hasActiveFailovers)
    }

    @Test("Multiple failures cascade through backups")
    func cascadeFailures() {
        var manager = FailoverManager(config: Self.testConfig)
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        let uri = manager.activeURI(for: "https://cdn-a.com/1080p.m3u8")
        #expect(uri == "https://cdn-c.com/1080p.m3u8")
    }

    @Test("Failures past last backup stay on last backup")
    func failuresPastLastBackup() {
        var manager = FailoverManager(config: Self.testConfig)
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        let uri = manager.activeURI(for: "https://cdn-a.com/1080p.m3u8")
        #expect(uri == "https://cdn-c.com/1080p.m3u8")
    }

    @Test("reportRecovery switches back to primary")
    func reportRecovery() {
        var manager = FailoverManager(config: Self.testConfig)
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        manager.reportRecovery(for: "https://cdn-a.com/1080p.m3u8")
        let uri = manager.activeURI(for: "https://cdn-a.com/1080p.m3u8")
        #expect(uri == "https://cdn-a.com/1080p.m3u8")
        #expect(!manager.hasActiveFailovers)
    }

    @Test("activeFailoverCount tracks multiple failures")
    func activeFailoverCount() {
        var manager = FailoverManager(config: Self.testConfig)
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        manager.reportFailure(for: "https://cdn-a.com/720p.m3u8")
        #expect(manager.activeFailoverCount == 2)
    }

    @Test("Unknown primary URI returns itself")
    func unknownPrimary() {
        let manager = FailoverManager(config: Self.testConfig)
        let uri = manager.activeURI(for: "https://unknown.com/stream.m3u8")
        #expect(uri == "https://unknown.com/stream.m3u8")
    }

    @Test("Failure on unknown primary creates failure state but returns primary")
    func failureUnknownPrimary() {
        var manager = FailoverManager(config: Self.testConfig)
        manager.reportFailure(for: "https://unknown.com/stream.m3u8")
        #expect(manager.hasActiveFailovers)
        let uri = manager.activeURI(for: "https://unknown.com/stream.m3u8")
        #expect(uri == "https://unknown.com/stream.m3u8")
    }

    @Test("reset clears all failure states")
    func reset() {
        var manager = FailoverManager(config: Self.testConfig)
        manager.reportFailure(for: "https://cdn-a.com/1080p.m3u8")
        manager.reportFailure(for: "https://cdn-a.com/720p.m3u8")
        manager.reset()
        #expect(!manager.hasActiveFailovers)
        #expect(manager.activeFailoverCount == 0)
    }

    @Test("FailureState isOnBackup reflects state")
    func failureStateIsOnBackup() {
        let onBackup = FailoverManager.FailureState(
            primaryURI: "primary.m3u8",
            currentBackupIndex: 0,
            failureCount: 1,
            lastFailureTime: nil
        )
        #expect(onBackup.isOnBackup)

        let notOnBackup = FailoverManager.FailureState(
            primaryURI: "primary.m3u8",
            currentBackupIndex: -1,
            failureCount: 0,
            lastFailureTime: nil
        )
        #expect(!notOnBackup.isOnBackup)
    }
}
