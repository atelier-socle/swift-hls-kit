// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("KeyManager")
struct KeyManagerTests {

    private let manager = KeyManager()

    // MARK: - Key Generation

    @Test("generateKey returns 16 bytes")
    func keySize() throws {
        let key = try manager.generateKey()
        #expect(key.count == 16)
    }

    @Test("Two generated keys are different")
    func keysAreDifferent() throws {
        let key1 = try manager.generateKey()
        let key2 = try manager.generateKey()
        #expect(key1 != key2)
    }

    // MARK: - IV Generation

    @Test("generateIV returns 16 bytes")
    func ivSize() throws {
        let iv = try manager.generateIV()
        #expect(iv.count == 16)
    }

    // MARK: - IV Derivation

    @Test("deriveIV(0) is all zeros")
    func deriveIVZero() {
        let iv = manager.deriveIV(fromSequenceNumber: 0)
        #expect(iv.count == 16)
        #expect(iv == Data(count: 16))
    }

    @Test("deriveIV(1) has correct big-endian encoding")
    func deriveIVOne() {
        let iv = manager.deriveIV(fromSequenceNumber: 1)
        #expect(iv.count == 16)
        var expected = Data(count: 16)
        expected[15] = 1
        #expect(iv == expected)
    }

    @Test("deriveIV(256) has correct encoding")
    func deriveIV256() {
        let iv = manager.deriveIV(fromSequenceNumber: 256)
        #expect(iv.count == 16)
        var expected = Data(count: 16)
        expected[14] = 1  // 256 = 0x0100
        expected[15] = 0
        #expect(iv == expected)
    }

    @Test("deriveIV(UInt64.max) fills lower 8 bytes")
    func deriveIVMax() {
        let iv = manager.deriveIV(
            fromSequenceNumber: UInt64.max
        )
        #expect(iv.count == 16)
        // High 8 bytes = 0, low 8 bytes = 0xFF...FF
        for i in 0..<8 {
            #expect(iv[i] == 0)
        }
        for i in 8..<16 {
            #expect(iv[i] == 0xFF)
        }
    }

    // MARK: - File I/O

    @Test("writeKey + readKey round-trip")
    func writeReadRoundTrip() throws {
        let key = try manager.generateKey()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "test-key-\(UUID().uuidString).bin"
            )
        defer { try? FileManager.default.removeItem(at: url) }

        try manager.writeKey(key, to: url)
        let read = try manager.readKey(from: url)
        #expect(read == key)
    }

    @Test("writeKey rejects wrong size")
    func writeKeyWrongSize() {
        let badKey = Data(repeating: 0x00, count: 10)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("bad-key.bin")
        #expect(throws: EncryptionError.self) {
            try manager.writeKey(badKey, to: url)
        }
    }

    @Test("readKey from non-existent file throws keyNotFound")
    func readKeyMissing() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent-key.bin")
        #expect(throws: EncryptionError.self) {
            try manager.readKey(from: url)
        }
    }

    @Test("readKey wrong size throws invalidKeySize")
    func readKeyWrongSize() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "bad-size-key-\(UUID().uuidString).bin"
            )
        defer { try? FileManager.default.removeItem(at: url) }

        try Data(repeating: 0x00, count: 10).write(to: url)
        #expect(throws: EncryptionError.self) {
            try manager.readKey(from: url)
        }
    }
}
