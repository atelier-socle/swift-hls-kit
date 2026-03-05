// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol adopted by transports that report connection quality.
///
/// Complements the base transport protocols (``RTMPTransport``,
/// ``SRTTransport``, ``IcecastTransport``). Transport library
/// bridge modules adopt this when the underlying transport
/// supports quality reporting.
public protocol QualityAwareTransport: Sendable {

    /// Current connection quality, or `nil` if not yet measured.
    var connectionQuality: TransportQuality? { get async }

    /// Stream of transport events.
    var transportEvents: AsyncStream<TransportEvent> { get }

    /// Current statistics snapshot, or `nil` if not yet available.
    var statisticsSnapshot: TransportStatisticsSnapshot? { get async }
}

/// Protocol for transports that support adaptive bitrate recommendations.
///
/// Transport libraries that implement ABR (bandwidth estimation +
/// bitrate suggestion) adopt this to feed recommendations into
/// the ``LivePipeline``.
public protocol AdaptiveBitrateTransport: Sendable {

    /// Stream of bitrate recommendations.
    var bitrateRecommendations: AsyncStream<TransportBitrateRecommendation> { get }
}

/// Protocol for transports that support local stream recording.
///
/// Allows the pipeline to start/stop recording and monitor
/// recording state.
public protocol RecordingTransport: Sendable {

    /// Current recording state, or `nil` if recording is not supported.
    var recordingState: TransportRecordingState? { get async }

    /// Start recording to the specified directory.
    ///
    /// - Parameter directory: Path to the directory for recording files.
    func startRecording(directory: String) async throws

    /// Stop recording and finalize the file.
    func stopRecording() async throws
}
