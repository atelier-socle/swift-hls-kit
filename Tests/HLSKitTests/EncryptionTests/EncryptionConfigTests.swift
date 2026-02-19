// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EncryptionConfig")
struct EncryptionConfigTests {

    // MARK: - Defaults

    @Test("Default values are correct")
    func defaultValues() throws {
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        #expect(config.method == .aes128)
        #expect(config.keyURL == url)
        #expect(config.key == nil)
        #expect(config.iv == nil)
        #expect(config.keyRotationInterval == nil)
        #expect(config.keyFormat == nil)
        #expect(config.keyFormatVersions == nil)
        #expect(config.writeKeyFile == true)
    }

    // MARK: - Custom Values

    @Test("Custom values preserved")
    func customValues() throws {
        let url = try #require(
            URL(string: "https://cdn.example.com/keys/1.bin")
        )
        let key = Data(repeating: 0xAB, count: 16)
        let iv = Data(repeating: 0xCD, count: 16)
        let config = EncryptionConfig(
            method: .aes128,
            keyURL: url,
            key: key,
            iv: iv,
            keyRotationInterval: 10,
            keyFormat: "identity",
            keyFormatVersions: "1",
            writeKeyFile: false
        )
        #expect(config.key == key)
        #expect(config.iv == iv)
        #expect(config.keyRotationInterval == 10)
        #expect(config.keyFormat == "identity")
        #expect(config.keyFormatVersions == "1")
        #expect(config.writeKeyFile == false)
    }

    // MARK: - Hashable

    @Test("Hashable conformance: equal configs hash equally")
    func hashable() throws {
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let a = EncryptionConfig(keyURL: url)
        let b = EncryptionConfig(keyURL: url)
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Different configs are not equal")
    func notEqual() throws {
        let url1 = try #require(
            URL(string: "https://example.com/key1.bin")
        )
        let url2 = try #require(
            URL(string: "https://example.com/key2.bin")
        )
        let a = EncryptionConfig(keyURL: url1)
        let b = EncryptionConfig(keyURL: url2)
        #expect(a != b)
    }

    // MARK: - EncryptionMethod Cases

    @Test("EncryptionMethod raw values")
    func methodRawValues() {
        #expect(EncryptionMethod.none.rawValue == "NONE")
        #expect(EncryptionMethod.aes128.rawValue == "AES-128")
        #expect(
            EncryptionMethod.sampleAES.rawValue == "SAMPLE-AES"
        )
        #expect(
            EncryptionMethod.sampleAESCTR.rawValue
                == "SAMPLE-AES-CTR"
        )
    }

    @Test("EncryptionMethod CaseIterable")
    func methodCaseIterable() {
        #expect(EncryptionMethod.allCases.count == 4)
    }
}
