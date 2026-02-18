// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The encryption method for media segments as declared by `EXT-X-KEY`.
///
/// Per RFC 8216 Section 4.3.2.4, the `METHOD` attribute specifies
/// the encryption method. If the method is `none`, other attributes
/// MUST NOT be present.
public enum EncryptionMethod: String, Sendable, Hashable, Codable, CaseIterable {

    /// No encryption. Segments are not encrypted.
    case none = "NONE"

    /// AES-128 encryption with a 128-bit key, PKCS7 padding, and CBC mode.
    case aes128 = "AES-128"

    /// Sample-level encryption using the Common Encryption scheme.
    case sampleAES = "SAMPLE-AES"

    /// Sample-level encryption using Common Encryption with CTR mode.
    case sampleAESCTR = "SAMPLE-AES-CTR"
}
