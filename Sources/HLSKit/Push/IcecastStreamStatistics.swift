// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Icecast stream statistics reported by transports.
///
/// Maps from IcecastKit's ``ConnectionStatistics`` to provide
/// HLSKit-compatible metrics for monitoring stream health.
public struct IcecastStreamStatistics: Sendable, Equatable {

    /// Total bytes sent to the Icecast server.
    public let bytesSent: Int64

    /// Duration of the current stream session.
    public let duration: TimeInterval

    /// Current sending bitrate in bits per second.
    public let currentBitrate: Double

    /// Number of ICY metadata updates sent during this session.
    public let metadataUpdateCount: Int

    /// Number of reconnections during this session.
    public let reconnectionCount: Int

    /// Creates Icecast stream statistics.
    ///
    /// - Parameters:
    ///   - bytesSent: Total bytes sent.
    ///   - duration: Stream session duration.
    ///   - currentBitrate: Current bitrate in bits/sec.
    ///   - metadataUpdateCount: Metadata updates sent.
    ///   - reconnectionCount: Reconnection count.
    public init(
        bytesSent: Int64,
        duration: TimeInterval,
        currentBitrate: Double,
        metadataUpdateCount: Int,
        reconnectionCount: Int
    ) {
        self.bytesSent = bytesSent
        self.duration = duration
        self.currentBitrate = currentBitrate
        self.metadataUpdateCount = metadataUpdateCount
        self.reconnectionCount = reconnectionCount
    }
}

// MARK: - Conversion

extension IcecastStreamStatistics {

    /// Convert to the common ``TransportStatisticsSnapshot``
    /// for pipeline integration.
    ///
    /// - Parameters:
    ///   - peakBitrate: Peak bitrate observed. When `nil`,
    ///     uses ``currentBitrate``.
    ///   - timestamp: Snapshot timestamp. Default is now.
    /// - Returns: A ``TransportStatisticsSnapshot`` value.
    public func toTransportStatisticsSnapshot(
        peakBitrate: Double? = nil,
        timestamp: Date = Date()
    ) -> TransportStatisticsSnapshot {
        TransportStatisticsSnapshot(
            bytesSent: bytesSent,
            duration: duration,
            currentBitrate: currentBitrate,
            peakBitrate: peakBitrate ?? currentBitrate,
            reconnectionCount: reconnectionCount,
            timestamp: timestamp
        )
    }
}
