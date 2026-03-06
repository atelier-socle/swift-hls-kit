// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - TransportAwarePipelinePolicy

/// Policy controlling how ``LivePipeline`` reacts to transport
/// quality and ABR signals.
///
/// Configure this policy to enable automatic bitrate adjustment,
/// set minimum quality thresholds, and control ABR responsiveness.
/// Attach it to ``LivePipelineConfiguration/transportPolicy``
/// to activate transport-aware behavior.
public struct TransportAwarePipelinePolicy: Sendable, Equatable {

    /// Whether to auto-adjust encoder bitrate based on transport
    /// recommendations.
    public var autoAdjustBitrate: Bool

    /// Minimum quality grade before ``LivePipeline`` considers
    /// the transport unhealthy.
    public var minimumQualityGrade: TransportQualityGrade

    /// How aggressively to follow transport ABR recommendations.
    public var abrResponsiveness: ABRResponsiveness

    /// ABR responsiveness levels.
    ///
    /// Controls how quickly the pipeline acts on transport ABR
    /// recommendations. More conservative settings reduce jitter
    /// at the cost of slower adaptation.
    public enum ABRResponsiveness: String, Sendable, CaseIterable {
        /// Only follow after 3 consecutive same-direction
        /// recommendations.
        case conservative
        /// Follow after 2 consecutive same-direction
        /// recommendations.
        case responsive
        /// Follow every recommendation immediately.
        case immediate
    }

    /// Creates a transport-aware pipeline policy.
    ///
    /// - Parameters:
    ///   - autoAdjustBitrate: Enable automatic bitrate adjustment.
    ///   - minimumQualityGrade: Minimum acceptable quality grade.
    ///   - abrResponsiveness: ABR recommendation responsiveness.
    public init(
        autoAdjustBitrate: Bool,
        minimumQualityGrade: TransportQualityGrade,
        abrResponsiveness: ABRResponsiveness
    ) {
        self.autoAdjustBitrate = autoAdjustBitrate
        self.minimumQualityGrade = minimumQualityGrade
        self.abrResponsiveness = abrResponsiveness
    }

    /// Default policy: auto-adjust enabled, minimum quality
    /// `.poor`, responsive ABR.
    public static let `default` = TransportAwarePipelinePolicy(
        autoAdjustBitrate: true,
        minimumQualityGrade: .poor,
        abrResponsiveness: .responsive
    )

    /// Disabled policy: no auto-adjustment, only react to
    /// critical quality.
    public static let disabled = TransportAwarePipelinePolicy(
        autoAdjustBitrate: false,
        minimumQualityGrade: .critical,
        abrResponsiveness: .conservative
    )
}
