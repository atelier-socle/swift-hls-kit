// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Unified transport events that ``LivePipeline`` reacts to.
///
/// All transport implementations emit these events through a common
/// stream, allowing the pipeline to respond to transport-level
/// changes uniformly. Events are consumed via
/// ``QualityAwareTransport/transportEvents``.
public enum TransportEvent: Sendable {

    /// Transport has connected successfully.
    ///
    /// - Parameter transportType: Identifier of the transport
    ///   (e.g. `"RTMP"`, `"SRT"`, `"Icecast"`).
    case connected(transportType: String)

    /// Transport has disconnected.
    ///
    /// - Parameters:
    ///   - transportType: Identifier of the transport.
    ///   - error: The error that caused the disconnection, if any.
    case disconnected(transportType: String, error: (any Error)?)

    /// Transport is attempting to reconnect.
    ///
    /// - Parameters:
    ///   - transportType: Identifier of the transport.
    ///   - attempt: Current reconnection attempt number (1-based).
    case reconnecting(transportType: String, attempt: Int)

    /// Connection quality has changed.
    ///
    /// - Parameter quality: The updated quality measurement.
    case qualityChanged(TransportQuality)

    /// A bitrate recommendation has been emitted.
    ///
    /// - Parameter recommendation: The bitrate recommendation.
    case bitrateRecommendation(TransportBitrateRecommendation)

    /// Statistics snapshot has been updated.
    ///
    /// - Parameter snapshot: The updated statistics.
    case statisticsUpdated(TransportStatisticsSnapshot)

    /// Recording state has changed.
    ///
    /// - Parameter state: The updated recording state.
    case recordingStateChanged(TransportRecordingState)
}
