// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Encrypts and decrypts HLS media segments.
///
/// Supports AES-128 (full segment encryption) and SAMPLE-AES
/// (sample-level encryption of NAL units and ADTS frames).
///
/// ## Single Segment (AES-128)
///
/// ```swift
/// let encryptor = SegmentEncryptor()
/// let key = try KeyManager().generateKey()
/// let iv = KeyManager().deriveIV(fromSequenceNumber: 0)
/// let encrypted = try encryptor.encrypt(
///     segmentData: rawData, key: key, iv: iv
/// )
/// ```
///
/// ## Batch Encryption
///
/// ```swift
/// let encryptedResult = try encryptor.encryptSegments(
///     result: segmentationResult,
///     config: encryptionConfig
/// )
/// ```
///
/// - SeeAlso: ``EncryptionConfig``, ``KeyManager``,
///   ``SampleEncryptor``
public struct SegmentEncryptor: Sendable {

    private let cryptoProvider: CryptoProvider
    private let keyManager: KeyManager

    /// Initialize with the default platform crypto provider.
    public init() {
        self.cryptoProvider = defaultCryptoProvider()
        self.keyManager = KeyManager()
    }

    /// Initialize with a custom crypto provider (for testing).
    ///
    /// - Parameter cryptoProvider: The crypto implementation to use.
    init(cryptoProvider: CryptoProvider) {
        self.cryptoProvider = cryptoProvider
        self.keyManager = KeyManager()
    }

    // MARK: - Single Segment

    /// Encrypt a single segment's data.
    ///
    /// - Parameters:
    ///   - segmentData: Raw segment data.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Encrypted segment data with PKCS#7 padding.
    /// - Throws: ``EncryptionError``
    public func encrypt(
        segmentData: Data, key: Data, iv: Data
    ) throws -> Data {
        try cryptoProvider.encrypt(segmentData, key: key, iv: iv)
    }

    /// Decrypt a single segment's data.
    ///
    /// - Parameters:
    ///   - segmentData: Encrypted segment data.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Decrypted plaintext data.
    /// - Throws: ``EncryptionError``
    public func decrypt(
        segmentData: Data, key: Data, iv: Data
    ) throws -> Data {
        try cryptoProvider.decrypt(segmentData, key: key, iv: iv)
    }

    // MARK: - Batch Encryption

    /// Encrypt all segments from a segmentation result.
    ///
    /// Dispatches to the appropriate encryption strategy based on
    /// the configured method:
    /// - `.aes128`: Full segment encryption with PKCS#7 padding.
    /// - `.sampleAES`: Sample-level encryption of NAL units/ADTS.
    /// - `.none`: Returns the result unchanged.
    ///
    /// - Parameters:
    ///   - result: Segmentation result from MP4Segmenter or
    ///     TSSegmenter.
    ///   - config: Encryption configuration.
    /// - Returns: Updated segmentation result with encrypted data.
    /// - Throws: ``EncryptionError``
    public func encryptSegments(
        result: SegmentationResult,
        config: EncryptionConfig
    ) throws -> SegmentationResult {
        switch config.method {
        case .aes128:
            return try encryptAES128(
                result: result, config: config
            )
        case .sampleAES:
            return try encryptSampleAES(
                result: result, config: config
            )
        case .none:
            return result
        case .sampleAESCTR:
            throw EncryptionError.unsupportedMethod(
                config.method.rawValue
            )
        }
    }

    /// Encrypt segments using SAMPLE-AES.
    ///
    /// Only works with MPEG-TS segments (SAMPLE-AES operates on
    /// PES/NAL/ADTS data within TS containers).
    ///
    /// - Parameters:
    ///   - result: Segmentation result (must be MPEG-TS).
    ///   - config: Encryption config with method `.sampleAES`.
    /// - Returns: Updated result with SAMPLE-AES encrypted segments.
    /// - Throws: ``EncryptionError``
    public func encryptSampleAES(
        result: SegmentationResult,
        config: EncryptionConfig
    ) throws -> SegmentationResult {
        let key = try config.key ?? keyManager.generateKey()
        let sampleEnc = SampleEncryptor(
            cryptoProvider: cryptoProvider
        )
        var encryptedSegments: [MediaSegmentOutput] = []

        for (index, segment) in result.mediaSegments.enumerated() {
            let iv = resolveIV(
                config: config, segmentIndex: index
            )
            let encrypted = try sampleEnc.encryptTSSegment(
                segment.data, key: key, iv: iv
            )
            encryptedSegments.append(
                MediaSegmentOutput(
                    index: segment.index,
                    data: encrypted,
                    duration: segment.duration,
                    filename: segment.filename,
                    byteRangeOffset: segment.byteRangeOffset,
                    byteRangeLength: segment.byteRangeLength
                )
            )
        }

        return buildEncryptedResult(
            result: result, config: config,
            segments: encryptedSegments
        )
    }

    // MARK: - AES-128

    private func encryptAES128(
        result: SegmentationResult,
        config: EncryptionConfig
    ) throws -> SegmentationResult {
        let key = try config.key ?? keyManager.generateKey()
        var encryptedSegments: [MediaSegmentOutput] = []

        for (index, segment) in result.mediaSegments.enumerated() {
            let iv = resolveIV(
                config: config, segmentIndex: index
            )
            let encrypted = try cryptoProvider.encrypt(
                segment.data, key: key, iv: iv
            )
            encryptedSegments.append(
                MediaSegmentOutput(
                    index: segment.index,
                    data: encrypted,
                    duration: segment.duration,
                    filename: segment.filename,
                    byteRangeOffset: segment.byteRangeOffset,
                    byteRangeLength: segment.byteRangeLength
                )
            )
        }

        return buildEncryptedResult(
            result: result, config: config,
            segments: encryptedSegments
        )
    }

    private func buildEncryptedResult(
        result: SegmentationResult,
        config: EncryptionConfig,
        segments: [MediaSegmentOutput]
    ) -> SegmentationResult {
        let builder = EncryptedPlaylistBuilder()
        let playlist: String?
        if let original = result.playlist {
            playlist = builder.addEncryptionTags(
                to: original,
                config: config,
                segmentCount: segments.count
            )
        } else {
            playlist = nil
        }

        return SegmentationResult(
            initSegment: result.initSegment,
            mediaSegments: segments,
            playlist: playlist,
            fileInfo: result.fileInfo,
            config: result.config
        )
    }

    /// Encrypt segment files in a directory.
    ///
    /// Reads each segment file, encrypts it, writes it back,
    /// and optionally writes the key file.
    ///
    /// - Parameters:
    ///   - directory: Directory containing segment files.
    ///   - segmentFilenames: Ordered list of segment filenames.
    ///   - config: Encryption configuration.
    /// - Returns: The encryption key used.
    /// - Throws: ``EncryptionError``
    public func encryptDirectory(
        _ directory: URL,
        segmentFilenames: [String],
        config: EncryptionConfig
    ) throws -> Data {
        guard
            config.method == .aes128
                || config.method == .sampleAES
        else {
            throw EncryptionError.unsupportedMethod(
                config.method.rawValue
            )
        }

        let key = try config.key ?? keyManager.generateKey()
        let sampleEnc =
            config.method == .sampleAES
            ? SampleEncryptor(cryptoProvider: cryptoProvider)
            : nil

        for (index, filename) in segmentFilenames.enumerated() {
            let fileURL = directory.appendingPathComponent(filename)
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                throw EncryptionError.segmentNotFound(
                    fileURL.path
                )
            }
            let iv = resolveIV(
                config: config, segmentIndex: index
            )
            let encrypted: Data
            if let sEnc = sampleEnc {
                encrypted = try sEnc.encryptTSSegment(
                    data, key: key, iv: iv
                )
            } else {
                encrypted = try cryptoProvider.encrypt(
                    data, key: key, iv: iv
                )
            }
            try encrypted.write(to: fileURL)
        }

        if config.writeKeyFile {
            let keyURL = directory.appendingPathComponent("key.bin")
            try keyManager.writeKey(key, to: keyURL)
        }

        return key
    }

    // MARK: - Private

    private func resolveIV(
        config: EncryptionConfig, segmentIndex: Int
    ) -> Data {
        if let explicitIV = config.iv {
            return explicitIV
        }
        return keyManager.deriveIV(
            fromSequenceNumber: UInt64(segmentIndex)
        )
    }
}
