// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

#if canImport(Security)
    import Security
#endif

/// Generates and manages HLS encryption keys.
///
/// Provides cryptographically secure random key generation and IV
/// derivation from media sequence numbers per RFC 8216 Section 5.2.
///
/// ## Key Generation
///
/// ```swift
/// let manager = KeyManager()
/// let key = try manager.generateKey()     // 16 random bytes
/// let iv = try manager.generateIV()       // 16 random bytes
/// ```
///
/// ## Sequence-Based IV
///
/// ```swift
/// let iv = manager.deriveIV(fromSequenceNumber: 42)
/// // → 0x0000000000000000000000000000002A
/// ```
///
/// - SeeAlso: ``SegmentEncryptor``, ``EncryptionConfig``
public struct KeyManager: Sendable {

    /// Creates a new key manager.
    public init() {}

    /// Generate a random 16-byte AES-128 key.
    ///
    /// Uses `SecRandomCopyBytes` on Apple platforms and
    /// `/dev/urandom` on Linux.
    ///
    /// - Returns: 16-byte random key.
    /// - Throws: ``EncryptionError/randomGenerationFailed(_:)``
    ///   if random generation fails.
    public func generateKey() throws -> Data {
        try generateRandomBytes(count: 16)
    }

    /// Generate a random 16-byte initialization vector.
    ///
    /// - Returns: 16-byte random IV.
    /// - Throws: ``EncryptionError/randomGenerationFailed(_:)``
    ///   if random generation fails.
    public func generateIV() throws -> Data {
        try generateRandomBytes(count: 16)
    }

    /// Derive an IV from a media sequence number.
    ///
    /// Per RFC 8216 Section 5.2: when no explicit IV is present,
    /// the IV is the big-endian representation of the media sequence
    /// number as a 128-bit unsigned integer.
    ///
    /// - Parameter sequenceNumber: The media sequence number.
    /// - Returns: 16-byte IV.
    public func deriveIV(
        fromSequenceNumber sequenceNumber: UInt64
    ) -> Data {
        var iv = Data(count: 16)
        // High 64 bits are zero, low 64 bits = sequence number
        var bigEndian = sequenceNumber.bigEndian
        withUnsafeBytes(of: &bigEndian) { bytes in
            iv.replaceSubrange(8..<16, with: bytes)
        }
        return iv
    }

    /// Write a key to a file.
    ///
    /// - Parameters:
    ///   - key: 16-byte key data.
    ///   - url: File URL to write to.
    /// - Throws: ``EncryptionError/invalidKeySize(_:)`` if key is
    ///   not 16 bytes, or filesystem errors.
    public func writeKey(_ key: Data, to url: URL) throws {
        guard key.count == 16 else {
            throw EncryptionError.invalidKeySize(key.count)
        }
        try key.write(to: url)
    }

    /// Read a key from a file.
    ///
    /// - Parameter url: File URL to read from.
    /// - Returns: 16-byte key data.
    /// - Throws: ``EncryptionError/keyNotFound(_:)`` if file
    ///   doesn't exist, or ``EncryptionError/invalidKeySize(_:)``
    ///   if data is not 16 bytes.
    public func readKey(from url: URL) throws -> Data {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw EncryptionError.keyNotFound(url.path)
        }
        guard data.count == 16 else {
            throw EncryptionError.invalidKeySize(data.count)
        }
        return data
    }

    // MARK: - Private

    private func generateRandomBytes(count: Int) throws -> Data {
        #if canImport(Security)
            var bytes = Data(count: count)
            let status = bytes.withUnsafeMutableBytes { ptr in
                guard let base = ptr.baseAddress else {
                    return errSecParam
                }
                return SecRandomCopyBytes(
                    kSecRandomDefault, count, base
                )
            }
            guard status == errSecSuccess else {
                throw EncryptionError.randomGenerationFailed(
                    "SecRandomCopyBytes failed with status: \(status)"
                )
            }
            return bytes
        #else
            guard
                let urandom = fopen("/dev/urandom", "r")
            else {
                throw EncryptionError.randomGenerationFailed(
                    "Failed to open /dev/urandom"
                )
            }
            defer { fclose(urandom) }
            var bytes = Data(count: count)
            let read = bytes.withUnsafeMutableBytes { ptr in
                fread(ptr.baseAddress, 1, count, urandom)
            }
            guard read == count else {
                throw EncryptionError.randomGenerationFailed(
                    "Failed to read \(count) bytes from /dev/urandom"
                )
            }
            return bytes
        #endif
    }
}
