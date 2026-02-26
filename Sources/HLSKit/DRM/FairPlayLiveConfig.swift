// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// FairPlay Streaming configuration for live HLS content.
///
/// Configures the key delivery parameters for Apple FairPlay DRM
/// in live streaming scenarios. HLSKit handles the manifest attributes
/// (`EXT-X-KEY`, `EXT-X-SESSION-KEY`); actual license acquisition
/// is the responsibility of the application's Key Server Module (KSM).
///
/// ```swift
/// let config = FairPlayLiveConfig(
///     keyServerURL: URL(string: "https://license.example.com/fps")!,
///     method: .sampleAESCTR
/// )
/// ```
public struct FairPlayLiveConfig: Sendable, Equatable {

    /// Key Server Module URL for license requests.
    public var keyServerURL: URL

    /// Encryption method.
    public var method: FairPlayMethod

    /// KEYFORMAT attribute value.
    public var keyFormat: String

    /// KEYFORMATVERSIONS attribute value.
    public var keyFormatVersions: String

    /// Whether to include EXT-X-SESSION-KEY in master playlist for pre-fetching.
    public var enableSessionKey: Bool

    /// Creates a FairPlay live configuration.
    ///
    /// - Parameters:
    ///   - keyServerURL: Key Server Module URL for license requests.
    ///   - method: Encryption method (default: `.sampleAESCTR`).
    ///   - keyFormat: KEYFORMAT attribute value.
    ///   - keyFormatVersions: KEYFORMATVERSIONS attribute value.
    ///   - enableSessionKey: Whether to include EXT-X-SESSION-KEY.
    public init(
        keyServerURL: URL,
        method: FairPlayMethod = .sampleAESCTR,
        keyFormat: String = "com.apple.streamingkeydelivery",
        keyFormatVersions: String = "1",
        enableSessionKey: Bool = true
    ) {
        self.keyServerURL = keyServerURL
        self.method = method
        self.keyFormat = keyFormat
        self.keyFormatVersions = keyFormatVersions
        self.enableSessionKey = enableSessionKey
    }

    // MARK: - FairPlayMethod

    /// FairPlay encryption methods.
    public enum FairPlayMethod: String, Sendable, CaseIterable, Equatable {

        /// SAMPLE-AES (CBC mode, legacy FairPlay).
        case sampleAES = "SAMPLE-AES"

        /// SAMPLE-AES-CTR (CBCS mode, modern FairPlay, recommended).
        case sampleAESCTR = "SAMPLE-AES-CTR"
    }

    // MARK: - Mapping

    /// Maps to the existing ``EncryptionMethod`` enum.
    public var encryptionMethod: EncryptionMethod {
        switch method {
        case .sampleAES: return .sampleAES
        case .sampleAESCTR: return .sampleAESCTR
        }
    }

    /// Generates the `EXT-X-KEY` attributes for a given key URI and IV.
    ///
    /// - Parameters:
    ///   - keyURI: The URI where the client fetches the key.
    ///   - iv: Optional initialization vector hex string.
    /// - Returns: An ``EncryptionKey`` ready for segment tagging.
    public func keyAttributes(keyURI: String, iv: String?) -> EncryptionKey {
        EncryptionKey(
            method: encryptionMethod,
            uri: keyURI,
            iv: iv,
            keyFormat: keyFormat,
            keyFormatVersions: keyFormatVersions
        )
    }

    /// Generates the `EXT-X-SESSION-KEY` entry for the master playlist.
    ///
    /// - Parameter keyURI: The URI where the client fetches the key.
    /// - Returns: An ``EncryptionKey`` ready for master playlist session keys.
    public func sessionKeyEntry(keyURI: String) -> EncryptionKey {
        EncryptionKey(
            method: encryptionMethod,
            uri: keyURI,
            keyFormat: keyFormat,
            keyFormatVersions: keyFormatVersions
        )
    }

    // MARK: - Presets

    /// Default key server URL for presets.
    private static let presetKeyServerURL =
        URL(string: "https://fps.example.com")
        ?? URL(fileURLWithPath: "/")

    /// Modern FairPlay with CBCS (recommended for new deployments).
    public static let modern = FairPlayLiveConfig(
        keyServerURL: presetKeyServerURL,
        method: .sampleAESCTR
    )

    /// Legacy FairPlay with CBC.
    public static let legacy = FairPlayLiveConfig(
        keyServerURL: presetKeyServerURL,
        method: .sampleAES,
        keyFormatVersions: "1"
    )
}
