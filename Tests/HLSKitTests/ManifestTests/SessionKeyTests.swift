// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EXT-X-SESSION-KEY")
struct SessionKeyTests {

    // MARK: - MasterPlaylist Property

    @Test("MasterPlaylist: sessionKeys property exists")
    func masterPlaylistSessionKeysProperty() {
        let sessionKey = EncryptionKey(
            method: .aes128,
            uri: "https://example.com/key"
        )
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 2_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "video/playlist.m3u8"
                )
            ],
            sessionKeys: [sessionKey]
        )
        #expect(playlist.sessionKeys.count == 1)
    }

    @Test("MasterPlaylist: sessionKeys empty by default")
    func masterPlaylistSessionKeysEmptyDefault() {
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 2_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "video/playlist.m3u8"
                )
            ]
        )
        #expect(playlist.sessionKeys.isEmpty)
    }

    // MARK: - Session Key with Different Methods

    @Test("SessionKey: AES-128 method")
    func sessionKeyAES128() {
        let key = EncryptionKey(
            method: .aes128,
            uri: "https://example.com/key",
            iv: "0x00000000000000000000000000000001"
        )
        #expect(key.method == .aes128)
        #expect(key.uri == "https://example.com/key")
        #expect(key.iv != nil)
    }

    @Test("SessionKey: SAMPLE-AES method")
    func sessionKeySampleAES() {
        let key = EncryptionKey(
            method: .sampleAES,
            uri: "https://example.com/sample-key"
        )
        #expect(key.method == .sampleAES)
    }

    @Test("SessionKey: SAMPLE-AES-CTR method")
    func sessionKeySampleAESCTR() {
        let key = EncryptionKey(
            method: .sampleAESCTR,
            uri: "https://example.com/ctr-key"
        )
        #expect(key.method == .sampleAESCTR)
    }

    // MARK: - Parsing

    @Test("ManifestParser: parses EXT-X-SESSION-KEY")
    func parseSessionKey() throws {
        let manifest = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-SESSION-KEY:METHOD=AES-128,URI="https://example.com/key"
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080
            video/playlist.m3u8
            """
        let parser = ManifestParser()
        let result = try parser.parse(manifest)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }

        #expect(playlist.sessionKeys.count == 1)
        #expect(playlist.sessionKeys.first?.method == .aes128)
        #expect(playlist.sessionKeys.first?.uri == "https://example.com/key")
    }

    @Test("ManifestParser: parses multiple EXT-X-SESSION-KEY tags")
    func parseMultipleSessionKeys() throws {
        let manifest = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-SESSION-KEY:METHOD=AES-128,URI="https://example.com/key1"
            #EXT-X-SESSION-KEY:METHOD=SAMPLE-AES,URI="https://example.com/key2"
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080
            video/playlist.m3u8
            """
        let parser = ManifestParser()
        let result = try parser.parse(manifest)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }

        #expect(playlist.sessionKeys.count == 2)
    }

    @Test("ManifestParser: parses SESSION-KEY with IV")
    func parseSessionKeyWithIV() throws {
        let manifest = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-SESSION-KEY:METHOD=AES-128,URI="https://example.com/key",IV=0x00000000000000000000000000000001
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080
            video/playlist.m3u8
            """
        let parser = ManifestParser()
        let result = try parser.parse(manifest)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }

        #expect(playlist.sessionKeys.first?.iv != nil)
    }

    // MARK: - Generation

    @Test("ManifestGenerator: writes EXT-X-SESSION-KEY")
    func generateSessionKey() {
        let sessionKey = EncryptionKey(
            method: .aes128,
            uri: "https://example.com/key"
        )
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 2_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "video/playlist.m3u8"
                )
            ],
            sessionKeys: [sessionKey]
        )
        let generator = ManifestGenerator()
        let output = generator.generateMaster(playlist)

        #expect(output.contains("#EXT-X-SESSION-KEY:"))
        #expect(output.contains("METHOD=AES-128"))
        #expect(output.contains("URI=\"https://example.com/key\""))
    }

    @Test("ManifestGenerator: writes SESSION-KEY with IV")
    func generateSessionKeyWithIV() {
        let sessionKey = EncryptionKey(
            method: .aes128,
            uri: "https://example.com/key",
            iv: "0x00000000000000000000000000000001"
        )
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 2_000_000,
                    resolution: Resolution(width: 1920, height: 1080),
                    uri: "video/playlist.m3u8"
                )
            ],
            sessionKeys: [sessionKey]
        )
        let generator = ManifestGenerator()
        let output = generator.generateMaster(playlist)

        #expect(output.contains("IV="))
    }

    // MARK: - Round-Trip

    @Test("Session key round-trip: parse → generate → parse")
    func sessionKeyRoundTrip() throws {
        let original = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-SESSION-KEY:METHOD=AES-128,URI="https://example.com/key"
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1920x1080
            video/playlist.m3u8
            """
        let parser = ManifestParser()
        let generator = ManifestGenerator()

        let result1 = try parser.parse(original)
        guard case .master(let playlist1) = result1 else {
            Issue.record("Expected master playlist")
            return
        }
        let generated = generator.generateMaster(playlist1)
        let result2 = try parser.parse(generated)
        guard case .master(let playlist2) = result2 else {
            Issue.record("Expected master playlist after round-trip")
            return
        }

        #expect(playlist1.sessionKeys.count == playlist2.sessionKeys.count)
        #expect(playlist1.sessionKeys.first?.method == playlist2.sessionKeys.first?.method)
    }
}
