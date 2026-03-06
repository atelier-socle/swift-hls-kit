// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - TransportDestinationHealth

/// Health status for a single transport destination.
///
/// Combines connection state, quality measurement, and statistics
/// into a unified health view for one push destination.
public struct TransportDestinationHealth: Sendable, Equatable {

    /// Human-readable label for this destination
    /// (e.g., "Twitch", "YouTube", "SRT-Backup").
    public let label: String

    /// Transport protocol type identifier
    /// (e.g., "RTMP", "SRT", "Icecast", "HTTP").
    public let transportType: String

    /// Current connection quality, if available.
    public let quality: TransportQuality?

    /// Current connection state.
    public let connectionState: PushConnectionState

    /// Latest statistics snapshot, if available.
    public let statistics: TransportStatisticsSnapshot?

    /// Creates a destination health status.
    ///
    /// - Parameters:
    ///   - label: Human-readable destination label.
    ///   - transportType: Transport protocol type identifier.
    ///   - quality: Current connection quality, or `nil`.
    ///   - connectionState: Current connection state.
    ///   - statistics: Latest statistics snapshot, or `nil`.
    public init(
        label: String,
        transportType: String,
        quality: TransportQuality?,
        connectionState: PushConnectionState,
        statistics: TransportStatisticsSnapshot?
    ) {
        self.label = label
        self.transportType = transportType
        self.quality = quality
        self.connectionState = connectionState
        self.statistics = statistics
    }
}

// MARK: - TransportHealthDashboard

/// Aggregated health view across all transport destinations.
///
/// Used by ``LivePipeline`` to monitor multi-destination
/// streaming health. Computes overall grade, healthy/degraded/failed
/// counts from the individual destination health reports.
public struct TransportHealthDashboard: Sendable, Equatable {

    /// Health status for each destination.
    public let destinations: [TransportDestinationHealth]

    /// Worst-case quality grade across all destinations.
    ///
    /// Returns `.critical` if any destination is disconnected,
    /// failed, or has `.critical` quality. If destinations is
    /// empty, returns `.critical`.
    public let overallGrade: TransportQualityGrade

    /// Number of destinations with quality grade >= `.good`.
    public let healthyCount: Int

    /// Number of destinations with quality grade `.fair`
    /// or `.poor`.
    public let degradedCount: Int

    /// Number of destinations that are disconnected, failed,
    /// or have `.critical` quality.
    public let failedCount: Int

    /// Creates a health dashboard from destination health reports.
    ///
    /// Computes ``overallGrade``, ``healthyCount``,
    /// ``degradedCount``, and ``failedCount`` from the
    /// destinations array.
    ///
    /// - Parameter destinations: Health status for each destination.
    public init(destinations: [TransportDestinationHealth]) {
        self.destinations = destinations

        var healthy = 0
        var degraded = 0
        var failed = 0
        var worstGrade: TransportQualityGrade = .excellent

        for destination in destinations {
            let grade = Self.effectiveGrade(for: destination)
            if grade < worstGrade {
                worstGrade = grade
            }
            switch grade {
            case .excellent, .good:
                healthy += 1
            case .fair, .poor:
                degraded += 1
            case .critical:
                failed += 1
            }
        }

        self.healthyCount = healthy
        self.degradedCount = degraded
        self.failedCount = failed
        self.overallGrade = destinations.isEmpty ? .critical : worstGrade
    }

    /// Computes the effective grade for a destination,
    /// treating disconnected/failed states as `.critical`.
    private static func effectiveGrade(
        for destination: TransportDestinationHealth
    ) -> TransportQualityGrade {
        switch destination.connectionState {
        case .disconnected, .failed:
            return .critical
        case .connecting, .reconnecting:
            return destination.quality?.grade ?? .poor
        case .connected:
            return destination.quality?.grade ?? .good
        }
    }
}
