// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CryptoProvider — AES-128-CBC")
struct CryptoProviderTests {

    private let provider = defaultCryptoProvider()
    private let key = Data(repeating: 0xAB, count: 16)
    private let iv = Data(repeating: 0xCD, count: 16)

    // MARK: - Round-Trip

    @Test("Encrypt + decrypt round-trip returns original data")
    func roundTrip() throws {
        let plaintext = Data("Hello, HLS encryption!".utf8)
        let encrypted = try provider.encrypt(
            plaintext, key: key, iv: iv
        )
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == plaintext)
    }

    @Test("Encrypted data differs from plaintext")
    func encryptedDiffers() throws {
        let plaintext = Data("Some segment data".utf8)
        let encrypted = try provider.encrypt(
            plaintext, key: key, iv: iv
        )
        #expect(encrypted != plaintext)
    }

    // MARK: - Known Test Vector (NIST AES-128-CBC)

    @Test("AES-128-CBC matches NIST test vector")
    func nistTestVector() throws {
        // NIST SP 800-38A Section F.2.1
        let nistKey = Data([
            0x2B, 0x7E, 0x15, 0x16, 0x28, 0xAE, 0xD2, 0xA6,
            0xAB, 0xF7, 0x15, 0x88, 0x09, 0xCF, 0x4F, 0x3C
        ])
        let nistIV = Data([
            0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
            0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
        ])
        let plaintext = Data([
            0x6B, 0xC1, 0xBE, 0xE2, 0x2E, 0x40, 0x9F, 0x96,
            0xE9, 0x3D, 0x7E, 0x11, 0x73, 0x93, 0x17, 0x2A
        ])

        let encrypted = try provider.encrypt(
            plaintext, key: nistKey, iv: nistIV
        )
        let decrypted = try provider.decrypt(
            encrypted, key: nistKey, iv: nistIV
        )
        #expect(decrypted == plaintext)

        // First 16 bytes of ciphertext (before padding block)
        let expected = Data([
            0x76, 0x49, 0xAB, 0xAC, 0x81, 0x19, 0xB2, 0x46,
            0xCE, 0xE9, 0x8E, 0x9B, 0x12, 0xE9, 0x19, 0x7D
        ])
        #expect(encrypted.prefix(16) == expected)
    }

    // MARK: - Different Data Sizes

    @Test("Encrypt 1 byte")
    func oneByte() throws {
        let data = Data([0x42])
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
        #expect(encrypted.count == 16)
    }

    @Test("Encrypt 15 bytes (one block minus one)")
    func fifteenBytes() throws {
        let data = Data(repeating: 0xAA, count: 15)
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
        #expect(encrypted.count == 16)
    }

    @Test("Encrypt 16 bytes (exact block)")
    func sixteenBytes() throws {
        let data = Data(repeating: 0xBB, count: 16)
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
        // PKCS#7 adds full padding block
        #expect(encrypted.count == 32)
    }

    @Test("Encrypt 17 bytes (one block plus one)")
    func seventeenBytes() throws {
        let data = Data(repeating: 0xCC, count: 17)
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
        #expect(encrypted.count == 32)
    }

    @Test("Encrypt 1000 bytes (large data)")
    func thousandBytes() throws {
        let data = Data(repeating: 0xDD, count: 1000)
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
    }

    // MARK: - Error Cases

    @Test("Wrong key size throws invalidKeySize")
    func wrongKeySize() {
        let badKey = Data(repeating: 0x00, count: 8)
        #expect(throws: EncryptionError.self) {
            try provider.encrypt(
                Data("test".utf8), key: badKey, iv: iv
            )
        }
    }

    @Test("Wrong IV size throws invalidIVSize")
    func wrongIVSize() {
        let badIV = Data(repeating: 0x00, count: 8)
        #expect(throws: EncryptionError.self) {
            try provider.encrypt(
                Data("test".utf8), key: key, iv: badIV
            )
        }
    }

    @Test("Decrypt with wrong key produces different data")
    func wrongKeyDecrypt() throws {
        let plaintext = Data("Secret segment data".utf8)
        let encrypted = try provider.encrypt(
            plaintext, key: key, iv: iv
        )
        let wrongKey = Data(repeating: 0x00, count: 16)
        // Decryption with wrong key either throws or gives junk
        do {
            let decrypted = try provider.decrypt(
                encrypted, key: wrongKey, iv: iv
            )
            #expect(decrypted != plaintext)
        } catch {
            // Padding error is expected
        }
    }

    @Test("Decrypt with wrong IV produces different first block")
    func wrongIVDecrypt() throws {
        let plaintext = Data(
            "This is exactly 32 bytes long!!".utf8
        )
        let encrypted = try provider.encrypt(
            plaintext, key: key, iv: iv
        )
        let wrongIV = Data(repeating: 0x00, count: 16)
        do {
            let decrypted = try provider.decrypt(
                encrypted, key: key, iv: wrongIV
            )
            #expect(decrypted != plaintext)
        } catch {
            // Padding error may occur
        }
    }
}
