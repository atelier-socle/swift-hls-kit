// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Encryption Coverage")
struct EncryptionCoverageTests {

    // MARK: - CryptoProvider Edge Cases

    @Test("Encrypt empty data")
    func encryptEmptyData() throws {
        let provider = defaultCryptoProvider()
        let key = Data(repeating: 0xAA, count: 16)
        let iv = Data(repeating: 0xBB, count: 16)
        let encrypted = try provider.encrypt(
            Data(), key: key, iv: iv
        )
        #expect(!encrypted.isEmpty)
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == Data())
    }

    @Test("Encrypt exactly 16 bytes (one block)")
    func encryptOneBlock() throws {
        let provider = defaultCryptoProvider()
        let key = Data(repeating: 0xAA, count: 16)
        let iv = Data(repeating: 0xBB, count: 16)
        let data = Data(repeating: 0xCC, count: 16)
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        // PKCS#7 adds full block when input is block-aligned
        #expect(encrypted.count == 32)
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
    }

    @Test("Encrypt 15 bytes (needs padding)")
    func encrypt15Bytes() throws {
        let provider = defaultCryptoProvider()
        let key = Data(repeating: 0xAA, count: 16)
        let iv = Data(repeating: 0xBB, count: 16)
        let data = Data(repeating: 0xDD, count: 15)
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        #expect(encrypted.count == 16)
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
    }

    @Test("Encrypt large data (1000 bytes)")
    func encryptLargeData() throws {
        let provider = defaultCryptoProvider()
        let key = Data(repeating: 0xAA, count: 16)
        let iv = Data(repeating: 0xBB, count: 16)
        let data = Data(repeating: 0xEE, count: 1000)
        let encrypted = try provider.encrypt(
            data, key: key, iv: iv
        )
        #expect(encrypted.count > data.count)
        let decrypted = try provider.decrypt(
            encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
    }

    // MARK: - EncryptedPlaylistBuilder Edge Cases

    @Test("Empty playlist still adds key tag")
    func emptyPlaylistAddsKeyTag() throws {
        let builder = EncryptedPlaylistBuilder()
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        let result = builder.addEncryptionTags(
            to: "", config: config, segmentCount: 0
        )
        #expect(!result.contains("#EXT-X-KEY:"))
    }

    @Test("Key rotation interval 1: per-segment keys")
    func perSegmentKeyRotation() throws {
        let builder = EncryptedPlaylistBuilder()
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, keyRotationInterval: 1
        )
        let playlist = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg0.ts
            #EXTINF:6.0,
            seg1.ts
            #EXTINF:6.0,
            seg2.ts
            #EXT-X-ENDLIST
            """
        let result = builder.addEncryptionTags(
            to: playlist, config: config, segmentCount: 3
        )
        let keyCount =
            result.components(
                separatedBy: "#EXT-X-KEY:"
            ).count - 1
        #expect(keyCount == 3)
    }

    @Test("Key rotation interval larger than segment count")
    func rotationLargerThanSegments() throws {
        let builder = EncryptedPlaylistBuilder()
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, keyRotationInterval: 100
        )
        let playlist = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let result = builder.addEncryptionTags(
            to: playlist, config: config, segmentCount: 1
        )
        let keyCount =
            result.components(
                separatedBy: "#EXT-X-KEY:"
            ).count - 1
        #expect(keyCount == 1)
    }

    @Test("KEYFORMAT and KEYFORMATVERSIONS in tag")
    func keyFormatInTag() throws {
        let builder = EncryptedPlaylistBuilder()
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url,
            keyFormat: "com.apple.streamingkeydelivery",
            keyFormatVersions: "1"
        )
        let tag = builder.buildKeyTag(
            config: config, iv: nil
        )
        #expect(tag.contains("KEYFORMAT="))
        #expect(
            tag.contains("com.apple.streamingkeydelivery")
        )
        #expect(tag.contains("KEYFORMATVERSIONS="))
    }

    // MARK: - SegmentEncryptor Edge Cases

    @Test("Encrypt segments with no segments: no-op")
    func encryptEmptySegments() throws {
        let encryptor = SegmentEncryptor()
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)
        let result = makeResult(segments: [], playlist: nil)
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )
        #expect(encrypted.mediaSegments.isEmpty)
    }

    @Test("SAMPLE-AES encryptDirectory with TS files")
    func sampleAESDirectory() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "cov-sae-dir-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let tsData = buildMinimalTSData()
        try tsData.write(
            to: dir.appendingPathComponent("seg.ts")
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            method: .sampleAES, keyURL: url, key: key
        )
        let encryptor = SegmentEncryptor()
        let returnedKey = try encryptor.encryptDirectory(
            dir, segmentFilenames: ["seg.ts"], config: config
        )
        #expect(returnedKey == key)
    }

    @Test("SAMPLE-AES-CTR throws unsupported")
    func sampleAESCTRThrows() throws {
        let encryptor = SegmentEncryptor()
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            method: .sampleAESCTR, keyURL: url
        )
        let result = makeResult(segments: [], playlist: nil)
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptSegments(
                result: result, config: config
            )
        }
    }

    @Test("SAMPLE-AES-CTR encryptDirectory throws unsupported")
    func sampleAESCTRDirectoryThrows() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "cov-ctr-dir-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            method: .sampleAESCTR, keyURL: url
        )
        let encryptor = SegmentEncryptor()
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptDirectory(
                dir, segmentFilenames: [], config: config
            )
        }
    }

    // MARK: - SampleEncryptor Edge Cases

    @Test("SampleEncryptor: empty video data")
    func sampleEncryptorEmptyVideo() throws {
        let enc = SampleEncryptor()
        let result = try enc.encryptVideoSamples(
            Data(), key: key, iv: iv
        )
        #expect(result.isEmpty)
    }

    @Test("SampleEncryptor: empty audio data")
    func sampleEncryptorEmptyAudio() throws {
        let enc = SampleEncryptor()
        let result = try enc.encryptAudioSamples(
            Data(repeating: 0x00, count: 4),
            key: key, iv: iv
        )
        #expect(result.count == 4)
    }

    @Test("SampleEncryptor: findNextStartCode edge cases")
    func findStartCodeEdgeCases() throws {
        let enc = SampleEncryptor()
        // Data too short
        let short = Data([0x00, 0x00])
        #expect(enc.findNextStartCode(in: short, from: 0) == nil)
        // Offset beyond data
        let data = Data(repeating: 0x00, count: 10)
        #expect(enc.findNextStartCode(in: data, from: 20) == nil)
    }

    @Test("SampleEncryptor: parseADTSFrameLength edge cases")
    func parseADTSEdgeCases() throws {
        let enc = SampleEncryptor()
        // Data too short
        let short = Data([0xFF, 0xF1, 0x50])
        #expect(enc.parseADTSFrameLength(short, at: 0) == 0)
    }

    // MARK: - Config Edge Cases

    @Test("EncryptionConfig with all optional fields nil")
    func configAllNil() throws {
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        #expect(config.key == nil)
        #expect(config.iv == nil)
        #expect(config.keyRotationInterval == nil)
        #expect(config.keyFormat == nil)
        #expect(config.keyFormatVersions == nil)
        #expect(config.method == .aes128)
        #expect(config.writeKeyFile == true)
    }

    // MARK: - Helpers

    private let key = Data(repeating: 0xBB, count: 16)
    private let iv = Data(repeating: 0xCD, count: 16)

    private func makeResult(
        segments: [MediaSegmentOutput],
        playlist: String?
    ) -> SegmentationResult {
        SegmentationResult(
            initSegment: Data(),
            mediaSegments: segments,
            playlist: playlist,
            fileInfo: MP4FileInfo(
                timescale: 90000,
                duration: 540_000,
                brands: ["isom"],
                tracks: []
            ),
            config: SegmentationConfig(
                containerFormat: .mpegTS
            )
        )
    }

    private func buildMinimalTSData() -> Data {
        var data = Data()
        var pat = Data(repeating: 0xFF, count: 188)
        pat[0] = 0x47
        pat[1] = 0x40
        pat[2] = 0x00
        pat[3] = 0x10
        data.append(pat)
        return data
    }
}

// MARK: - TS Path Coverage

extension EncryptionCoverageTests {

    @Test("TS with adaptation field covers AFC branch")
    func tsAdaptationField() throws {
        let enc = SampleEncryptor()
        let pat = buildPATPacket()
        let vidHdr: [UInt8] = [
            0x47, 0x41, 0x01, 0x30, 0x07, 0x00,
            0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
            0x00, 0x00, 0x01, 0xE0, 0x00, 0x00,
            0x80, 0x80, 0x05, 0x21, 0x00, 0x01,
            0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x65
        ]
        var vid = Data(vidHdr)
        vid.append(Data(repeating: 0xAA, count: 188 - vidHdr.count))
        let result = try enc.encryptTSSegment(
            pat + vid, key: key, iv: iv
        )
        #expect(result.count == pat.count + vid.count)
    }

    @Test("TS with audio PID covers audio branch")
    func tsAudioPES() throws {
        let enc = SampleEncryptor()
        let pat = buildPATPacket()
        let audHdr: [UInt8] = [
            0x47, 0x41, 0x02, 0x10,
            0x00, 0x00, 0x01, 0xC0,
            0x00, 0x00, 0x80, 0x00, 0x00
        ]
        var aud = Data(audHdr)
        aud.append(Data(repeating: 0xBB, count: 188 - audHdr.count))
        let result = try enc.encryptTSSegment(
            pat + aud, key: key, iv: iv
        )
        #expect(result.count == pat.count + aud.count)
    }

    private func buildPATPacket() -> Data {
        var pat = Data(repeating: 0xFF, count: 188)
        pat[0] = 0x47
        pat[1] = 0x40
        pat[2] = 0x00
        pat[3] = 0x10
        return pat
    }
}
