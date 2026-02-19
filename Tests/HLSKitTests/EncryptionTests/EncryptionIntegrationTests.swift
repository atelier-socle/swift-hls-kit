// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Encryption — Integration")
struct EncryptionIntegrationTests {

    // MARK: - Segment + Encrypt Round-Trip

    @Test("Encrypt segments then decrypt: data matches original")
    func encryptDecryptRoundTrip() throws {
        let encryptor = SegmentEncryptor()
        let key = try KeyManager().generateKey()

        let original = (0..<3).map { i in
            MediaSegmentOutput(
                index: i,
                data: Data(
                    repeating: UInt8(truncatingIfNeeded: i + 1),
                    count: 188
                ),
                duration: 6.0,
                filename: "segment_\(i).ts",
                byteRangeOffset: nil,
                byteRangeLength: nil
            )
        }

        let fileInfo = MP4FileInfo(
            timescale: 90000,
            duration: 1_620_000,
            brands: ["isom"],
            tracks: []
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)
        let segResult = SegmentationResult(
            initSegment: Data(),
            mediaSegments: original,
            playlist: """
                #EXTM3U
                #EXT-X-VERSION:3
                #EXT-X-TARGETDURATION:6
                #EXTINF:6.0,
                segment_0.ts
                #EXTINF:6.0,
                segment_1.ts
                #EXTINF:6.0,
                segment_2.ts
                #EXT-X-ENDLIST
                """,
            fileInfo: fileInfo,
            config: SegmentationConfig(
                containerFormat: .mpegTS
            )
        )

        let encrypted = try encryptor.encryptSegments(
            result: segResult, config: config
        )

        // Decrypt each segment
        let keyManager = KeyManager()
        for (i, seg) in encrypted.mediaSegments.enumerated() {
            let iv = keyManager.deriveIV(
                fromSequenceNumber: UInt64(i)
            )
            let decrypted = try encryptor.decrypt(
                segmentData: seg.data, key: key, iv: iv
            )
            #expect(decrypted == original[i].data)
        }
    }

    // MARK: - HLSEngine Integration

    @Test("HLSEngine.encrypt produces encrypted result")
    func engineEncrypt() throws {
        let segments = [
            MediaSegmentOutput(
                index: 0,
                data: Data(repeating: 0xAA, count: 100),
                duration: 6.0,
                filename: "segment_0.ts",
                byteRangeOffset: nil,
                byteRangeLength: nil
            )
        ]
        let fileInfo = MP4FileInfo(
            timescale: 90000,
            duration: 540_000,
            brands: ["isom"],
            tracks: []
        )
        let result = SegmentationResult(
            initSegment: Data(),
            mediaSegments: segments,
            playlist: """
                #EXTM3U
                #EXT-X-VERSION:3
                #EXT-X-TARGETDURATION:6
                #EXTINF:6.0,
                segment_0.ts
                #EXT-X-ENDLIST
                """,
            fileInfo: fileInfo,
            config: SegmentationConfig(
                containerFormat: .mpegTS
            )
        )

        let key = Data(repeating: 0xBB, count: 16)
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)

        let engine = HLSEngine()
        let encrypted = try engine.encrypt(
            segments: result, config: config
        )

        #expect(encrypted.mediaSegments.count == 1)
        #expect(
            encrypted.mediaSegments[0].data
                != segments[0].data
        )
        let playlist = try #require(encrypted.playlist)
        #expect(playlist.contains("#EXT-X-KEY:"))
    }

    // MARK: - HLSEngine segmentAndEncrypt

    @Test("HLSEngine.segmentAndEncrypt segments then encrypts")
    func engineSegmentAndEncrypt() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "enc-sae-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let inputURL = dir.appendingPathComponent("input.mp4")
        try data.write(to: inputURL)

        let outputDir = dir.appendingPathComponent("output")
        let key = Data(repeating: 0xCC, count: 16)
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let encConfig = EncryptionConfig(
            keyURL: url, key: key
        )

        let engine = HLSEngine()
        let result = try engine.segmentAndEncrypt(
            input: inputURL,
            outputDirectory: outputDir,
            encryptionConfig: encConfig
        )

        #expect(result.mediaSegments.count > 0)
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-KEY:"))
        #expect(playlist.contains("METHOD=AES-128"))
    }

    // MARK: - Encrypted Playlist Validation

    @Test("Encrypted playlist validates with HLSValidator")
    func validatorAcceptsEncryptedPlaylist() throws {
        let playlist = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key.bin"
            #EXTINF:6.0,
            segment_0.ts
            #EXTINF:6.0,
            segment_1.ts
            #EXT-X-ENDLIST
            """

        let engine = HLSEngine()
        let report = try engine.validateString(playlist)
        #expect(report.errors.isEmpty)
    }

    // MARK: - Key File Round-Trip

    @Test("Write key, encrypt, read key, decrypt: matches")
    func keyFileRoundTrip() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "enc-keyrt-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let keyManager = KeyManager()
        let key = try keyManager.generateKey()
        let keyURL = dir.appendingPathComponent("key.bin")
        try keyManager.writeKey(key, to: keyURL)

        let encryptor = SegmentEncryptor()
        let original = Data("Test segment content".utf8)
        let iv = keyManager.deriveIV(fromSequenceNumber: 0)

        let encrypted = try encryptor.encrypt(
            segmentData: original, key: key, iv: iv
        )

        let readKey = try keyManager.readKey(from: keyURL)
        let decrypted = try encryptor.decrypt(
            segmentData: encrypted, key: readKey, iv: iv
        )

        #expect(decrypted == original)
    }
}
