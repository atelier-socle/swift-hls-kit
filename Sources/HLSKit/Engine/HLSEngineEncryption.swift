// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Encryption

extension HLSEngine {

    /// Segment a media file and encrypt the segments.
    ///
    /// Combines segmentation and AES-128 encryption in one step.
    /// Equivalent to calling ``segment(data:config:)`` followed
    /// by ``encrypt(segments:config:)``.
    ///
    /// - Parameters:
    ///   - input: Source media file URL.
    ///   - outputDirectory: Directory for output files.
    ///   - segmentConfig: Segmentation configuration.
    ///   - encryptionConfig: Encryption configuration.
    /// - Returns: Segmentation result with encrypted segments.
    /// - Throws: `MP4Error`, `TransportError`, or
    ///   ``EncryptionError``.
    public func segmentAndEncrypt(
        input: URL,
        outputDirectory: URL,
        segmentConfig: SegmentationConfig = SegmentationConfig(),
        encryptionConfig: EncryptionConfig
    ) throws -> SegmentationResult {
        let result = try segment(url: input, config: segmentConfig)
        return try encrypt(
            segments: result, config: encryptionConfig
        )
    }

    /// Encrypt existing segments from a segmentation result.
    ///
    /// Takes a ``SegmentationResult`` and encrypts all segment
    /// data in-memory. The returned result contains encrypted
    /// segment data and an updated playlist with `EXT-X-KEY` tags.
    ///
    /// - Parameters:
    ///   - result: Existing segmentation result.
    ///   - config: Encryption configuration.
    /// - Returns: Updated result with encrypted segments.
    /// - Throws: ``EncryptionError``
    public func encrypt(
        segments result: SegmentationResult,
        config: EncryptionConfig
    ) throws -> SegmentationResult {
        let encryptor = SegmentEncryptor()
        return try encryptor.encryptSegments(
            result: result, config: config
        )
    }
}
