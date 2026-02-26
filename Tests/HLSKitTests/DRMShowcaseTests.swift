// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - DRM Showcase

@Suite("DRM Live — Showcase Scenarios")
struct DRMShowcaseTests {

    @Test("FairPlay live stream with key rotation every 10 segments")
    func fairPlayKeyRotation() async throws {
        let pipeline = LiveDRMPipeline.fairPlayOnly(
            config: .modern,
            rotation: .everyNSegments(10)
        )
        let key0 = try await pipeline.keyForSegment(index: 0)
        let key5 = try await pipeline.keyForSegment(index: 5)
        #expect(key0.keyID == key5.keyID)

        let key10 = try await pipeline.keyForSegment(index: 10)
        #expect(key10.keyID != key0.keyID)
    }

    @Test("Multi-DRM: FairPlay + Widevine + PlayReady")
    func multiDRMSystems() {
        let pipeline = LiveDRMPipeline.multiDRM(
            cencSystems: [.widevine, .playReady]
        )
        let keys = pipeline.sessionKeys(
            currentKeyURI: "https://keys.example.com/k1"
        )
        // 1 FairPlay + 2 CENC
        #expect(keys.count == 3)

        let formats = keys.compactMap(\.keyFormat)
        #expect(formats.contains("com.apple.streamingkeydelivery"))
        #expect(formats.contains(CENCConfig.keyFormat(for: .widevine)))
        #expect(formats.contains(CENCConfig.keyFormat(for: .playReady)))
    }

    @Test("No rotation: single key for entire stream")
    func noRotationSingleKey() async throws {
        let pipeline = LiveDRMPipeline(
            fairPlay: .modern,
            rotationPolicy: .none,
            keyProvider: MockKeyProvider()
        )
        let key0 = try await pipeline.keyForSegment(index: 0)
        let key999 = try await pipeline.keyForSegment(index: 999)
        #expect(key0.keyID == key999.keyID)
    }

    @Test("Manual key rotation triggered by app")
    func manualRotation() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .manual,
            keyProvider: MockKeyProvider()
        )
        let key1 = try await manager.keyForSegment(index: 0)
        let key2 = try await manager.keyForSegment(index: 100)
        #expect(key1.keyID == key2.keyID)

        let key3 = try await manager.forceKeyRotation()
        #expect(key3.keyID != key1.keyID)
    }

    @Test("Session key pre-fetching for fast start")
    func sessionKeyPreFetching() {
        let pipeline = LiveDRMPipeline.fairPlayOnly()
        let keys = pipeline.sessionKeys(
            currentKeyURI: "skd://fast-start-key"
        )
        #expect(keys.count == 1)
        #expect(keys[0].method == .sampleAESCTR)
        #expect(keys[0].keyFormat == "com.apple.streamingkeydelivery")
        #expect(keys[0].uri == "skd://fast-start-key")
    }

    @Test("Legacy FairPlay with SAMPLE-AES")
    func legacyFairPlay() {
        let pipeline = LiveDRMPipeline.fairPlayOnly(config: .legacy)
        let keys = pipeline.sessionKeys(
            currentKeyURI: "skd://legacy-key"
        )
        #expect(keys[0].method == .sampleAES)
    }

    @Test("CENC system IDs match DASH-IF specification")
    func cencSystemIDs() {
        #expect(
            CENCConfig.systemID(for: .widevine)
                == "edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"
        )
        #expect(
            CENCConfig.systemID(for: .playReady)
                == "9a04f079-9840-4286-ab92-e65be0885f95"
        )
        #expect(
            CENCConfig.systemID(for: .fairPlay)
                == "94ce86fb-07ff-4f43-adb8-93d2fa968ca2"
        )
    }

    @Test("Key rotation statistics tracking")
    func rotationStatistics() async throws {
        let manager = LiveKeyManager(
            rotationPolicy: .everySegment,
            keyProvider: MockKeyProvider()
        )
        _ = try await manager.keyForSegment(index: 0)
        _ = try await manager.keyForSegment(index: 1)
        _ = try await manager.keyForSegment(index: 2)
        _ = try await manager.keyForSegment(index: 3)

        let stats = await manager.statistics()
        #expect(stats.totalRotations == 4)
        #expect(stats.currentKeyID != nil)
        #expect(stats.timeSinceLastRotation != nil)
    }

    @Test("Complete DRM pipeline: config → key → manifest attributes")
    func completePipeline() async throws {
        let pipeline = LiveDRMPipeline.fairPlayOnly()
        let key = try await pipeline.keyForSegment(index: 0)

        // Convert to EncryptionKey for manifest
        let encKey = key.toEncryptionKey()
        #expect(encKey.method == .aes128)
        #expect(encKey.uri == key.keyURI)
        #expect(encKey.iv?.hasPrefix("0x") == true)

        // Generate session keys
        let sessionKeys = pipeline.sessionKeys(
            currentKeyURI: key.keyURI
        )
        #expect(sessionKeys.count == 1)
        #expect(sessionKeys[0].keyFormat == "com.apple.streamingkeydelivery")
    }

    @Test("Random key provider generates valid encryption keys")
    func randomKeyProvider() async throws {
        let provider = RandomKeyProvider(
            method: .sampleAESCTR,
            keyURITemplate: "https://keys.example.com/{id}"
        )
        let key = try await provider.provideKey()
        #expect(key.keyData.count == 16)
        #expect(key.iv.count == 16)
        #expect(key.method == .sampleAESCTR)
        #expect(key.keyURI.hasPrefix("https://keys.example.com/"))
        #expect(!key.keyID.isEmpty)
    }
}
