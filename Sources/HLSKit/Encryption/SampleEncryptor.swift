// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Encrypts individual media samples per the SAMPLE-AES specification.
///
/// Unlike AES-128 (which encrypts entire segment files), SAMPLE-AES
/// encrypts only the media sample data within NAL units (video) and
/// ADTS frames (audio), leaving container metadata readable.
///
/// ## Video (H.264) Encryption Pattern
/// For NAL unit types 1 (non-IDR) and 5 (IDR):
/// - Skip first 32 bytes (unencrypted)
/// - Encrypt in 16-byte blocks
/// - Leave trailing bytes (< 16) unencrypted
///
/// ## Audio (AAC) Encryption Pattern
/// For each ADTS frame:
/// - Skip 7-byte ADTS header (unencrypted)
/// - Skip first 16 bytes of audio data (unencrypted)
/// - Encrypt remaining in 16-byte blocks
/// - Leave trailing bytes unencrypted
///
/// - SeeAlso: RFC 8216 Section 5.3
public struct SampleEncryptor: Sendable {

    private let cryptoProvider: CryptoProvider

    /// Creates a sample encryptor with the default platform
    /// crypto provider.
    public init() {
        self.cryptoProvider = defaultCryptoProvider()
    }

    /// Creates a sample encryptor with a custom crypto provider.
    ///
    /// - Parameter cryptoProvider: The crypto implementation to use.
    init(cryptoProvider: CryptoProvider) {
        self.cryptoProvider = cryptoProvider
    }

    // MARK: - Video Encryption

    /// Encrypt video NAL units in Annex B format per SAMPLE-AES.
    ///
    /// - Parameters:
    ///   - data: Annex B video data (with start codes).
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Encrypted video data (same size).
    /// - Throws: ``EncryptionError``
    public func encryptVideoSamples(
        _ data: Data,
        key: Data,
        iv: Data
    ) throws -> Data {
        try validateKeyAndIV(key: key, iv: iv)
        return try processVideoNALUnits(
            data, key: key, iv: iv, encrypt: true
        )
    }

    /// Decrypt video NAL units in Annex B format per SAMPLE-AES.
    ///
    /// - Parameters:
    ///   - data: Encrypted Annex B video data.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Decrypted video data.
    /// - Throws: ``EncryptionError``
    public func decryptVideoSamples(
        _ data: Data,
        key: Data,
        iv: Data
    ) throws -> Data {
        try validateKeyAndIV(key: key, iv: iv)
        return try processVideoNALUnits(
            data, key: key, iv: iv, encrypt: false
        )
    }

    // MARK: - Audio Encryption

    /// Encrypt AAC frames in ADTS format per SAMPLE-AES.
    ///
    /// - Parameters:
    ///   - data: ADTS audio data.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Encrypted audio data (same size).
    /// - Throws: ``EncryptionError``
    public func encryptAudioSamples(
        _ data: Data,
        key: Data,
        iv: Data
    ) throws -> Data {
        try validateKeyAndIV(key: key, iv: iv)
        return try processADTSFrames(
            data, key: key, iv: iv, encrypt: true
        )
    }

    /// Decrypt AAC frames in ADTS format per SAMPLE-AES.
    ///
    /// - Parameters:
    ///   - data: Encrypted ADTS audio data.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Decrypted audio data.
    /// - Throws: ``EncryptionError``
    public func decryptAudioSamples(
        _ data: Data,
        key: Data,
        iv: Data
    ) throws -> Data {
        try validateKeyAndIV(key: key, iv: iv)
        return try processADTSFrames(
            data, key: key, iv: iv, encrypt: false
        )
    }

    // MARK: - TS Segment

    /// Encrypt a complete MPEG-TS segment using SAMPLE-AES.
    ///
    /// - Parameters:
    ///   - tsData: Complete TS segment data.
    ///   - key: 16-byte AES key.
    ///   - iv: 16-byte initialization vector.
    /// - Returns: Encrypted TS segment (same size).
    /// - Throws: ``EncryptionError``
    public func encryptTSSegment(
        _ tsData: Data,
        key: Data,
        iv: Data
    ) throws -> Data {
        try validateKeyAndIV(key: key, iv: iv)

        guard tsData.count >= TSPacket.packetSize else {
            return tsData
        }

        var result = tsData
        let packetCount = tsData.count / TSPacket.packetSize
        var pesBuffers: [UInt16: (start: Int, data: Data)] = [:]

        for i in 0..<packetCount {
            let pktStart = i * TSPacket.packetSize
            let pktEnd = pktStart + TSPacket.packetSize
            guard pktEnd <= tsData.count else { break }
            guard tsData[pktStart] == TSPacket.syncByte else {
                continue
            }

            let byte1 = tsData[pktStart + 1]
            let byte2 = tsData[pktStart + 2]
            let pid = UInt16(byte1 & 0x1F) << 8 | UInt16(byte2)
            let pusi = (byte1 & 0x40) != 0

            guard
                pid == TSPacket.PID.video
                    || pid == TSPacket.PID.audio
            else {
                continue
            }

            let payOff = tsPayloadOffset(tsData, at: pktStart)
            guard payOff < pktEnd else { continue }
            let payload = tsData.subdata(in: payOff..<pktEnd)

            if pusi {
                if let existing = pesBuffers[pid] {
                    try encryptPESAndWrite(
                        pesData: existing.data, pid: pid,
                        keyIV: (key, iv),
                        result: &result,
                        pktStart: existing.start
                    )
                }
                pesBuffers[pid] = (start: pktStart, data: payload)
            } else if pesBuffers[pid] != nil {
                pesBuffers[pid]?.data.append(payload)
            }
        }

        for (pid, buffer) in pesBuffers {
            try encryptPESAndWrite(
                pesData: buffer.data, pid: pid,
                keyIV: (key, iv),
                result: &result,
                pktStart: buffer.start
            )
        }

        return result
    }
}

// MARK: - Video Processing

extension SampleEncryptor {

    private func processVideoNALUnits(
        _ data: Data,
        key: Data,
        iv: Data,
        encrypt: Bool
    ) throws -> Data {
        var result = data
        var offset = 0

        while offset < data.count {
            guard
                let nalStart = findNextStartCode(
                    in: data, from: offset
                )
            else {
                break
            }

            let hdrOff = nalStart + 4
            guard hdrOff < data.count else { break }
            let nalType = data[hdrOff] & 0x1F

            let nalEnd =
                findNextStartCode(
                    in: data, from: hdrOff
                ) ?? data.count

            if nalType == 1 || nalType == 5 {
                let bodyStart = hdrOff + 1
                let bodyLength = nalEnd - bodyStart
                if bodyLength > 48 {
                    try cryptRegion(
                        data: data, result: &result,
                        range: (bodyStart + 32, nalEnd),
                        keyIV: (key, iv), encrypt: encrypt
                    )
                }
            }

            offset = hdrOff
        }

        return result
    }
}

// MARK: - Audio Processing

extension SampleEncryptor {

    private func processADTSFrames(
        _ data: Data,
        key: Data,
        iv: Data,
        encrypt: Bool
    ) throws -> Data {
        var result = data
        var offset = 0

        while offset < data.count - 7 {
            guard data[offset] == 0xFF,
                (data[offset + 1] & 0xF0) == 0xF0
            else {
                offset += 1
                continue
            }

            let frameLen = parseADTSFrameLength(data, at: offset)
            guard frameLen > 0,
                offset + frameLen <= data.count
            else {
                break
            }

            let cryptStart = offset + 7 + 16
            let frameEnd = offset + frameLen

            if cryptStart < frameEnd {
                try cryptRegion(
                    data: data, result: &result,
                    range: (cryptStart, frameEnd),
                    keyIV: (key, iv), encrypt: encrypt
                )
            }

            offset += frameLen
        }

        return result
    }
}

// MARK: - Private Helpers

extension SampleEncryptor {

    func validateKeyAndIV(key: Data, iv: Data) throws {
        guard key.count == 16 else {
            throw EncryptionError.invalidKeySize(key.count)
        }
        guard iv.count == 16 else {
            throw EncryptionError.invalidIVSize(iv.count)
        }
    }

    func findNextStartCode(
        in data: Data, from offset: Int
    ) -> Int? {
        guard offset + 3 < data.count else { return nil }
        for i in offset..<(data.count - 3) {
            if data[i] == 0x00, data[i + 1] == 0x00,
                data[i + 2] == 0x00, data[i + 3] == 0x01
            {
                return i
            }
        }
        return nil
    }

    func parseADTSFrameLength(
        _ data: Data, at offset: Int
    ) -> Int {
        guard offset + 6 < data.count else { return 0 }
        let high = Int(data[offset + 3] & 0x03) << 11
        let mid = Int(data[offset + 4]) << 3
        let low = Int(data[offset + 5] >> 5) & 0x07
        return high | mid | low
    }

    /// Encrypt or decrypt a block-aligned region in-place.
    func cryptRegion(
        data: Data,
        result: inout Data,
        range: (start: Int, end: Int),
        keyIV: (key: Data, iv: Data),
        encrypt: Bool
    ) throws {
        let start = range.start
        let end = range.end
        let available = end - start
        let fullBlocks = available / 16
        guard fullBlocks > 0 else { return }

        let length = fullBlocks * 16
        let range = start..<(start + length)
        let slice = data.subdata(in: range)

        let processed: Data
        if encrypt {
            processed = try cryptoProvider.encrypt(
                slice, key: keyIV.key, iv: keyIV.iv
            )
        } else {
            processed = try cryptoProvider.decrypt(
                slice, key: keyIV.key, iv: keyIV.iv
            )
        }

        result.replaceSubrange(
            range, with: processed.prefix(length)
        )
    }
}
