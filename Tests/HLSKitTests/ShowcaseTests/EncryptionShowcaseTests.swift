// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Key Management

@Suite("Encryption Showcase — Key Management")
struct KeyManagementShowcase {

    @Test("KeyManager — generate random 16-byte AES key")
    func generateKey() throws {
        let km = KeyManager()
        let key = try km.generateKey()
        #expect(key.count == 16)
    }

    @Test("KeyManager — generate random 16-byte IV")
    func generateIV() throws {
        let km = KeyManager()
        let iv = try km.generateIV()
        #expect(iv.count == 16)
    }

    @Test("KeyManager — two generated keys are different")
    func uniqueKeys() throws {
        let km = KeyManager()
        let key1 = try km.generateKey()
        let key2 = try km.generateKey()
        #expect(key1 != key2)
    }

    @Test("KeyManager — derive IV from media sequence number (RFC 8216)")
    func deriveIV() {
        let km = KeyManager()
        let iv0 = km.deriveIV(fromSequenceNumber: 0)
        let iv1 = km.deriveIV(fromSequenceNumber: 1)
        #expect(iv0.count == 16)
        #expect(iv1.count == 16)
        #expect(iv0 != iv1)
        // Sequence 0 → all zeros
        #expect(iv0 == Data(repeating: 0, count: 16))
    }

    @Test("KeyManager — write key to file + read key from file")
    func writeAndReadKey() throws {
        let km = KeyManager()
        let key = try km.generateKey()

        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let keyURL = tmpDir.appendingPathComponent("key.bin")
        try km.writeKey(key, to: keyURL)
        let readBack = try km.readKey(from: keyURL)
        #expect(readBack == key)
    }

    @Test("EncryptionConfig — method, keyURL, key rotation interval")
    func encryptionConfig() throws {
        let keyURL = try #require(URL(string: "https://example.com/key"))
        let config = EncryptionConfig(
            method: .aes128,
            keyURL: keyURL,
            keyRotationInterval: 10,
            writeKeyFile: true
        )
        #expect(config.method == .aes128)
        #expect(config.keyRotationInterval == 10)
        #expect(config.writeKeyFile == true)
    }

    @Test("EncryptionConfig — FairPlay key format attributes")
    func fairPlayConfig() throws {
        let keyURL = try #require(URL(string: "skd://key.example.com"))
        let config = EncryptionConfig(
            method: .sampleAES,
            keyURL: keyURL,
            keyFormat: "com.apple.streamingkeydelivery",
            keyFormatVersions: "1"
        )
        #expect(config.keyFormat == "com.apple.streamingkeydelivery")
        #expect(config.keyFormatVersions == "1")
    }
}

// MARK: - AES-128 Full Segment Encryption

@Suite("Encryption Showcase — AES-128")
struct AES128EncryptionShowcase {

    @Test("AES-128 — encrypt single segment (data differs from original)")
    func encryptSingle() throws {
        let km = KeyManager()
        let key = try km.generateKey()
        let iv = try km.generateIV()
        let original = Data(repeating: 0xAB, count: 1024)

        let encrypted = try SegmentEncryptor().encrypt(
            segmentData: original, key: key, iv: iv
        )
        #expect(encrypted != original)
        #expect(encrypted.count >= original.count)
    }

    @Test("AES-128 — encrypt → decrypt round-trip (data matches original)")
    func roundTrip() throws {
        let km = KeyManager()
        let key = try km.generateKey()
        let iv = try km.generateIV()
        let original = Data(repeating: 0xCD, count: 1024)

        let encryptor = SegmentEncryptor()
        let encrypted = try encryptor.encrypt(
            segmentData: original, key: key, iv: iv
        )
        let decrypted = try encryptor.decrypt(
            segmentData: encrypted, key: key, iv: iv
        )
        #expect(decrypted == original)
    }

    @Test("AES-128 — batch encrypt segments from tiny segmentation result")
    func batchEncrypt() throws {
        let tinyMP4 = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 3,
            keyframeInterval: 1,
            sampleDelta: 3000,
            timescale: 90000
        )
        let segResult = try MP4Segmenter().segment(data: tinyMP4)

        let km = KeyManager()
        let key = try km.generateKey()
        let keyURL = try #require(URL(string: "https://example.com/key"))
        let config = EncryptionConfig(
            method: .aes128,
            keyURL: keyURL,
            key: key
        )

        let encResult = try SegmentEncryptor().encryptSegments(
            result: segResult, config: config
        )
        #expect(encResult.segmentCount == segResult.segmentCount)
        if let playlist = encResult.playlist {
            #expect(playlist.contains("METHOD=AES-128"))
        }
    }
}

// MARK: - SAMPLE-AES

@Suite("Encryption Showcase — SAMPLE-AES")
struct SampleAESEncryptionShowcase {

    @Test("SAMPLE-AES — encrypt video NAL units")
    func encryptVideo() throws {
        let km = KeyManager()
        let key = try km.generateKey()
        let iv = try km.generateIV()
        let videoData = Data(repeating: 0x42, count: 256)

        let encrypted = try SampleEncryptor().encryptVideoSamples(
            videoData, key: key, iv: iv
        )
        #expect(encrypted.count == videoData.count)
    }

    @Test("SAMPLE-AES — encrypt audio ADTS frames")
    func encryptAudio() throws {
        let km = KeyManager()
        let key = try km.generateKey()
        let iv = try km.generateIV()
        let audioData = Data(repeating: 0x55, count: 256)

        let encrypted = try SampleEncryptor().encryptAudioSamples(
            audioData, key: key, iv: iv
        )
        #expect(encrypted.count == audioData.count)
    }

    @Test("SAMPLE-AES — encrypt → decrypt round-trip for video")
    func videoRoundTrip() throws {
        let km = KeyManager()
        let key = try km.generateKey()
        let iv = try km.generateIV()
        let original = Data(repeating: 0x77, count: 256)

        let enc = SampleEncryptor()
        let encrypted = try enc.encryptVideoSamples(original, key: key, iv: iv)
        let decrypted = try enc.decryptVideoSamples(encrypted, key: key, iv: iv)
        #expect(decrypted == original)
    }
}

// MARK: - Encryption Integration

@Suite("Encryption Showcase — Integration")
struct EncryptionIntegrationShowcase {

    @Test("AES-128 vs SAMPLE-AES — different encrypted output")
    func differentMethods() throws {
        let km = KeyManager()
        let key = try km.generateKey()
        let iv = try km.generateIV()
        let data = Data(repeating: 0xAA, count: 1024)

        let aes128 = try SegmentEncryptor().encrypt(
            segmentData: data, key: key, iv: iv
        )
        let sampleAES = try SampleEncryptor().encryptVideoSamples(
            data, key: key, iv: iv
        )

        #expect(aes128 != sampleAES)
    }

    @Test("EncryptionMethod — .none, .aes128, .sampleAES raw values")
    func encryptionMethodValues() {
        #expect(EncryptionMethod.none.rawValue == "NONE")
        #expect(EncryptionMethod.aes128.rawValue == "AES-128")
        #expect(EncryptionMethod.sampleAES.rawValue == "SAMPLE-AES")
    }
}
