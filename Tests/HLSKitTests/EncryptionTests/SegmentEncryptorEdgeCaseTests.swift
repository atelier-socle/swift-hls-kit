// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SegmentEncryptor — Edge Cases")
struct SegmentEncryptorEdgeCaseTests {

    private let encryptor = SegmentEncryptor()
    private let key = Data(repeating: 0xAB, count: 16)

    // MARK: - Directory Encryption

    @Test("encryptDirectory encrypts files in place")
    func directoryEncrypt() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "enc-dir-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let original = Data(repeating: 0x42, count: 188)
        let filename = "segment_0.ts"
        try original.write(
            to: dir.appendingPathComponent(filename)
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)
        let returnedKey = try encryptor.encryptDirectory(
            dir, segmentFilenames: [filename], config: config
        )

        #expect(returnedKey == key)

        let encrypted = try Data(
            contentsOf: dir.appendingPathComponent(filename)
        )
        #expect(encrypted != original)

        let keyFile = try Data(
            contentsOf: dir.appendingPathComponent("key.bin")
        )
        #expect(keyFile == key)
    }

    @Test("encryptDirectory does not write key when disabled")
    func directoryNoKeyFile() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "enc-nokey-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        try Data(repeating: 0x42, count: 100).write(
            to: dir.appendingPathComponent("seg.ts")
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, key: key, writeKeyFile: false
        )
        _ = try encryptor.encryptDirectory(
            dir, segmentFilenames: ["seg.ts"], config: config
        )

        let keyExists = FileManager.default.fileExists(
            atPath: dir.appendingPathComponent("key.bin").path
        )
        #expect(!keyExists)
    }

    @Test("encryptDirectory with unsupported method throws")
    func directoryUnsupportedMethod() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "enc-unsup-\(UUID().uuidString)"
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
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptDirectory(
                dir, segmentFilenames: [], config: config
            )
        }
    }

    @Test("encryptDirectory with missing segment throws")
    func directoryMissingSegment() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "enc-miss-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptDirectory(
                dir,
                segmentFilenames: ["nonexistent.ts"],
                config: config
            )
        }
    }

    // MARK: - Custom Provider & Edge Cases

    @Test("Custom crypto provider is used")
    func customProvider() throws {
        let custom = SegmentEncryptor(
            cryptoProvider: defaultCryptoProvider()
        )
        let iv = Data(repeating: 0xCD, count: 16)
        let data = Data("test".utf8)
        let enc = try custom.encrypt(
            segmentData: data, key: key, iv: iv
        )
        let dec = try custom.decrypt(
            segmentData: enc, key: key, iv: iv
        )
        #expect(dec == data)
    }

    @Test("Encrypt with explicit IV uses it")
    func explicitIV() throws {
        let segment = makeSegment()
        let result = makeResult(
            segments: [segment],
            playlist: """
                #EXTM3U
                #EXT-X-TARGETDURATION:6
                #EXTINF:6.0,
                segment_0.ts
                #EXT-X-ENDLIST
                """
        )
        let explicitIV = Data(repeating: 0x01, count: 16)
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, key: key, iv: explicitIV
        )
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )
        let decrypted = try encryptor.decrypt(
            segmentData: encrypted.mediaSegments[0].data,
            key: key,
            iv: explicitIV
        )
        #expect(decrypted == segment.data)
    }

    @Test("Encrypt result without playlist keeps nil")
    func noPlaylist() throws {
        let segment = makeSegment()
        let result = makeResult(
            segments: [segment], playlist: nil
        )
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )
        #expect(encrypted.playlist == nil)
    }

    @Test("Encrypt generates key when not provided")
    func generatesKey() throws {
        let segment = makeSegment()
        let result = makeResult(
            segments: [segment], playlist: nil
        )
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )
        #expect(
            encrypted.mediaSegments[0].data != segment.data
        )
    }

    // MARK: - Helpers

    private func makeSegment(
        index: Int = 0, size: Int = 100
    ) -> MediaSegmentOutput {
        MediaSegmentOutput(
            index: index,
            data: Data(repeating: 0x42, count: size),
            duration: 6.0,
            filename: "segment_\(index).ts",
            byteRangeOffset: nil,
            byteRangeLength: nil
        )
    }

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
}
