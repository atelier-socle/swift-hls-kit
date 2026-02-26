// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Facade that orchestrates DRM for a live HLS stream.
///
/// Combines key management, rotation policy, session keys, and
/// optional CENC interoperability into a single configuration point.
///
/// ```swift
/// let drm = LiveDRMPipeline.fairPlayOnly()
/// let key = try await drm.keyForSegment(index: 5)
/// let sessionKeys = drm.sessionKeys(currentKeyURI: key.keyURI)
/// ```
public struct LiveDRMPipeline<Provider: KeyProvider>: Sendable {

    /// FairPlay configuration (nil if not using FairPlay).
    public let fairPlay: FairPlayLiveConfig?

    /// Key rotation policy.
    public let rotationPolicy: KeyRotationPolicy

    /// CENC interop configuration (nil if Apple-only).
    public let cenc: CENCConfig?

    /// The live key manager (actor).
    public let keyManager: LiveKeyManager<Provider>

    /// The session key manager.
    public var sessionKeyManager: SessionKeyManager

    /// Creates a live DRM pipeline.
    ///
    /// - Parameters:
    ///   - fairPlay: FairPlay configuration (nil if not using FairPlay).
    ///   - rotationPolicy: Key rotation policy (default: every 10 segments).
    ///   - cenc: CENC interop configuration (nil if Apple-only).
    ///   - keyProvider: Provider for generating/fetching keys.
    public init(
        fairPlay: FairPlayLiveConfig? = nil,
        rotationPolicy: KeyRotationPolicy = .everyNSegments(10),
        cenc: CENCConfig? = nil,
        keyProvider: Provider
    ) {
        self.fairPlay = fairPlay
        self.rotationPolicy = rotationPolicy
        self.cenc = cenc
        self.keyManager = LiveKeyManager(
            rotationPolicy: rotationPolicy,
            keyProvider: keyProvider
        )

        var skm = SessionKeyManager()
        if let fp = fairPlay, fp.enableSessionKey {
            skm.addDRMSystem(.fairPlay(fp))
        }
        if let cencConfig = cenc {
            skm.addDRMSystem(.cenc(cencConfig))
        }
        self.sessionKeyManager = skm
    }

    // MARK: - Key Management

    /// Get encryption key for a segment.
    ///
    /// - Parameter index: The segment index (0-based).
    /// - Returns: The encryption key for this segment.
    /// - Throws: If key generation fails.
    public func keyForSegment(index: Int) async throws -> LiveEncryptionKey {
        try await keyManager.keyForSegment(index: index)
    }

    /// Get session keys for master playlist.
    ///
    /// - Parameter currentKeyURI: The current key URI.
    /// - Returns: Array of ``EncryptionKey`` for `MasterPlaylist.sessionKeys`.
    public func sessionKeys(currentKeyURI: String) -> [EncryptionKey] {
        sessionKeyManager.generateSessionKeys(currentKeyURI: currentKeyURI)
    }

    /// Get key rotation statistics.
    ///
    /// - Returns: Current rotation statistics.
    public func statistics() async -> KeyRotationStatistics {
        await keyManager.statistics()
    }

    /// Whether multi-DRM is configured.
    public var isMultiDRM: Bool { cenc != nil }

    /// Whether any DRM is configured.
    public var isEnabled: Bool { fairPlay != nil || cenc != nil }
}

// MARK: - RandomKeyProvider Presets

extension LiveDRMPipeline where Provider == RandomKeyProvider {

    /// Creates a live DRM pipeline with a default random key provider.
    ///
    /// - Parameters:
    ///   - fairPlay: FairPlay configuration (nil if not using FairPlay).
    ///   - rotationPolicy: Key rotation policy (default: every 10 segments).
    ///   - cenc: CENC interop configuration (nil if Apple-only).
    public init(
        fairPlay: FairPlayLiveConfig? = nil,
        rotationPolicy: KeyRotationPolicy = .everyNSegments(10),
        cenc: CENCConfig? = nil
    ) {
        self.init(
            fairPlay: fairPlay,
            rotationPolicy: rotationPolicy,
            cenc: cenc,
            keyProvider: RandomKeyProvider()
        )
    }

    /// FairPlay-only with moderate rotation.
    ///
    /// - Parameters:
    ///   - config: FairPlay configuration (default: `.modern`).
    ///   - rotation: Key rotation policy (default: every 10 segments).
    /// - Returns: A configured pipeline.
    public static func fairPlayOnly(
        config: FairPlayLiveConfig = .modern,
        rotation: KeyRotationPolicy = .everyNSegments(10)
    ) -> LiveDRMPipeline<RandomKeyProvider> {
        LiveDRMPipeline(
            fairPlay: config,
            rotationPolicy: rotation
        )
    }

    /// Multi-DRM (FairPlay + Widevine + PlayReady).
    ///
    /// - Parameters:
    ///   - fairPlay: FairPlay configuration (default: `.modern`).
    ///   - cencSystems: CENC systems to include (default: Widevine + PlayReady).
    ///   - rotation: Key rotation policy (default: every 10 segments).
    /// - Returns: A configured pipeline.
    public static func multiDRM(
        fairPlay: FairPlayLiveConfig = .modern,
        cencSystems: [CENCConfig.CENCSystem] = [.widevine, .playReady],
        rotation: KeyRotationPolicy = .everyNSegments(10)
    ) -> LiveDRMPipeline<RandomKeyProvider> {
        let cenc = CENCConfig(
            systems: cencSystems,
            defaultKeyID: UUID().uuidString
        )
        return LiveDRMPipeline(
            fairPlay: fairPlay,
            rotationPolicy: rotation,
            cenc: cenc
        )
    }
}
