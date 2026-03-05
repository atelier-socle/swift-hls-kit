// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generic transport statistics that all transports can report.
///
/// A point-in-time snapshot of transport-level metrics. Transport
/// libraries convert their internal statistics into this common type
/// so that ``LivePipeline`` and ``MultiDestinationPusher`` can
/// aggregate and display unified metrics.
public struct TransportStatisticsSnapshot: Sendable, Equatable {

    /// Total bytes sent since connection.
    public let bytesSent: Int64

    /// Duration of the current connection.
    public let duration: TimeInterval

    /// Current sending bitrate in bits per second.
    public let currentBitrate: Double

    /// Peak bitrate observed during this connection.
    public let peakBitrate: Double

    /// Number of reconnections since initial connect.
    public let reconnectionCount: Int

    /// Timestamp of this snapshot.
    public let timestamp: Date

    /// Creates a new statistics snapshot.
    ///
    /// - Parameters:
    ///   - bytesSent: Total bytes sent since connection.
    ///   - duration: Duration of the current connection.
    ///   - currentBitrate: Current sending bitrate in bps.
    ///   - peakBitrate: Peak bitrate observed.
    ///   - reconnectionCount: Number of reconnections.
    ///   - timestamp: Timestamp of this snapshot.
    public init(
        bytesSent: Int64,
        duration: TimeInterval,
        currentBitrate: Double,
        peakBitrate: Double,
        reconnectionCount: Int,
        timestamp: Date
    ) {
        self.bytesSent = bytesSent
        self.duration = duration
        self.currentBitrate = currentBitrate
        self.peakBitrate = peakBitrate
        self.reconnectionCount = reconnectionCount
        self.timestamp = timestamp
    }
}
