// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Manages `EXT-X-SESSION-KEY` entries in master playlists.
///
/// Session keys allow clients to pre-fetch DRM keys before selecting
/// a variant, reducing playback start time. Supports multiple DRM
/// systems simultaneously (one SESSION-KEY per system).
///
/// ```swift
/// var manager = SessionKeyManager()
/// manager.addDRMSystem(.fairPlay(.modern))
/// let sessionKeys = manager.generateSessionKeys(
///     currentKeyURI: "https://keys.example.com/key1"
/// )
/// // → [EncryptionKey] ready for MasterPlaylist.sessionKeys
/// ```
public struct SessionKeyManager: Sendable, Equatable {

    /// Creates an empty session key manager.
    public init() {}

    // MARK: - DRMSystem

    /// A configured DRM system.
    public enum DRMSystem: Sendable, Equatable {

        /// Apple FairPlay Streaming.
        case fairPlay(FairPlayLiveConfig)

        /// Generic CENC (Widevine, PlayReady).
        case cenc(CENCConfig)

        /// Custom DRM with explicit attributes.
        case custom(
            method: EncryptionMethod,
            keyFormat: String,
            keyFormatVersions: String
        )
    }

    /// Registered DRM systems.
    private var systems: [DRMSystem] = []

    // MARK: - Management

    /// Register a DRM system.
    ///
    /// - Parameter system: The DRM system to add.
    public mutating func addDRMSystem(_ system: DRMSystem) {
        systems.append(system)
    }

    /// Remove all registered systems.
    public mutating func removeAllSystems() {
        systems.removeAll()
    }

    /// Number of registered DRM systems.
    public var systemCount: Int { systems.count }

    // MARK: - Generation

    /// Generate SESSION-KEY entries for all registered DRM systems.
    ///
    /// - Parameters:
    ///   - currentKeyURI: The current key URI.
    ///   - iv: Optional initialization vector hex string.
    /// - Returns: Array of ``EncryptionKey`` ready for
    ///   `MasterPlaylist.sessionKeys`.
    public func generateSessionKeys(
        currentKeyURI: String,
        iv: String? = nil
    ) -> [EncryptionKey] {
        var keys: [EncryptionKey] = []

        for system in systems {
            switch system {
            case .fairPlay(let config):
                let key = EncryptionKey(
                    method: config.encryptionMethod,
                    uri: currentKeyURI,
                    iv: iv,
                    keyFormat: config.keyFormat,
                    keyFormatVersions: config.keyFormatVersions
                )
                keys.append(key)

            case .cenc(let config):
                for cencSystem in config.systems {
                    let key = EncryptionKey(
                        method: .sampleAESCTR,
                        uri: currentKeyURI,
                        iv: iv,
                        keyFormat: CENCConfig.keyFormat(for: cencSystem),
                        keyFormatVersions: "1"
                    )
                    keys.append(key)
                }

            case .custom(let method, let format, let versions):
                let key = EncryptionKey(
                    method: method,
                    uri: currentKeyURI,
                    iv: iv,
                    keyFormat: format,
                    keyFormatVersions: versions
                )
                keys.append(key)
            }
        }

        return keys
    }
}
