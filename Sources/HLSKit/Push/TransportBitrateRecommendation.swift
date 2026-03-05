// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Bitrate recommendation emitted by transport layers.
///
/// HLSKit can use this to adjust encoder settings in the
/// ``LivePipeline``. Transport libraries that implement
/// adaptive bitrate (bandwidth estimation + bitrate suggestion)
/// emit these recommendations through ``AdaptiveBitrateTransport``.
public struct TransportBitrateRecommendation: Sendable, Equatable {

    /// Recommended target bitrate in bits per second.
    public let recommendedBitrate: Int

    /// Current estimated available bitrate in bits per second.
    public let currentEstimatedBitrate: Int

    /// Direction of the recommendation.
    public let direction: Direction

    /// Human-readable reason for this recommendation.
    public let reason: String

    /// Confidence level of this recommendation (0.0–1.0).
    public let confidence: Double

    /// Timestamp of this recommendation.
    public let timestamp: Date

    /// Direction of a bitrate recommendation.
    public enum Direction: String, Sendable, CaseIterable {
        /// Increase bitrate — more bandwidth available.
        case increase
        /// Decrease bitrate — congestion detected.
        case decrease
        /// Maintain current bitrate — conditions stable.
        case maintain
    }

    /// Creates a new bitrate recommendation.
    ///
    /// - Parameters:
    ///   - recommendedBitrate: Recommended target bitrate in bps.
    ///   - currentEstimatedBitrate: Current estimated available bitrate in bps.
    ///   - direction: Direction of the recommendation.
    ///   - reason: Human-readable reason.
    ///   - confidence: Confidence level (0.0–1.0).
    ///   - timestamp: Timestamp of this recommendation.
    public init(
        recommendedBitrate: Int,
        currentEstimatedBitrate: Int,
        direction: Direction,
        reason: String,
        confidence: Double,
        timestamp: Date
    ) {
        self.recommendedBitrate = recommendedBitrate
        self.currentEstimatedBitrate = currentEstimatedBitrate
        self.direction = direction
        self.reason = reason
        self.confidence = confidence
        self.timestamp = timestamp
    }
}
