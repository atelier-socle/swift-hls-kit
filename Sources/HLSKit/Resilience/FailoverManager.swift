// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Manages primary/backup stream failover for live HLS.
///
/// Tracks stream health and manages transitions between primary
/// and backup origins based on the redundant stream configuration.
///
/// ```swift
/// var manager = FailoverManager(config: redundantConfig)
/// manager.reportFailure(for: "https://cdn-a.com/main.m3u8")
/// let uri = manager.activeURI(for: "https://cdn-a.com/main.m3u8")
/// // → "https://cdn-b.com/main.m3u8" (backup)
/// ```
public struct FailoverManager: Sendable {

    /// Redundant stream configuration.
    public let config: RedundantStreamConfig

    /// Failure tracking per primary URI.
    private var failures: [String: FailureState] = [:]

    /// Creates a failover manager.
    ///
    /// - Parameter config: The redundant stream configuration.
    public init(config: RedundantStreamConfig) {
        self.config = config
    }

    // MARK: - FailureState

    /// Stream failure state.
    public struct FailureState: Sendable, Equatable {
        /// The primary URI being tracked.
        public let primaryURI: String
        /// Current backup index (0-based into backupURIs).
        public var currentBackupIndex: Int
        /// Number of failures recorded.
        public var failureCount: Int
        /// Time of the last failure.
        public var lastFailureTime: Date?
        /// Whether the stream is currently using a backup.
        public var isOnBackup: Bool { currentBackupIndex >= 0 }
    }

    // MARK: - Failure Reporting

    /// Report a failure for a primary URI.
    ///
    /// Increments the backup index to switch to the next available backup.
    ///
    /// - Parameter primaryURI: The primary URI that failed.
    public mutating func reportFailure(for primaryURI: String) {
        if var state = failures[primaryURI] {
            let backup = findBackup(for: primaryURI)
            let maxIndex = (backup?.backupURIs.count ?? 1) - 1
            if state.currentBackupIndex < maxIndex {
                state.currentBackupIndex += 1
            }
            state.failureCount += 1
            state.lastFailureTime = Date()
            failures[primaryURI] = state
        } else {
            failures[primaryURI] = FailureState(
                primaryURI: primaryURI,
                currentBackupIndex: 0,
                failureCount: 1,
                lastFailureTime: Date()
            )
        }
    }

    /// Report recovery of a primary URI.
    ///
    /// Resets the failure state, switching back to the primary.
    ///
    /// - Parameter primaryURI: The primary URI that recovered.
    public mutating func reportRecovery(for primaryURI: String) {
        failures.removeValue(forKey: primaryURI)
    }

    // MARK: - Active URI

    /// Get the active URI for a primary URI (may return backup).
    ///
    /// - Parameter primaryURI: The primary URI to look up.
    /// - Returns: The currently active URI (primary or backup).
    public func activeURI(for primaryURI: String) -> String {
        guard let state = failures[primaryURI],
            let backup = findBackup(for: primaryURI)
        else {
            return primaryURI
        }
        let index = state.currentBackupIndex
        if index >= 0 && index < backup.backupURIs.count {
            return backup.backupURIs[index]
        }
        return primaryURI
    }

    // MARK: - Status

    /// Check if any streams are on backup.
    public var hasActiveFailovers: Bool {
        !failures.isEmpty
    }

    /// Number of active failovers.
    public var activeFailoverCount: Int {
        failures.count
    }

    /// Reset all failure states.
    public mutating func reset() {
        failures.removeAll()
    }

    // MARK: - Private

    private func findBackup(
        for primaryURI: String
    ) -> RedundantStreamConfig.VariantBackup? {
        config.backups.first { $0.primaryURI == primaryURI }
    }
}
