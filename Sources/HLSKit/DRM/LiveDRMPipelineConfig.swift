// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Lightweight DRM configuration for LivePipelineConfiguration.
///
/// Captures DRM parameters without creating the actor-based LiveDRMPipeline.
/// The LivePipeline creates the actual DRM pipeline at runtime.
///
/// ```swift
/// let config = LiveDRMPipelineConfig(
///     fairPlay: .modern,
///     rotationPolicy: .everyNSegments(10)
/// )
/// ```
public struct LiveDRMPipelineConfig: Sendable, Equatable {

    /// FairPlay configuration.
    public var fairPlay: FairPlayLiveConfig?

    /// Key rotation policy.
    public var rotationPolicy: KeyRotationPolicy

    /// CENC interop configuration.
    public var cenc: CENCConfig?

    /// Creates a DRM pipeline configuration.
    ///
    /// - Parameters:
    ///   - fairPlay: Optional FairPlay configuration.
    ///   - rotationPolicy: Key rotation policy.
    ///   - cenc: Optional CENC interop configuration.
    public init(
        fairPlay: FairPlayLiveConfig? = nil,
        rotationPolicy: KeyRotationPolicy = .everyNSegments(10),
        cenc: CENCConfig? = nil
    ) {
        self.fairPlay = fairPlay
        self.rotationPolicy = rotationPolicy
        self.cenc = cenc
    }

    // MARK: - Computed Properties

    /// Whether any DRM is configured.
    public var isEnabled: Bool { fairPlay != nil || cenc != nil }

    /// Whether multi-DRM is configured.
    public var isMultiDRM: Bool { cenc != nil }

    // MARK: - Presets

    /// FairPlay with modern CBCS encryption and key rotation every 10 segments.
    public static let fairPlayModern = LiveDRMPipelineConfig(
        fairPlay: .modern,
        rotationPolicy: .everyNSegments(10)
    )

    /// Multi-DRM: FairPlay + Widevine + PlayReady with key rotation.
    public static let multiDRM = LiveDRMPipelineConfig(
        fairPlay: .modern,
        rotationPolicy: .everyNSegments(10),
        cenc: CENCConfig(
            systems: [.widevine, .playReady],
            defaultKeyID: "default"
        )
    )
}
