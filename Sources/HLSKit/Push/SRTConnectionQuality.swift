// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// SRT connection quality assessment.
///
/// Maps from SRTKit's quality scoring system to provide
/// HLSKit-compatible quality metrics. Combines round-trip
/// time and packet loss rate into a composite score.
public struct SRTConnectionQuality: Sendable, Equatable {

    /// Composite quality score (0.0–1.0).
    public let score: Double

    /// Quality grade derived from the score.
    public let grade: TransportQualityGrade

    /// Round-trip time in milliseconds.
    public let rttMs: Double

    /// Packet loss rate (0.0–1.0).
    public let packetLossRate: Double

    /// Actionable recommendation based on quality assessment.
    public let recommendation: String?

    /// Creates an SRT connection quality assessment.
    ///
    /// - Parameters:
    ///   - score: Composite quality score (0.0–1.0).
    ///   - grade: Quality grade.
    ///   - rttMs: Round-trip time in milliseconds.
    ///   - packetLossRate: Packet loss rate (0.0–1.0).
    ///   - recommendation: Actionable recommendation, if any.
    public init(
        score: Double,
        grade: TransportQualityGrade,
        rttMs: Double,
        packetLossRate: Double,
        recommendation: String? = nil
    ) {
        self.score = score
        self.grade = grade
        self.rttMs = rttMs
        self.packetLossRate = packetLossRate
        self.recommendation = recommendation
    }
}

// MARK: - Conversion

extension SRTConnectionQuality {

    /// Convert to the common ``TransportQuality`` type for
    /// pipeline integration.
    ///
    /// - Parameter timestamp: The timestamp for the quality
    ///   snapshot. Defaults to the current date.
    /// - Returns: A ``TransportQuality`` value.
    public func toTransportQuality(
        timestamp: Date = Date()
    ) -> TransportQuality {
        TransportQuality(
            score: score,
            grade: grade,
            recommendation: recommendation,
            timestamp: timestamp
        )
    }
}
