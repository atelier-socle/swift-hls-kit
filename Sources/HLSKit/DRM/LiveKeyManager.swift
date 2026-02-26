// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Manages encryption key lifecycle for live HLS streams.
///
/// Tracks key rotation, generates IVs, and provides the current
/// encryption key for each segment. Works with any DRM system
/// via the ``KeyProvider`` protocol.
///
/// ```swift
/// let manager = LiveKeyManager(
///     rotationPolicy: .everyNSegments(10),
///     keyProvider: RandomKeyProvider()
/// )
/// let key = try await manager.keyForSegment(index: 0)
/// ```
public actor LiveKeyManager<Provider: KeyProvider> {

    /// Current rotation policy.
    public let rotationPolicy: KeyRotationPolicy

    /// Key provider for generating/fetching keys.
    private let keyProvider: Provider

    /// Current active key.
    private var currentKey: LiveEncryptionKey?

    /// Segment index of last key rotation.
    private var lastRotationSegment: Int = 0

    /// Time of last key rotation.
    private var lastRotationTime: Date?

    /// Total number of key rotations performed.
    private var rotationCount: Int = 0

    /// Creates a live key manager.
    ///
    /// - Parameters:
    ///   - rotationPolicy: The key rotation policy.
    ///   - keyProvider: Provider for generating or fetching keys.
    public init(
        rotationPolicy: KeyRotationPolicy,
        keyProvider: Provider
    ) {
        self.rotationPolicy = rotationPolicy
        self.keyProvider = keyProvider
    }

    // MARK: - Key Management

    /// Get the encryption key for a given segment.
    ///
    /// May trigger a key rotation based on the policy.
    ///
    /// - Parameters:
    ///   - index: The segment index (0-based).
    ///   - timestamp: Current timestamp (default: now).
    /// - Returns: The encryption key for this segment.
    /// - Throws: If key generation fails.
    public func keyForSegment(
        index: Int,
        timestamp: Date = Date()
    ) async throws -> LiveEncryptionKey {
        if let current = currentKey {
            let elapsed: TimeInterval
            if let lastTime = lastRotationTime {
                elapsed = timestamp.timeIntervalSince(lastTime)
            } else {
                elapsed = 0
            }

            let shouldRotate = rotationPolicy.shouldRotate(
                segmentIndex: index,
                elapsed: elapsed,
                lastRotationSegment: lastRotationSegment
            )

            if shouldRotate {
                return try await performRotation(
                    segmentIndex: index,
                    timestamp: timestamp
                )
            }
            return current
        }

        // First key request — perform initial rotation.
        return try await performRotation(
            segmentIndex: index,
            timestamp: timestamp
        )
    }

    /// Force an immediate key rotation regardless of policy.
    ///
    /// - Returns: The new encryption key.
    /// - Throws: If key generation fails.
    @discardableResult
    public func forceKeyRotation() async throws -> LiveEncryptionKey {
        try await performRotation(
            segmentIndex: lastRotationSegment,
            timestamp: Date()
        )
    }

    /// Current rotation statistics.
    ///
    /// - Returns: Statistics about key rotations.
    public func statistics() -> KeyRotationStatistics {
        let timeSinceLast: TimeInterval?
        if let lastTime = lastRotationTime {
            timeSinceLast = Date().timeIntervalSince(lastTime)
        } else {
            timeSinceLast = nil
        }

        return KeyRotationStatistics(
            totalRotations: rotationCount,
            currentKeyID: currentKey?.keyID,
            timeSinceLastRotation: timeSinceLast,
            segmentsSinceLastRotation: 0
        )
    }

    /// Reset the manager (new stream).
    public func reset() {
        currentKey = nil
        lastRotationSegment = 0
        lastRotationTime = nil
        rotationCount = 0
    }

    // MARK: - Private

    private func performRotation(
        segmentIndex: Int,
        timestamp: Date
    ) async throws -> LiveEncryptionKey {
        let newKey = try await keyProvider.provideKey()
        currentKey = newKey
        lastRotationSegment = segmentIndex
        lastRotationTime = timestamp
        rotationCount += 1
        return newKey
    }
}

// MARK: - KeyProvider

/// Protocol for providing encryption keys.
///
/// Implement this to integrate with your key server.
public protocol KeyProvider: Sendable {

    /// Generate or fetch a new encryption key.
    ///
    /// - Returns: A new live encryption key.
    /// - Throws: If key generation or retrieval fails.
    func provideKey() async throws -> LiveEncryptionKey
}

// MARK: - LiveEncryptionKey

/// An encryption key for a live segment.
///
/// Contains the raw key data, IV, and metadata needed for both
/// encryption operations and HLS manifest generation.
///
/// ```swift
/// let key = LiveEncryptionKey(
///     keyData: keyBytes,
///     iv: ivBytes,
///     keyURI: "https://keys.example.com/key1"
/// )
/// let encryptionKey = key.toEncryptionKey()
/// ```
public struct LiveEncryptionKey: Sendable, Equatable {

    /// Raw key data (16 bytes for AES-128, 32 for AES-256).
    public let keyData: Data

    /// Initialization vector (16 bytes).
    public let iv: Data

    /// URI where the client fetches this key.
    public let keyURI: String

    /// Encryption method.
    public let method: EncryptionMethod

    /// Key format identifier.
    public let keyFormat: String?

    /// Key format versions.
    public let keyFormatVersions: String?

    /// Unique key identifier.
    public let keyID: String

    /// Creates a live encryption key.
    ///
    /// - Parameters:
    ///   - keyData: Raw key data.
    ///   - iv: Initialization vector.
    ///   - keyURI: URI where the client fetches this key.
    ///   - method: Encryption method (default: `.sampleAESCTR`).
    ///   - keyFormat: Key format identifier.
    ///   - keyFormatVersions: Key format versions.
    ///   - keyID: Unique key identifier (default: generated UUID).
    public init(
        keyData: Data,
        iv: Data,
        keyURI: String,
        method: EncryptionMethod = .sampleAESCTR,
        keyFormat: String? = nil,
        keyFormatVersions: String? = nil,
        keyID: String = UUID().uuidString
    ) {
        self.keyData = keyData
        self.iv = iv
        self.keyURI = keyURI
        self.method = method
        self.keyFormat = keyFormat
        self.keyFormatVersions = keyFormatVersions
        self.keyID = keyID
    }

    /// Converts to the existing ``EncryptionKey`` model for manifest generation.
    ///
    /// - Returns: An ``EncryptionKey`` with hex-encoded IV.
    public func toEncryptionKey() -> EncryptionKey {
        let ivHex = "0x" + iv.map { String(format: "%02x", $0) }.joined()
        return EncryptionKey(
            method: method,
            uri: keyURI,
            iv: ivHex,
            keyFormat: keyFormat,
            keyFormatVersions: keyFormatVersions
        )
    }
}

// MARK: - KeyRotationStatistics

/// Key rotation statistics.
///
/// Tracks the state of key rotations for monitoring and debugging.
public struct KeyRotationStatistics: Sendable, Equatable {

    /// Total rotations since start.
    public let totalRotations: Int

    /// Current key ID.
    public let currentKeyID: String?

    /// Time since last rotation.
    public let timeSinceLastRotation: TimeInterval?

    /// Segments since last rotation.
    public let segmentsSinceLastRotation: Int

    /// Creates key rotation statistics.
    ///
    /// - Parameters:
    ///   - totalRotations: Total rotations since start.
    ///   - currentKeyID: Current key ID.
    ///   - timeSinceLastRotation: Time since last rotation.
    ///   - segmentsSinceLastRotation: Segments since last rotation.
    public init(
        totalRotations: Int,
        currentKeyID: String?,
        timeSinceLastRotation: TimeInterval?,
        segmentsSinceLastRotation: Int
    ) {
        self.totalRotations = totalRotations
        self.currentKeyID = currentKeyID
        self.timeSinceLastRotation = timeSinceLastRotation
        self.segmentsSinceLastRotation = segmentsSinceLastRotation
    }
}

// MARK: - RandomKeyProvider

/// Default key provider that generates random keys locally.
///
/// For production, replace with your KSM-backed provider.
///
/// ```swift
/// let provider = RandomKeyProvider()
/// let key = try await provider.provideKey()
/// ```
public struct RandomKeyProvider: KeyProvider, Sendable {

    /// Encryption method for generated keys.
    public let method: EncryptionMethod

    /// URI template for key URIs. `{id}` is replaced with the key ID.
    public let keyURITemplate: String

    /// Creates a random key provider.
    ///
    /// - Parameters:
    ///   - method: Encryption method (default: `.aes128`).
    ///   - keyURITemplate: URI template with `{id}` placeholder.
    public init(
        method: EncryptionMethod = .aes128,
        keyURITemplate: String = "https://keys.example.com/{id}"
    ) {
        self.method = method
        self.keyURITemplate = keyURITemplate
    }

    /// Generate a random encryption key.
    ///
    /// - Returns: A new live encryption key with random data.
    /// - Throws: If random generation fails.
    public func provideKey() async throws -> LiveEncryptionKey {
        let manager = KeyManager()
        let keyData = try manager.generateKey()
        let iv = try manager.generateIV()
        let keyID = UUID().uuidString
        let uri = keyURITemplate.replacingOccurrences(of: "{id}", with: keyID)

        return LiveEncryptionKey(
            keyData: keyData,
            iv: iv,
            keyURI: uri,
            method: method,
            keyID: keyID
        )
    }
}
