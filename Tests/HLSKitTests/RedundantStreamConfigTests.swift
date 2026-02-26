// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - RedundantStreamConfig

@Suite("RedundantStreamConfig — Configuration")
struct RedundantStreamConfigTests {

    @Test("Default init has empty backups")
    func defaultInit() {
        let config = RedundantStreamConfig()
        #expect(config.backups.isEmpty)
        #expect(config.primaryRecoveryDelay == 30)
    }

    @Test("Custom init sets properties")
    func customInit() {
        let config = RedundantStreamConfig(
            backups: [
                .init(
                    primaryURI: "https://cdn-a.com/1080p.m3u8",
                    backupURIs: ["https://cdn-b.com/1080p.m3u8"]
                )
            ],
            primaryRecoveryDelay: 60
        )
        #expect(config.backups.count == 1)
        #expect(config.primaryRecoveryDelay == 60)
    }

    @Test("VariantBackup totalURIs counts primary plus backups")
    func variantBackupTotalURIs() {
        let backup = RedundantStreamConfig.VariantBackup(
            primaryURI: "primary.m3u8",
            backupURIs: ["backup1.m3u8", "backup2.m3u8"]
        )
        #expect(backup.totalURIs == 3)
    }

    @Test("totalBackupURIs sums all backup URIs")
    func totalBackupURIs() {
        let config = RedundantStreamConfig(backups: [
            .init(primaryURI: "a.m3u8", backupURIs: ["b.m3u8"]),
            .init(primaryURI: "c.m3u8", backupURIs: ["d.m3u8", "e.m3u8"])
        ])
        #expect(config.totalBackupURIs == 3)
    }

    @Test("Validate empty backupURIs")
    func validateEmptyBackups() {
        let config = RedundantStreamConfig(backups: [
            .init(primaryURI: "main.m3u8", backupURIs: [])
        ])
        let errors = config.validate()
        #expect(errors.contains { $0.contains("no backup URIs") })
    }

    @Test("Validate duplicate URIs")
    func validateDuplicateURIs() {
        let config = RedundantStreamConfig(backups: [
            .init(primaryURI: "a.m3u8", backupURIs: ["b.m3u8"]),
            .init(primaryURI: "b.m3u8", backupURIs: ["c.m3u8"])
        ])
        let errors = config.validate()
        #expect(errors.contains { $0.contains("Duplicate") })
    }

    @Test("Valid configuration has no errors")
    func validateValid() {
        let config = RedundantStreamConfig(backups: [
            .init(
                primaryURI: "https://cdn-a.com/1080p.m3u8",
                backupURIs: ["https://cdn-b.com/1080p.m3u8"]
            )
        ])
        let errors = config.validate()
        #expect(errors.isEmpty)
    }

    @Test("primaryRecoveryDelay can be customized")
    func customRecoveryDelay() {
        let config = RedundantStreamConfig(primaryRecoveryDelay: 120)
        #expect(config.primaryRecoveryDelay == 120)
    }
}

// MARK: - Equatable

@Suite("RedundantStreamConfig — Equatable")
struct RedundantStreamConfigEquatableTests {

    @Test("Identical configs are equal")
    func identical() {
        let a = RedundantStreamConfig(backups: [
            .init(primaryURI: "a.m3u8", backupURIs: ["b.m3u8"])
        ])
        let b = RedundantStreamConfig(backups: [
            .init(primaryURI: "a.m3u8", backupURIs: ["b.m3u8"])
        ])
        #expect(a == b)
    }

    @Test("Different configs are not equal")
    func different() {
        let a = RedundantStreamConfig(backups: [
            .init(primaryURI: "a.m3u8", backupURIs: ["b.m3u8"])
        ])
        let b = RedundantStreamConfig(backups: [
            .init(primaryURI: "a.m3u8", backupURIs: ["c.m3u8"])
        ])
        #expect(a != b)
    }
}
