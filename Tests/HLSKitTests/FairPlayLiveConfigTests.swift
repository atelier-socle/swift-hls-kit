// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("FairPlayLiveConfig — Configuration")
struct FairPlayLiveConfigTests {

    @Test("Init with default values uses CBCS and session key enabled")
    func initDefaults() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config = FairPlayLiveConfig(keyServerURL: url)
        #expect(config.method == .sampleAESCTR)
        #expect(config.keyFormat == "com.apple.streamingkeydelivery")
        #expect(config.keyFormatVersions == "1")
        #expect(config.enableSessionKey == true)
    }

    @Test("Init with custom values preserves all properties")
    func initCustom() throws {
        let url = try #require(URL(string: "https://custom.example.com/fps"))
        let config = FairPlayLiveConfig(
            keyServerURL: url,
            method: .sampleAES,
            keyFormat: "custom-format",
            keyFormatVersions: "1/2",
            enableSessionKey: false
        )
        #expect(config.keyServerURL == url)
        #expect(config.method == .sampleAES)
        #expect(config.keyFormat == "custom-format")
        #expect(config.keyFormatVersions == "1/2")
        #expect(config.enableSessionKey == false)
    }

    @Test("FairPlayMethod has two cases")
    func methodCases() {
        let cases = FairPlayLiveConfig.FairPlayMethod.allCases
        #expect(cases.count == 2)
        #expect(cases.contains(.sampleAES))
        #expect(cases.contains(.sampleAESCTR))
    }

    @Test("FairPlayMethod raw values match HLS spec")
    func methodRawValues() {
        #expect(FairPlayLiveConfig.FairPlayMethod.sampleAES.rawValue == "SAMPLE-AES")
        #expect(FairPlayLiveConfig.FairPlayMethod.sampleAESCTR.rawValue == "SAMPLE-AES-CTR")
    }

    @Test("encryptionMethod maps sampleAES correctly")
    func encryptionMethodSampleAES() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config = FairPlayLiveConfig(keyServerURL: url, method: .sampleAES)
        #expect(config.encryptionMethod == .sampleAES)
    }

    @Test("encryptionMethod maps sampleAESCTR correctly")
    func encryptionMethodSampleAESCTR() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config = FairPlayLiveConfig(keyServerURL: url, method: .sampleAESCTR)
        #expect(config.encryptionMethod == .sampleAESCTR)
    }

    @Test("keyAttributes produces correct EncryptionKey")
    func keyAttributesGeneration() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config = FairPlayLiveConfig(keyServerURL: url)
        let key = config.keyAttributes(keyURI: "skd://key123", iv: "0x00000001")
        #expect(key.method == .sampleAESCTR)
        #expect(key.uri == "skd://key123")
        #expect(key.iv == "0x00000001")
        #expect(key.keyFormat == "com.apple.streamingkeydelivery")
        #expect(key.keyFormatVersions == "1")
    }

    @Test("keyAttributes with nil IV omits IV")
    func keyAttributesNilIV() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config = FairPlayLiveConfig(keyServerURL: url)
        let key = config.keyAttributes(keyURI: "skd://key123", iv: nil)
        #expect(key.iv == nil)
    }

    @Test("sessionKeyEntry produces correct EncryptionKey")
    func sessionKeyEntry() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config = FairPlayLiveConfig(keyServerURL: url)
        let key = config.sessionKeyEntry(keyURI: "skd://session-key")
        #expect(key.method == .sampleAESCTR)
        #expect(key.uri == "skd://session-key")
        #expect(key.iv == nil)
        #expect(key.keyFormat == "com.apple.streamingkeydelivery")
        #expect(key.keyFormatVersions == "1")
    }

    @Test("enableSessionKey can be disabled")
    func sessionKeyDisabled() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config = FairPlayLiveConfig(
            keyServerURL: url,
            enableSessionKey: false
        )
        #expect(config.enableSessionKey == false)
    }

    @Test("Modern preset uses CBCS method")
    func modernPreset() {
        let config = FairPlayLiveConfig.modern
        #expect(config.method == .sampleAESCTR)
        #expect(config.enableSessionKey == true)
        #expect(config.keyFormat == "com.apple.streamingkeydelivery")
    }

    @Test("Legacy preset uses CBC method")
    func legacyPreset() {
        let config = FairPlayLiveConfig.legacy
        #expect(config.method == .sampleAES)
        #expect(config.keyFormatVersions == "1")
    }

    @Test("Equatable conformance works correctly")
    func equatable() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config1 = FairPlayLiveConfig(keyServerURL: url)
        let config2 = FairPlayLiveConfig(keyServerURL: url)
        #expect(config1 == config2)
    }

    @Test("Equatable detects differences")
    func equatableDifference() throws {
        let url = try #require(URL(string: "https://fps.example.com"))
        let config1 = FairPlayLiveConfig(keyServerURL: url, method: .sampleAES)
        let config2 = FairPlayLiveConfig(keyServerURL: url, method: .sampleAESCTR)
        #expect(config1 != config2)
    }
}
