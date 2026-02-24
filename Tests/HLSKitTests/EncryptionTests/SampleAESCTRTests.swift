// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SAMPLE-AES-CTR Encryption")
struct SampleAESCTRTests {

    // MARK: - EncryptionMethod

    @Test("EncryptionMethod: sampleAESCTR case exists")
    func encryptionMethodSampleAESCTR() {
        let method = EncryptionMethod.sampleAESCTR
        #expect(method.rawValue == "SAMPLE-AES-CTR")
    }

    @Test("EncryptionMethod: all cases includes sampleAESCTR")
    func encryptionMethodAllCases() {
        let cases = EncryptionMethod.allCases
        #expect(cases.contains(.sampleAESCTR))
    }

    @Test("EncryptionMethod: parse SAMPLE-AES-CTR string")
    func parseEncryptionMethod() {
        let method = EncryptionMethod(rawValue: "SAMPLE-AES-CTR")
        #expect(method == .sampleAESCTR)
    }

    // MARK: - EncryptionKey with SAMPLE-AES-CTR

    @Test("EncryptionKey: create with sampleAESCTR method")
    func encryptionKeySampleAESCTR() {
        let key = EncryptionKey(
            method: .sampleAESCTR,
            uri: "https://example.com/ctr-key"
        )
        #expect(key.method == .sampleAESCTR)
        #expect(key.uri == "https://example.com/ctr-key")
    }

    @Test("EncryptionKey: sampleAESCTR with IV")
    func encryptionKeySampleAESCTRWithIV() {
        let key = EncryptionKey(
            method: .sampleAESCTR,
            uri: "https://example.com/ctr-key",
            iv: "0x42424242424242424242424242424242"
        )
        #expect(key.iv != nil)
    }

    @Test("EncryptionKey: sampleAESCTR with KEYFORMAT")
    func encryptionKeySampleAESCTRWithKeyFormat() {
        let key = EncryptionKey(
            method: .sampleAESCTR,
            uri: "https://example.com/ctr-key",
            keyFormat: "identity"
        )
        #expect(key.keyFormat == "identity")
    }

    // MARK: - Parsing

    @Test("TagParser: parses EXT-X-KEY with SAMPLE-AES-CTR")
    func parseKeySampleAESCTR() throws {
        let parser = TagParser()
        let attributes = "METHOD=SAMPLE-AES-CTR,URI=\"https://example.com/key\""
        let key = try parser.parseKey(attributes)
        #expect(key.method == .sampleAESCTR)
    }

    @Test("ManifestParser: parses media playlist with SAMPLE-AES-CTR")
    func parseMediaPlaylistSampleAESCTR() throws {
        let manifest = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-TARGETDURATION:6
            #EXT-X-KEY:METHOD=SAMPLE-AES-CTR,URI="https://example.com/key"
            #EXTINF:6.0,
            segment001.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let result = try parser.parse(manifest)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.segments.first?.key?.method == .sampleAESCTR)
    }

    // MARK: - Generation

    @Test("TagWriter: writes SAMPLE-AES-CTR method")
    func writeKeySampleAESCTR() {
        let writer = TagWriter()
        let key = EncryptionKey(
            method: .sampleAESCTR,
            uri: "https://example.com/key"
        )
        let output = writer.writeKey(key)
        #expect(output.contains("METHOD=SAMPLE-AES-CTR"))
    }

    @Test("ManifestGenerator: writes KEY with SAMPLE-AES-CTR")
    func generateMediaPlaylistSampleAESCTR() {
        let key = EncryptionKey(
            method: .sampleAESCTR,
            uri: "https://example.com/key"
        )
        let segment = Segment(
            duration: 6.0,
            uri: "segment001.ts",
            key: key
        )
        let playlist = MediaPlaylist(
            version: .v7,
            targetDuration: 6,
            playlistType: .vod,
            hasEndList: true,
            segments: [segment]
        )
        let generator = ManifestGenerator()
        let output = generator.generateMedia(playlist)

        #expect(output.contains("METHOD=SAMPLE-AES-CTR"))
    }

    // MARK: - Round-Trip

    @Test("SAMPLE-AES-CTR round-trip: parse → generate → parse")
    func sampleAESCTRRoundTrip() throws {
        let original = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-TARGETDURATION:6
            #EXT-X-KEY:METHOD=SAMPLE-AES-CTR,URI="https://example.com/key"
            #EXTINF:6.0,
            segment001.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let generator = ManifestGenerator()

        let result1 = try parser.parse(original)
        guard case .media(let playlist1) = result1 else {
            Issue.record("Expected media playlist")
            return
        }
        let generated = generator.generateMedia(playlist1)
        let result2 = try parser.parse(generated)
        guard case .media(let playlist2) = result2 else {
            Issue.record("Expected media playlist after round-trip")
            return
        }

        #expect(playlist1.segments.first?.key?.method == playlist2.segments.first?.key?.method)
        #expect(playlist1.segments.first?.key?.method == .sampleAESCTR)
    }

    // MARK: - Validation

    @Test("HLSValidator: SAMPLE-AES-CTR requires version 7+")
    func validateSampleAESCTRVersion() {
        let key = EncryptionKey(
            method: .sampleAESCTR,
            uri: "https://example.com/key"
        )
        let segment = Segment(
            duration: 6.0,
            uri: "segment001.ts",
            key: key
        )
        let playlist = MediaPlaylist(
            version: .v7,
            targetDuration: 6,
            playlistType: .vod,
            hasEndList: true,
            segments: [segment]
        )
        let validator = HLSValidator()
        let report = validator.validate(playlist)
        #expect(report.isValid)
    }

    // MARK: - Comparison with other methods

    @Test("EncryptionMethod: sampleAESCTR different from sampleAES")
    func sampleAESCTRDifferentFromSampleAES() {
        #expect(EncryptionMethod.sampleAESCTR != EncryptionMethod.sampleAES)
        #expect(EncryptionMethod.sampleAESCTR.rawValue != EncryptionMethod.sampleAES.rawValue)
    }

    @Test("EncryptionMethod: sampleAESCTR different from aes128")
    func sampleAESCTRDifferentFromAES128() {
        #expect(EncryptionMethod.sampleAESCTR != EncryptionMethod.aes128)
    }
}
