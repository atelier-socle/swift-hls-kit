// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for redundant (backup) streams in HLS.
///
/// Per Apple HLS spec, multiple `EXT-X-STREAM-INF` entries with identical
/// parameters but different URIs provide automatic failover.
///
/// ```swift
/// let config = RedundantStreamConfig(backups: [
///     .init(primaryURI: "https://cdn-a.com/1080p.m3u8",
///           backupURIs: ["https://cdn-b.com/1080p.m3u8"])
/// ])
/// ```
public struct RedundantStreamConfig: Sendable, Equatable {

    /// Variant backup configurations.
    public var backups: [VariantBackup]

    /// Delay before switching back to primary after recovery (seconds).
    public var primaryRecoveryDelay: TimeInterval

    /// Creates a redundant stream configuration.
    ///
    /// - Parameters:
    ///   - backups: The variant backup configurations.
    ///   - primaryRecoveryDelay: Delay before switching back to primary.
    public init(
        backups: [VariantBackup] = [],
        primaryRecoveryDelay: TimeInterval = 30
    ) {
        self.backups = backups
        self.primaryRecoveryDelay = primaryRecoveryDelay
    }

    // MARK: - VariantBackup

    /// A variant with backup URIs.
    public struct VariantBackup: Sendable, Equatable {
        /// Primary variant URI.
        public let primaryURI: String
        /// Backup URIs in priority order.
        public let backupURIs: [String]

        /// Creates a variant backup.
        ///
        /// - Parameters:
        ///   - primaryURI: The primary variant URI.
        ///   - backupURIs: Backup URIs in priority order.
        public init(primaryURI: String, backupURIs: [String]) {
            self.primaryURI = primaryURI
            self.backupURIs = backupURIs
        }

        /// Total URIs (primary + backups).
        public var totalURIs: Int { 1 + backupURIs.count }
    }

    // MARK: - Properties

    /// Total number of backup URIs across all variants.
    public var totalBackupURIs: Int {
        backups.reduce(0) { $0 + $1.backupURIs.count }
    }

    // MARK: - Validation

    /// Validate the configuration.
    ///
    /// - Returns: An array of validation error messages. Empty if valid.
    public func validate() -> [String] {
        var errors: [String] = []

        for backup in backups where backup.backupURIs.isEmpty {
            errors.append(
                "Variant '\(backup.primaryURI)' has no backup URIs"
            )
        }

        var allURIs: [String] = []
        for backup in backups {
            allURIs.append(backup.primaryURI)
            allURIs.append(contentsOf: backup.backupURIs)
        }
        if Set(allURIs).count != allURIs.count {
            errors.append("Duplicate URIs found across variants and backups")
        }

        return errors
    }
}
