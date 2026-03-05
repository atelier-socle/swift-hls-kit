// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Unified transport connection quality, reported by any transport.
///
/// HLSKit uses this to make intelligent pipeline decisions
/// such as bitrate adaptation and failover. Transport libraries
/// (swift-rtmp-kit, swift-srt-kit, swift-icecast-kit) convert
/// their internal quality metrics into this common type.
public struct TransportQuality: Sendable, Equatable {

    /// Composite quality score (0.0–1.0).
    public let score: Double

    /// Human-readable quality grade derived from the score.
    public let grade: TransportQualityGrade

    /// Actionable recommendation from the transport layer.
    public let recommendation: String?

    /// Timestamp of this quality measurement.
    public let timestamp: Date

    /// Creates a new transport quality measurement.
    ///
    /// - Parameters:
    ///   - score: Composite quality score (0.0–1.0).
    ///   - grade: Human-readable quality grade.
    ///   - recommendation: Actionable recommendation, if any.
    ///   - timestamp: Timestamp of this measurement.
    public init(
        score: Double,
        grade: TransportQualityGrade,
        recommendation: String?,
        timestamp: Date
    ) {
        self.score = score
        self.grade = grade
        self.recommendation = recommendation
        self.timestamp = timestamp
    }
}

/// Human-readable quality grade for transport connections.
///
/// Grades map to score ranges:
/// - ``excellent``: score > 0.9
/// - ``good``: score > 0.7
/// - ``fair``: score > 0.5
/// - ``poor``: score > 0.3
/// - ``critical``: score ≤ 0.3
public enum TransportQualityGrade: String, Sendable, CaseIterable, Comparable {

    /// Excellent quality — score above 0.9.
    case excellent

    /// Good quality — score above 0.7.
    case good

    /// Fair quality — score above 0.5.
    case fair

    /// Poor quality — score above 0.3.
    case poor

    /// Critical quality — score at or below 0.3.
    case critical

    // MARK: - Comparable

    public static func < (lhs: TransportQualityGrade, rhs: TransportQualityGrade) -> Bool {
        lhs.ordinal < rhs.ordinal
    }

    /// Numeric ordinal for ordering (critical=0 … excellent=4).
    private var ordinal: Int {
        switch self {
        case .critical: 0
        case .poor: 1
        case .fair: 2
        case .good: 3
        case .excellent: 4
        }
    }
}

extension TransportQualityGrade {

    /// Initialize a grade from a quality score (0.0–1.0).
    ///
    /// - Parameter score: Quality score to convert.
    public init(score: Double) {
        switch score {
        case _ where score > 0.9:
            self = .excellent
        case _ where score > 0.7:
            self = .good
        case _ where score > 0.5:
            self = .fair
        case _ where score > 0.3:
            self = .poor
        default:
            self = .critical
        }
    }
}
