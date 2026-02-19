// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors during HLS segment encryption and decryption operations.
///
/// Each case provides contextual information about the failure,
/// accessible via the ``LocalizedError`` conformance.
///
/// - SeeAlso: ``SegmentEncryptor``, ``KeyManager``
public enum EncryptionError: Error, Sendable, Hashable {

    /// Invalid key size (must be 16 bytes for AES-128).
    case invalidKeySize(Int)

    /// Invalid IV size (must be 16 bytes).
    case invalidIVSize(Int)

    /// Crypto operation failed.
    case cryptoFailed(String)

    /// Random number generation failed.
    case randomGenerationFailed(String)

    /// Segment file not found.
    case segmentNotFound(String)

    /// Key file not found.
    case keyNotFound(String)

    /// Encryption method not supported.
    case unsupportedMethod(String)

    /// Configuration error.
    case invalidConfig(String)
}

// MARK: - LocalizedError

extension EncryptionError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidKeySize(let size):
            return "Invalid AES-128 key size: \(size) bytes (expected 16)"
        case .invalidIVSize(let size):
            return "Invalid IV size: \(size) bytes (expected 16)"
        case .cryptoFailed(let message):
            return "Crypto operation failed: \(message)"
        case .randomGenerationFailed(let message):
            return "Random generation failed: \(message)"
        case .segmentNotFound(let path):
            return "Segment file not found: \(path)"
        case .keyNotFound(let path):
            return "Key file not found: \(path)"
        case .unsupportedMethod(let method):
            return "Unsupported encryption method: \(method)"
        case .invalidConfig(let message):
            return "Invalid encryption configuration: \(message)"
        }
    }
}
