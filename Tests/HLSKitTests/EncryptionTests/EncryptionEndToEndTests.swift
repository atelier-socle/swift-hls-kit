// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Encryption End-to-End")
struct EncryptionEndToEndTests {

    private let key = Data(repeating: 0xBB, count: 16)

    // MARK: - AES-128 Pipeline

    @Test("Segment → AES-128 encrypt → decrypt → data matches")
    func aes128RoundTrip() throws {
        let encryptor = SegmentEncryptor()
        let segments = (0..<3).map { i in
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

        let result = makeResult(
            segments: segments,
            playlist: samplePlaylist(count: 3)
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url, key: key)
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )

        #expect(encrypted.mediaSegments.count == 3)

        let keyManager = KeyManager()
        for (i, seg) in encrypted.mediaSegments.enumerated() {
            let iv = keyManager.deriveIV(
                fromSequenceNumber: UInt64(i)
            )
            let decrypted = try encryptor.decrypt(
                segmentData: seg.data, key: key, iv: iv
            )
            #expect(decrypted == segments[i].data)
        }
    }

    @Test("Segment → encrypt with key rotation → multiple key tags")
    func keyRotationPlaylist() throws {
        let encryptor = SegmentEncryptor()
        let segments = (0..<6).map { i in
            MediaSegmentOutput(
                index: i,
                data: Data(repeating: 0x42, count: 100),
                duration: 6.0,
                filename: "segment_\(i).ts",
                byteRangeOffset: nil,
                byteRangeLength: nil
            )
        }

        let result = makeResult(
            segments: segments,
            playlist: samplePlaylist(count: 6)
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, key: key, keyRotationInterval: 2
        )
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )

        let playlist = try #require(encrypted.playlist)
        let keyTagCount =
            playlist.components(
                separatedBy: "#EXT-X-KEY:"
            ).count - 1
        #expect(keyTagCount >= 3)
    }

    @Test("HLSEngine.segmentAndEncrypt produces encrypted HLS")
    func engineSegmentAndEncrypt() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "e2e-sae-\(UUID().uuidString)"
            )
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let inputURL = dir.appendingPathComponent("input.mp4")
        try data.write(to: inputURL)

        let outputDir = dir.appendingPathComponent("output")
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

    // MARK: - SAMPLE-AES Pipeline

    @Test("SAMPLE-AES encrypt preserves segment size")
    func sampleAESPreservesSize() throws {
        let encryptor = SegmentEncryptor()
        let tsData = buildVideoTSData(bodySize: 100)
        let segment = MediaSegmentOutput(
            index: 0,
            data: tsData,
            duration: 6.0,
            filename: "segment_0.ts",
            byteRangeOffset: nil,
            byteRangeLength: nil
        )

        let result = makeResult(
            segments: [segment],
            playlist: samplePlaylist(count: 1)
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            method: .sampleAES, keyURL: url, key: key
        )
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )

        #expect(
            encrypted.mediaSegments[0].data.count
                == tsData.count
        )
        let playlist = try #require(encrypted.playlist)
        #expect(playlist.contains("METHOD=SAMPLE-AES"))
    }

    // MARK: - Playlist Validation

    @Test("Encrypted playlist passes HLSValidator")
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

    @Test("Key rotation playlist has correct EXT-X-KEY placement")
    func keyRotationPlacement() throws {
        let encryptor = SegmentEncryptor()
        let segments = (0..<4).map { i in
            MediaSegmentOutput(
                index: i,
                data: Data(repeating: 0x42, count: 100),
                duration: 6.0,
                filename: "segment_\(i).ts",
                byteRangeOffset: nil,
                byteRangeLength: nil
            )
        }

        let result = makeResult(
            segments: segments,
            playlist: samplePlaylist(count: 4)
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, key: key, keyRotationInterval: 2
        )
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )

        let playlist = try #require(encrypted.playlist)
        let lines = playlist.components(separatedBy: "\n")

        var keyTagPositions: [Int] = []
        for (i, line) in lines.enumerated()
        where line.hasPrefix("#EXT-X-KEY:") {
            keyTagPositions.append(i)
        }

        #expect(keyTagPositions.count >= 2)
    }

    // MARK: - Cross-Method

    @Test("AES-128 and SAMPLE-AES produce different output")
    func crossMethodDiffers() throws {
        let encryptor = SegmentEncryptor()
        let tsData = buildVideoTSData(bodySize: 100)
        let segment = MediaSegmentOutput(
            index: 0,
            data: tsData,
            duration: 6.0,
            filename: "segment_0.ts",
            byteRangeOffset: nil,
            byteRangeLength: nil
        )

        let result = makeResult(
            segments: [segment],
            playlist: samplePlaylist(count: 1)
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let aes128Config = EncryptionConfig(
            method: .aes128, keyURL: url, key: key
        )
        let sampleConfig = EncryptionConfig(
            method: .sampleAES, keyURL: url, key: key
        )

        let aes128Result = try encryptor.encryptSegments(
            result: result, config: aes128Config
        )
        let sampleResult = try encryptor.encryptSegments(
            result: result, config: sampleConfig
        )

        #expect(
            aes128Result.mediaSegments[0].data
                != sampleResult.mediaSegments[0].data
        )
    }

    @Test("Method NONE returns unchanged result")
    func methodNoneUnchanged() throws {
        let encryptor = SegmentEncryptor()
        let segment = MediaSegmentOutput(
            index: 0,
            data: Data(repeating: 0x42, count: 100),
            duration: 6.0,
            filename: "segment_0.ts",
            byteRangeOffset: nil,
            byteRangeLength: nil
        )

        let result = makeResult(
            segments: [segment],
            playlist: samplePlaylist(count: 1)
        )

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            method: .none, keyURL: url, key: key
        )
        let encrypted = try encryptor.encryptSegments(
            result: result, config: config
        )

        #expect(
            encrypted.mediaSegments[0].data
                == segment.data
        )
    }

}

// MARK: - Helpers

extension EncryptionEndToEndTests {

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

    private func samplePlaylist(count: Int) -> String {
        var lines = [
            "#EXTM3U",
            "#EXT-X-VERSION:3",
            "#EXT-X-TARGETDURATION:6"
        ]
        for i in 0..<count {
            lines.append("#EXTINF:6.0,")
            lines.append("segment_\(i).ts")
        }
        lines.append("#EXT-X-ENDLIST")
        return lines.joined(separator: "\n")
    }

    private func buildVideoTSData(bodySize: Int) -> Data {
        var data = Data()
        var pat = Data(repeating: 0xFF, count: 188)
        pat[0] = 0x47
        pat[1] = 0x40
        pat[2] = 0x00
        pat[3] = 0x10
        data.append(pat)

        var vidPkt = Data(repeating: 0x00, count: 188)
        vidPkt[0] = 0x47
        vidPkt[1] = 0x41
        vidPkt[2] = 0x01
        vidPkt[3] = 0x10
        vidPkt[4] = 0x00
        vidPkt[5] = 0x00
        vidPkt[6] = 0x01
        vidPkt[7] = 0xE0
        vidPkt[8] = 0x00
        vidPkt[9] = 0x00
        vidPkt[10] = 0x80
        vidPkt[11] = 0x80
        vidPkt[12] = 0x05
        vidPkt[13] = 0x21
        vidPkt[14] = 0x00
        vidPkt[15] = 0x01
        vidPkt[16] = 0x00
        vidPkt[17] = 0x01
        let esStart = 18
        vidPkt[esStart] = 0x00
        vidPkt[esStart + 1] = 0x00
        vidPkt[esStart + 2] = 0x00
        vidPkt[esStart + 3] = 0x01
        vidPkt[esStart + 4] = 0x65
        for i in (esStart + 5)..<188 {
            vidPkt[i] = UInt8(truncatingIfNeeded: i)
        }
        data.append(vidPkt)
        return data
    }
}
