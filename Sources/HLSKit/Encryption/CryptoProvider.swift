// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol for AES-128-CBC encryption and decryption.
///
/// Implementations provide platform-specific crypto operations.
/// - Apple platforms: ``CommonCryptoCryptoProvider`` via CommonCrypto
/// - Linux: ``OpenSSLCryptoProvider`` via OpenSSL CLI
///
/// Custom implementations can be injected into ``SegmentEncryptor``
/// for testing or alternative crypto backends.
///
/// - SeeAlso: ``SegmentEncryptor``, ``EncryptionConfig``
protocol CryptoProvider: Sendable {

    /// Encrypt data with AES-128-CBC.
    ///
    /// - Parameters:
    ///   - data: Plaintext data.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Encrypted data with PKCS#7 padding.
    /// - Throws: ``EncryptionError`` on failure.
    func encrypt(_ data: Data, key: Data, iv: Data) throws -> Data

    /// Decrypt data with AES-128-CBC.
    ///
    /// - Parameters:
    ///   - data: Ciphertext data with PKCS#7 padding.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Decrypted plaintext data.
    /// - Throws: ``EncryptionError`` on failure.
    func decrypt(_ data: Data, key: Data, iv: Data) throws -> Data
}

// MARK: - Default Provider

/// Returns the appropriate ``CryptoProvider`` for the current platform.
///
/// - Apple platforms: ``CommonCryptoCryptoProvider``
/// - Linux: ``OpenSSLCryptoProvider``
func defaultCryptoProvider() -> CryptoProvider {
    #if canImport(CommonCrypto)
        return CommonCryptoCryptoProvider()
    #elseif os(Linux)
        return OpenSSLCryptoProvider()
    #endif
}

// MARK: - Apple Implementation

#if canImport(CommonCrypto)
    import CommonCrypto

    /// AES-128-CBC encryption using Apple's CommonCrypto framework.
    ///
    /// Uses `CCCrypt` for both encryption and decryption with
    /// PKCS#7 padding. Available on macOS, iOS, tvOS, watchOS,
    /// and visionOS.
    struct CommonCryptoCryptoProvider: CryptoProvider {

        func encrypt(
            _ data: Data, key: Data, iv: Data
        ) throws -> Data {
            try crypt(
                data, key: key, iv: iv,
                operation: CCOperation(kCCEncrypt)
            )
        }

        func decrypt(
            _ data: Data, key: Data, iv: Data
        ) throws -> Data {
            try crypt(
                data, key: key, iv: iv,
                operation: CCOperation(kCCDecrypt)
            )
        }

        private func crypt(
            _ data: Data, key: Data, iv: Data,
            operation: CCOperation
        ) throws -> Data {
            guard key.count == kCCKeySizeAES128 else {
                throw EncryptionError.invalidKeySize(key.count)
            }
            guard iv.count == kCCBlockSizeAES128 else {
                throw EncryptionError.invalidIVSize(iv.count)
            }

            let bufferSize = data.count + kCCBlockSizeAES128
            var buffer = Data(count: bufferSize)
            var bytesProcessed = 0

            let status = buffer.withUnsafeMutableBytes { bufferPtr in
                data.withUnsafeBytes { dataPtr in
                    key.withUnsafeBytes { keyPtr in
                        iv.withUnsafeBytes { ivPtr in
                            CCCrypt(
                                operation,
                                CCAlgorithm(kCCAlgorithmAES),
                                CCOptions(kCCOptionPKCS7Padding),
                                keyPtr.baseAddress,
                                kCCKeySizeAES128,
                                ivPtr.baseAddress,
                                dataPtr.baseAddress,
                                data.count,
                                bufferPtr.baseAddress,
                                bufferSize,
                                &bytesProcessed
                            )
                        }
                    }
                }
            }

            guard status == kCCSuccess else {
                throw EncryptionError.cryptoFailed(
                    "CCCrypt failed with status: \(status)"
                )
            }

            buffer.count = bytesProcessed
            return buffer
        }
    }
#endif

// MARK: - Linux Implementation

#if os(Linux)
    /// AES-128-CBC encryption for Linux using the OpenSSL CLI.
    ///
    /// Falls back to invoking `openssl enc` as a subprocess.
    /// For production use, ensure `libssl-dev` is installed.
    ///
    /// The ``CryptoProvider`` protocol allows swapping this
    /// implementation for a direct OpenSSL EVP binding.
    struct OpenSSLCryptoProvider: CryptoProvider {

        func encrypt(
            _ data: Data, key: Data, iv: Data
        ) throws -> Data {
            guard key.count == 16 else {
                throw EncryptionError.invalidKeySize(key.count)
            }
            guard iv.count == 16 else {
                throw EncryptionError.invalidIVSize(iv.count)
            }
            return try runOpenSSL(
                data, key: key, iv: iv, decrypt: false
            )
        }

        func decrypt(
            _ data: Data, key: Data, iv: Data
        ) throws -> Data {
            guard key.count == 16 else {
                throw EncryptionError.invalidKeySize(key.count)
            }
            guard iv.count == 16 else {
                throw EncryptionError.invalidIVSize(iv.count)
            }
            return try runOpenSSL(
                data, key: key, iv: iv, decrypt: true
            )
        }

        private func runOpenSSL(
            _ data: Data, key: Data, iv: Data, decrypt: Bool
        ) throws -> Data {
            let keyHex = key.map {
                String(format: "%02x", $0)
            }.joined()
            let ivHex = iv.map {
                String(format: "%02x", $0)
            }.joined()

            let tempIn = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            let tempOut = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)

            defer {
                try? FileManager.default.removeItem(at: tempIn)
                try? FileManager.default.removeItem(at: tempOut)
            }

            try data.write(to: tempIn)

            var args = [
                "enc", "-aes-128-cbc",
                "-K", keyHex,
                "-iv", ivHex,
                "-in", tempIn.path,
                "-out", tempOut.path
            ]
            if decrypt {
                args.append("-d")
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
            process.arguments = args

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                throw EncryptionError.cryptoFailed(
                    "OpenSSL exited with status \(process.terminationStatus)"
                )
            }

            return try Data(contentsOf: tempOut)
        }
    }
#endif
