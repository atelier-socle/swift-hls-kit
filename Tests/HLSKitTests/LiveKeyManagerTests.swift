// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Mock Key Provider

/// Deterministic key provider for testing.
struct MockKeyProvider: KeyProvider, Sendable {
    let prefix: String

    init(prefix: String = "mock") {
        self.prefix = prefix
    }

    func provideKey() async throws -> LiveEncryptionKey {
        let keyID = "\(prefix)-\(UUID().uuidString)"
        return LiveEncryptionKey(
            keyData: Data(repeating: 0xAB, count: 16),
            iv: Data(repeating: 0xCD, count: 16),
            keyURI: "https://keys.example.com/\(keyID)",
            method: .aes128,
            keyID: keyID
        )
    }
}

// MARK: - LiveKeyManager Tests

@Suite("LiveKeyManager — Key Lifecycle")
struct LiveKeyManagerTests {

    @Test("Init with policy and provider")
    func initWithPolicyAndProvider() async {
        let manager = LiveKeyManager(
            rotationPolicy: .everyNSegments(10),
            keyProvider: MockKeyProvider()
        )
        let stats = await manager.statistics()
        #expect(stats.totalRotations == 0)
        #expect(stats.currentKeyID == nil)
    }

    @Test("keyForSegment returns a key on first call")
    func firstKeyRequest() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .none,
            keyProvider: MockKeyProvider()
        )
        let key = try await manager.keyForSegment(index: 0)
        #expect(key.keyData.count == 16)
        #expect(key.iv.count == 16)
        #expect(key.method == .aes128)
    }

    @Test("keyForSegment with .none returns same key for all segments")
    func noRotationSameKey() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .none,
            keyProvider: MockKeyProvider()
        )
        let key1 = try await manager.keyForSegment(index: 0)
        let key2 = try await manager.keyForSegment(index: 1)
        let key3 = try await manager.keyForSegment(index: 100)
        #expect(key1.keyID == key2.keyID)
        #expect(key2.keyID == key3.keyID)
    }

    @Test("keyForSegment with .everySegment gives new key each segment")
    func everySegmentNewKey() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .everySegment,
            keyProvider: MockKeyProvider()
        )
        let key0 = try await manager.keyForSegment(index: 0)
        let key1 = try await manager.keyForSegment(index: 1)
        let key2 = try await manager.keyForSegment(index: 2)
        #expect(key0.keyID != key1.keyID)
        #expect(key1.keyID != key2.keyID)
    }

    @Test("keyForSegment with .everyNSegments(5) rotates at boundary")
    func everyNSegmentsRotation() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .everyNSegments(5),
            keyProvider: MockKeyProvider()
        )
        let key0 = try await manager.keyForSegment(index: 0)
        let key1 = try await manager.keyForSegment(index: 1)
        let key4 = try await manager.keyForSegment(index: 4)
        #expect(key0.keyID == key1.keyID)
        #expect(key0.keyID == key4.keyID)

        let key5 = try await manager.keyForSegment(index: 5)
        #expect(key5.keyID != key0.keyID)
    }

    @Test("keyForSegment with .manual never rotates automatically")
    func manualNoAutoRotation() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .manual,
            keyProvider: MockKeyProvider()
        )
        let key0 = try await manager.keyForSegment(index: 0)
        let key100 = try await manager.keyForSegment(index: 100)
        #expect(key0.keyID == key100.keyID)
    }

    @Test("forceKeyRotation produces a new key")
    func forceRotation() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .none,
            keyProvider: MockKeyProvider()
        )
        let key1 = try await manager.keyForSegment(index: 0)
        let key2 = try await manager.forceKeyRotation()
        #expect(key1.keyID != key2.keyID)
    }

    @Test("statistics tracks rotation count")
    func statisticsTracking() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .everySegment,
            keyProvider: MockKeyProvider()
        )
        _ = try await manager.keyForSegment(index: 0)
        _ = try await manager.keyForSegment(index: 1)
        _ = try await manager.keyForSegment(index: 2)

        let stats = await manager.statistics()
        #expect(stats.totalRotations == 3)
        #expect(stats.currentKeyID != nil)
    }

    @Test("statistics after force rotation")
    func statisticsAfterForce() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .none,
            keyProvider: MockKeyProvider()
        )
        _ = try await manager.keyForSegment(index: 0)
        _ = try await manager.forceKeyRotation()
        _ = try await manager.forceKeyRotation()

        let stats = await manager.statistics()
        #expect(stats.totalRotations == 3)
    }

    @Test("reset clears all state")
    func resetState() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .everySegment,
            keyProvider: MockKeyProvider()
        )
        _ = try await manager.keyForSegment(index: 0)
        _ = try await manager.keyForSegment(index: 1)
        await manager.reset()

        let stats = await manager.statistics()
        #expect(stats.totalRotations == 0)
        #expect(stats.currentKeyID == nil)
    }

    @Test("keyForSegment after reset provides new key")
    func keyAfterReset() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .none,
            keyProvider: MockKeyProvider()
        )
        let key1 = try await manager.keyForSegment(index: 0)
        await manager.reset()
        let key2 = try await manager.keyForSegment(index: 0)
        #expect(key1.keyID != key2.keyID)
    }
}

// MARK: - LiveEncryptionKey Tests

@Suite("LiveEncryptionKey — Model")
struct LiveEncryptionKeyTests {

    @Test("toEncryptionKey produces correct mapping")
    func toEncryptionKey() {
        let key = LiveEncryptionKey(
            keyData: Data(repeating: 0xFF, count: 16),
            iv: Data([
                0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
            ]),
            keyURI: "https://keys.example.com/key1",
            method: .aes128,
            keyFormat: "identity",
            keyFormatVersions: "1",
            keyID: "test-key"
        )
        let enc = key.toEncryptionKey()
        #expect(enc.method == .aes128)
        #expect(enc.uri == "https://keys.example.com/key1")
        #expect(enc.iv == "0x000102030405060708090a0b0c0d0e0f")
        #expect(enc.keyFormat == "identity")
        #expect(enc.keyFormatVersions == "1")
    }

    @Test("toEncryptionKey with nil keyFormat")
    func toEncryptionKeyNilFormat() {
        let key = LiveEncryptionKey(
            keyData: Data(repeating: 0xAB, count: 16),
            iv: Data(repeating: 0x00, count: 16),
            keyURI: "https://keys.example.com/key2",
            keyID: "test-key-2"
        )
        let enc = key.toEncryptionKey()
        #expect(enc.keyFormat == nil)
        #expect(enc.keyFormatVersions == nil)
    }

    @Test("Equatable conformance")
    func equatable() {
        let key1 = LiveEncryptionKey(
            keyData: Data(repeating: 0xAB, count: 16),
            iv: Data(repeating: 0xCD, count: 16),
            keyURI: "https://keys.example.com/k1",
            keyID: "same-id"
        )
        let key2 = LiveEncryptionKey(
            keyData: Data(repeating: 0xAB, count: 16),
            iv: Data(repeating: 0xCD, count: 16),
            keyURI: "https://keys.example.com/k1",
            keyID: "same-id"
        )
        #expect(key1 == key2)
    }

    @Test("Default method is sampleAESCTR")
    func defaultMethod() {
        let key = LiveEncryptionKey(
            keyData: Data(repeating: 0x00, count: 16),
            iv: Data(repeating: 0x00, count: 16),
            keyURI: "https://keys.example.com/k",
            keyID: "k"
        )
        #expect(key.method == .sampleAESCTR)
    }
}

// MARK: - RandomKeyProvider Tests

@Suite("RandomKeyProvider — Key Generation")
struct RandomKeyProviderTests {

    @Test("provideKey generates 16-byte key data")
    func keyDataSize() async throws {
        let provider = RandomKeyProvider()
        let key = try await provider.provideKey()
        #expect(key.keyData.count == 16)
    }

    @Test("provideKey generates 16-byte IV")
    func ivSize() async throws {
        let provider = RandomKeyProvider()
        let key = try await provider.provideKey()
        #expect(key.iv.count == 16)
    }

    @Test("provideKey generates valid URI from template")
    func uriFromTemplate() async throws {
        let provider = RandomKeyProvider(
            keyURITemplate: "https://my-server.com/keys/{id}"
        )
        let key = try await provider.provideKey()
        #expect(key.keyURI.hasPrefix("https://my-server.com/keys/"))
        #expect(!key.keyURI.contains("{id}"))
    }

    @Test("provideKey uses configured method")
    func configuredMethod() async throws {
        let provider = RandomKeyProvider(method: .sampleAESCTR)
        let key = try await provider.provideKey()
        #expect(key.method == .sampleAESCTR)
    }

    @Test("provideKey generates unique keys")
    func uniqueKeys() async throws {
        let provider = RandomKeyProvider()
        let key1 = try await provider.provideKey()
        let key2 = try await provider.provideKey()
        #expect(key1.keyID != key2.keyID)
    }

    @Test("Default method is AES-128")
    func defaultMethod() {
        let provider = RandomKeyProvider()
        #expect(provider.method == .aes128)
    }
}

// MARK: - KeyRotationStatistics Tests

@Suite("KeyRotationStatistics — Model")
struct KeyRotationStatisticsTests {

    @Test("Init with all values")
    func initAll() {
        let stats = KeyRotationStatistics(
            totalRotations: 5,
            currentKeyID: "key-5",
            timeSinceLastRotation: 30.0,
            segmentsSinceLastRotation: 3
        )
        #expect(stats.totalRotations == 5)
        #expect(stats.currentKeyID == "key-5")
        #expect(stats.timeSinceLastRotation == 30.0)
        #expect(stats.segmentsSinceLastRotation == 3)
    }

    @Test("Init with nil values")
    func initNil() {
        let stats = KeyRotationStatistics(
            totalRotations: 0,
            currentKeyID: nil,
            timeSinceLastRotation: nil,
            segmentsSinceLastRotation: 0
        )
        #expect(stats.currentKeyID == nil)
        #expect(stats.timeSinceLastRotation == nil)
    }
}
