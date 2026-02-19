// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EncryptionError")
struct EncryptionErrorTests {

    // MARK: - Error Descriptions

    @Test("All error cases have errorDescription")
    func allErrorDescriptions() {
        let errors: [EncryptionError] = [
            .invalidKeySize(8),
            .invalidIVSize(4),
            .cryptoFailed("test failure"),
            .randomGenerationFailed("rng failure"),
            .segmentNotFound("/path/to/seg.ts"),
            .keyNotFound("/path/to/key.bin"),
            .unsupportedMethod("SAMPLE-AES"),
            .invalidConfig("missing key URL")
        ]
        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }
    }

    @Test("invalidKeySize includes size in message")
    func invalidKeySizeMessage() {
        let error = EncryptionError.invalidKeySize(8)
        #expect(error.errorDescription?.contains("8") == true)
    }

    @Test("invalidIVSize includes size in message")
    func invalidIVSizeMessage() {
        let error = EncryptionError.invalidIVSize(4)
        #expect(error.errorDescription?.contains("4") == true)
    }

    @Test("cryptoFailed includes message")
    func cryptoFailedMessage() {
        let error = EncryptionError.cryptoFailed("CCCrypt failed")
        #expect(
            error.errorDescription?.contains("CCCrypt") == true
        )
    }

    // MARK: - Hashable

    @Test("Hashable conformance")
    func hashable() {
        let a = EncryptionError.invalidKeySize(8)
        let b = EncryptionError.invalidKeySize(8)
        let c = EncryptionError.invalidKeySize(16)
        #expect(a == b)
        #expect(a != c)
        #expect(a.hashValue == b.hashValue)
    }

    // MARK: - Sendable

    @Test("Error is Sendable")
    func sendable() {
        let error: any Sendable = EncryptionError.cryptoFailed(
            "test"
        )
        #expect(error is EncryptionError)
    }
}
