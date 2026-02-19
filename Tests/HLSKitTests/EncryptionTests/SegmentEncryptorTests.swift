// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SegmentEncryptor")
struct SegmentEncryptorTests {

    private let encryptor = SegmentEncryptor()
    private let key = Data(repeating: 0xAB, count: 16)
    private let iv = Data(repeating: 0xCD, count: 16)

    // MARK: - Single Segment

    @Test("Encrypt single segment: output differs from input")
    func encryptSingle() throws {
        let data = Data("HLS segment payload".utf8)
        let encrypted = try encryptor.encrypt(
            segmentData: data, key: key, iv: iv
        )
        #expect(encrypted != data)
        #expect(!encrypted.isEmpty)
    }

    @Test("Encrypt + decrypt round-trip: data matches")
    func roundTrip() throws {
        let data = Data(repeating: 0x42, count: 188)
        let encrypted = try encryptor.encrypt(
            segmentData: data, key: key, iv: iv
        )
        let decrypted = try encryptor.decrypt(
            segmentData: encrypted, key: key, iv: iv
        )
        #expect(decrypted == data)
    }

    @Test("Encrypt with derived IV produces consistent results")
    func derivedIV() throws {
        let data = Data("segment content".utf8)
        let derivedIV = KeyManager().deriveIV(
            fromSequenceNumber: 5
        )
        let enc1 = try encryptor.encrypt(
            segmentData: data, key: key, iv: derivedIV
        )
        let enc2 = try encryptor.encrypt(
            segmentData: data, key: key, iv: derivedIV
        )
        #expect(enc1 == enc2)
    }

    @Test("Encrypted segment is larger due to PKCS#7 padding")
    func paddingIncreasesSize() throws {
        let data = Data(repeating: 0xFF, count: 100)
        let encrypted = try encryptor.encrypt(
            segmentData: data, key: key, iv: iv
        )
        #expect(encrypted.count > data.count)
        #expect(encrypted.count == 112)
    }

    // MARK: - Batch Encryption

    @Test("encryptSegments encrypts all segments")
    func batchEncrypt() throws {
        let segments = (0..<3).map { i in
            MediaSegmentOutput(
                index: i,
                data: Data(repeating: UInt8(i), count: 188),
                duration: 6.0,
                filename: "segment_\(i).ts",
                byteRangeOffset: nil,
                byteRangeLength: nil
            )
        }
        let result = makeResult(
            segments: segments,
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
                """
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, key: key
        )
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )

        #expect(encrypted.mediaSegments.count == 3)
        for (i, seg) in encrypted.mediaSegments.enumerated() {
            #expect(seg.data != segments[i].data)
            #expect(seg.filename == segments[i].filename)
            #expect(seg.duration == segments[i].duration)
        }
    }

    @Test("encryptSegments adds EXT-X-KEY to playlist")
    func batchEncryptPlaylist() throws {
        let segment = makeSegment(index: 0)
        let result = makeResult(
            segments: [segment],
            playlist: """
                #EXTM3U
                #EXT-X-VERSION:3
                #EXT-X-TARGETDURATION:6
                #EXTINF:6.0,
                segment_0.ts
                #EXT-X-ENDLIST
                """
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )

        let playlist = try #require(encrypted.playlist)
        #expect(playlist.contains("#EXT-X-KEY:"))
        #expect(playlist.contains("METHOD=AES-128"))
        #expect(playlist.contains("example.com/key.bin"))
    }

    @Test("encryptSegments rejects unsupported method")
    func unsupportedMethod() throws {
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            method: .sampleAES, keyURL: url
        )
        let result = makeResult(segments: [], playlist: nil)
        #expect(throws: EncryptionError.self) {
            try encryptor.encryptSegments(
                result: result, config: config
            )
        }
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
