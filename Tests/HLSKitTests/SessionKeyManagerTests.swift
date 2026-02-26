// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SessionKeyManager — Session Keys")
struct SessionKeyManagerTests {

    @Test("Init empty has zero systems")
    func initEmpty() {
        let manager = SessionKeyManager()
        #expect(manager.systemCount == 0)
    }

    @Test("addDRMSystem increases count")
    func addSystem() {
        var manager = SessionKeyManager()
        manager.addDRMSystem(.fairPlay(.modern))
        #expect(manager.systemCount == 1)
        manager.addDRMSystem(
            .cenc(
                CENCConfig(
                    systems: [.widevine],
                    defaultKeyID: "k1"
                )))
        #expect(manager.systemCount == 2)
    }

    @Test("removeAllSystems resets count to zero")
    func removeAll() {
        var manager = SessionKeyManager()
        manager.addDRMSystem(.fairPlay(.modern))
        manager.addDRMSystem(.fairPlay(.legacy))
        manager.removeAllSystems()
        #expect(manager.systemCount == 0)
    }

    @Test("generateSessionKeys with FairPlay produces correct keyFormat")
    func fairPlaySessionKey() {
        var manager = SessionKeyManager()
        manager.addDRMSystem(.fairPlay(.modern))
        let keys = manager.generateSessionKeys(
            currentKeyURI: "skd://key1"
        )
        #expect(keys.count == 1)
        #expect(keys[0].keyFormat == "com.apple.streamingkeydelivery")
        #expect(keys[0].method == .sampleAESCTR)
        #expect(keys[0].uri == "skd://key1")
    }

    @Test("generateSessionKeys with CENC produces one key per system")
    func cencSessionKeys() {
        var manager = SessionKeyManager()
        let cenc = CENCConfig(
            systems: [.widevine, .playReady],
            defaultKeyID: "k1"
        )
        manager.addDRMSystem(.cenc(cenc))
        let keys = manager.generateSessionKeys(
            currentKeyURI: "https://keys.example.com/k1"
        )
        #expect(keys.count == 2)
        let formats = Set(keys.map { $0.keyFormat ?? "" })
        #expect(formats.contains(CENCConfig.keyFormat(for: .widevine)))
        #expect(formats.contains(CENCConfig.keyFormat(for: .playReady)))
    }

    @Test("generateSessionKeys with multiple systems produces all keys")
    func multipleSystemsSessionKeys() {
        var manager = SessionKeyManager()
        manager.addDRMSystem(.fairPlay(.modern))
        manager.addDRMSystem(
            .cenc(
                CENCConfig(
                    systems: [.widevine],
                    defaultKeyID: "k1"
                )))
        let keys = manager.generateSessionKeys(
            currentKeyURI: "https://keys.example.com/k1"
        )
        #expect(keys.count == 2)
    }

    @Test("generateSessionKeys with custom DRM system")
    func customSystem() {
        var manager = SessionKeyManager()
        manager.addDRMSystem(
            .custom(
                method: .aes128,
                keyFormat: "com.custom.drm",
                keyFormatVersions: "2"
            ))
        let keys = manager.generateSessionKeys(
            currentKeyURI: "https://custom.example.com/k1"
        )
        #expect(keys.count == 1)
        #expect(keys[0].method == .aes128)
        #expect(keys[0].keyFormat == "com.custom.drm")
        #expect(keys[0].keyFormatVersions == "2")
    }

    @Test("generateSessionKeys passes IV when provided")
    func sessionKeyWithIV() {
        var manager = SessionKeyManager()
        manager.addDRMSystem(.fairPlay(.modern))
        let keys = manager.generateSessionKeys(
            currentKeyURI: "skd://key1",
            iv: "0x00000001"
        )
        #expect(keys[0].iv == "0x00000001")
    }

    @Test("generateSessionKeys with no systems returns empty")
    func noSystemsEmpty() {
        let manager = SessionKeyManager()
        let keys = manager.generateSessionKeys(
            currentKeyURI: "https://keys.example.com/k1"
        )
        #expect(keys.isEmpty)
    }

    @Test("DRMSystem.fairPlay equatable")
    func fairPlayEquatable() {
        let system1 = SessionKeyManager.DRMSystem.fairPlay(.modern)
        let system2 = SessionKeyManager.DRMSystem.fairPlay(.modern)
        #expect(system1 == system2)
    }

    @Test("DRMSystem.cenc equatable")
    func cencEquatable() {
        let config = CENCConfig(systems: [.widevine], defaultKeyID: "k1")
        let system1 = SessionKeyManager.DRMSystem.cenc(config)
        let system2 = SessionKeyManager.DRMSystem.cenc(config)
        #expect(system1 == system2)
    }

    @Test("DRMSystem.custom equatable")
    func customEquatable() {
        let s1 = SessionKeyManager.DRMSystem.custom(
            method: .aes128, keyFormat: "fmt", keyFormatVersions: "1"
        )
        let s2 = SessionKeyManager.DRMSystem.custom(
            method: .aes128, keyFormat: "fmt", keyFormatVersions: "1"
        )
        #expect(s1 == s2)
    }

    @Test("SessionKeyManager Equatable conformance")
    func managerEquatable() {
        let m1 = SessionKeyManager()
        let m2 = SessionKeyManager()
        #expect(m1 == m2)
    }
}
