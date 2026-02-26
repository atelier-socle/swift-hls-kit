// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LiveDRMPipeline — Facade")
struct LiveDRMPipelineTests {

    @Test("Init with FairPlay only is enabled but not multiDRM")
    func fairPlayOnly() {
        let pipeline = LiveDRMPipeline(fairPlay: .modern)
        #expect(pipeline.isEnabled)
        #expect(!pipeline.isMultiDRM)
    }

    @Test("Init with FairPlay + CENC is enabled and multiDRM")
    func fairPlayPlusCENC() {
        let cenc = CENCConfig(
            systems: [.widevine],
            defaultKeyID: "k1"
        )
        let pipeline = LiveDRMPipeline(
            fairPlay: .modern,
            cenc: cenc
        )
        #expect(pipeline.isEnabled)
        #expect(pipeline.isMultiDRM)
    }

    @Test("Init without FairPlay or CENC is not enabled")
    func noDRM() {
        let pipeline = LiveDRMPipeline<RandomKeyProvider>()
        #expect(!pipeline.isEnabled)
        #expect(!pipeline.isMultiDRM)
    }

    @Test("keyForSegment delegates to key manager")
    func keyForSegmentDelegation() async throws {
        let pipeline = LiveDRMPipeline(
            fairPlay: .modern,
            keyProvider: MockKeyProvider()
        )
        let key = try await pipeline.keyForSegment(index: 0)
        #expect(key.keyData.count == 16)
        #expect(key.iv.count == 16)
    }

    @Test("sessionKeys with FairPlay includes FairPlay session key")
    func sessionKeysWithFairPlay() {
        let pipeline = LiveDRMPipeline(fairPlay: .modern)
        let keys = pipeline.sessionKeys(
            currentKeyURI: "skd://key1"
        )
        #expect(keys.count == 1)
        #expect(keys[0].keyFormat == "com.apple.streamingkeydelivery")
    }

    @Test("sessionKeys with multi-DRM includes multiple keys")
    func sessionKeysMultiDRM() {
        let cenc = CENCConfig(
            systems: [.widevine, .playReady],
            defaultKeyID: "k1"
        )
        let pipeline = LiveDRMPipeline(
            fairPlay: .modern,
            cenc: cenc
        )
        let keys = pipeline.sessionKeys(
            currentKeyURI: "https://keys.example.com/k1"
        )
        // 1 FairPlay + 2 CENC = 3 session keys
        #expect(keys.count == 3)
    }

    @Test("sessionKeys without enableSessionKey excludes FairPlay")
    func sessionKeysDisabledFairPlay() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let fpConfig = FairPlayLiveConfig(
            keyServerURL: url,
            enableSessionKey: false
        )
        let pipeline = LiveDRMPipeline(fairPlay: fpConfig)
        let keys = pipeline.sessionKeys(
            currentKeyURI: "skd://key1"
        )
        #expect(keys.isEmpty)
    }

    @Test("statistics returns valid data")
    func statisticsReturnsData() async throws {
        let pipeline = LiveDRMPipeline(
            fairPlay: .modern,
            keyProvider: MockKeyProvider()
        )
        _ = try await pipeline.keyForSegment(index: 0)
        let stats = await pipeline.statistics()
        #expect(stats.totalRotations == 1)
        #expect(stats.currentKeyID != nil)
    }

    @Test("fairPlayOnly preset creates correct pipeline")
    func fairPlayOnlyPreset() {
        let pipeline = LiveDRMPipeline.fairPlayOnly()
        #expect(pipeline.isEnabled)
        #expect(!pipeline.isMultiDRM)
        #expect(pipeline.fairPlay?.method == .sampleAESCTR)
        #expect(pipeline.rotationPolicy == .everyNSegments(10))
    }

    @Test("fairPlayOnly preset with custom rotation")
    func fairPlayOnlyCustomRotation() {
        let pipeline = LiveDRMPipeline.fairPlayOnly(
            rotation: .everySegment
        )
        #expect(pipeline.rotationPolicy == .everySegment)
    }

    @Test("multiDRM preset creates correct pipeline")
    func multiDRMPreset() {
        let pipeline = LiveDRMPipeline.multiDRM()
        #expect(pipeline.isEnabled)
        #expect(pipeline.isMultiDRM)
        #expect(pipeline.fairPlay?.method == .sampleAESCTR)
        #expect(pipeline.cenc?.systems.count == 2)
    }

    @Test("multiDRM preset with custom systems")
    func multiDRMCustomSystems() {
        let pipeline = LiveDRMPipeline.multiDRM(
            cencSystems: [.widevine]
        )
        #expect(pipeline.cenc?.systems.count == 1)
        #expect(pipeline.cenc?.systems.first == .widevine)
    }

    @Test("Pipeline with .none rotation does not rotate")
    func noneRotation() async throws {
        let pipeline = LiveDRMPipeline(
            fairPlay: .modern,
            rotationPolicy: .none,
            keyProvider: MockKeyProvider()
        )
        let key1 = try await pipeline.keyForSegment(index: 0)
        let key2 = try await pipeline.keyForSegment(index: 100)
        #expect(key1.keyID == key2.keyID)
    }

    @Test("rotationPolicy is preserved")
    func rotationPolicyPreserved() {
        let pipeline = LiveDRMPipeline(
            rotationPolicy: .interval(60)
        )
        #expect(pipeline.rotationPolicy == .interval(60))
    }
}
