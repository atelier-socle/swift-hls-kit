// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CENCConfig — CENC Interop")
struct DRMInteropTests {

    @Test("CENCSystem has three cases")
    func systemCases() {
        let cases = CENCConfig.CENCSystem.allCases
        #expect(cases.count == 3)
        #expect(cases.contains(.widevine))
        #expect(cases.contains(.playReady))
        #expect(cases.contains(.fairPlay))
    }

    @Test("systemID for Widevine matches DASH-IF spec")
    func widevineSystemID() {
        let id = CENCConfig.systemID(for: .widevine)
        #expect(id == "edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")
    }

    @Test("systemID for PlayReady matches DASH-IF spec")
    func playReadySystemID() {
        let id = CENCConfig.systemID(for: .playReady)
        #expect(id == "9a04f079-9840-4286-ab92-e65be0885f95")
    }

    @Test("systemID for FairPlay matches DASH-IF spec")
    func fairPlaySystemID() {
        let id = CENCConfig.systemID(for: .fairPlay)
        #expect(id == "94ce86fb-07ff-4f43-adb8-93d2fa968ca2")
    }

    @Test("keyFormat for Widevine")
    func widevineKeyFormat() {
        let format = CENCConfig.keyFormat(for: .widevine)
        #expect(format == "urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed")
    }

    @Test("keyFormat for PlayReady")
    func playReadyKeyFormat() {
        let format = CENCConfig.keyFormat(for: .playReady)
        #expect(format == "urn:uuid:9a04f079-9840-4286-ab92-e65be0885f95")
    }

    @Test("keyFormat for FairPlay")
    func fairPlayKeyFormat() {
        let format = CENCConfig.keyFormat(for: .fairPlay)
        #expect(format == "com.apple.streamingkeydelivery")
    }

    @Test("psshBoxData returns non-empty data for Widevine")
    func psshWidevine() {
        let config = CENCConfig(
            systems: [.widevine],
            defaultKeyID: "key-001"
        )
        let data = config.psshBoxData(for: .widevine)
        #expect(!data.isEmpty)
        #expect(data.count > 16)
    }

    @Test("psshBoxData returns non-empty data for PlayReady")
    func psshPlayReady() {
        let config = CENCConfig(
            systems: [.playReady],
            defaultKeyID: "key-001"
        )
        let data = config.psshBoxData(for: .playReady)
        #expect(!data.isEmpty)
    }

    @Test("psshBoxData with custom keyID uses override")
    func psshCustomKeyID() {
        let config = CENCConfig(
            systems: [.widevine],
            defaultKeyID: "default-key"
        )
        let data1 = config.psshBoxData(for: .widevine)
        let data2 = config.psshBoxData(for: .widevine, keyID: "custom-key")
        #expect(data1 != data2)
    }

    @Test("psshBoxData contains PSSH type box")
    func psshContainsType() {
        let config = CENCConfig(
            systems: [.widevine],
            defaultKeyID: "key-001"
        )
        let data = config.psshBoxData(for: .widevine)
        // "pssh" in ASCII: 0x70, 0x73, 0x73, 0x68
        #expect(data.count >= 8)
        #expect(data[4] == 0x70)
        #expect(data[5] == 0x73)
        #expect(data[6] == 0x73)
        #expect(data[7] == 0x68)
    }

    @Test("Init with multiple systems")
    func initMultipleSystems() {
        let config = CENCConfig(
            systems: [.widevine, .playReady, .fairPlay],
            defaultKeyID: "multi-key"
        )
        #expect(config.systems.count == 3)
        #expect(config.defaultKeyID == "multi-key")
    }

    @Test("licenseServers mapping")
    func licenseServers() {
        let config = CENCConfig(
            systems: [.widevine, .playReady],
            defaultKeyID: "k1",
            licenseServers: [
                .widevine: "https://widevine.example.com/license",
                .playReady: "https://playready.example.com/license"
            ]
        )
        #expect(config.licenseServers[.widevine] == "https://widevine.example.com/license")
        #expect(config.licenseServers[.playReady] == "https://playready.example.com/license")
    }

    @Test("CENCSystem Hashable conformance")
    func hashable() {
        let set: Set<CENCConfig.CENCSystem> = [.widevine, .playReady, .widevine]
        #expect(set.count == 2)
    }

    @Test("CENCConfig Equatable conformance")
    func equatable() {
        let config1 = CENCConfig(
            systems: [.widevine],
            defaultKeyID: "k1"
        )
        let config2 = CENCConfig(
            systems: [.widevine],
            defaultKeyID: "k1"
        )
        #expect(config1 == config2)
    }

    @Test("CENCConfig detects differences")
    func equatableDifference() {
        let config1 = CENCConfig(
            systems: [.widevine],
            defaultKeyID: "k1"
        )
        let config2 = CENCConfig(
            systems: [.playReady],
            defaultKeyID: "k1"
        )
        #expect(config1 != config2)
    }
}
