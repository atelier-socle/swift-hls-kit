// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EncryptedPlaylistBuilder")
struct EncryptedPlaylistBuilderTests {

    private let builder = EncryptedPlaylistBuilder()

    // MARK: - Key Tag Injection

    @Test("Adds EXT-X-KEY tag to playlist")
    func addsKeyTag() throws {
        let playlist = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            segment_0.ts
            #EXT-X-ENDLIST
            """

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        let result = builder.addEncryptionTags(
            to: playlist, config: config, segmentCount: 1
        )

        #expect(result.contains("#EXT-X-KEY:"))
        #expect(result.contains("METHOD=AES-128"))
        #expect(result.contains("example.com/key.bin"))
    }

    @Test("Key tag has correct METHOD and URI")
    func keyTagAttributes() throws {
        let url = try #require(
            URL(string: "https://cdn.example.com/keys/v1.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        let tag = builder.buildKeyTag(config: config, iv: nil)

        #expect(tag.hasPrefix("#EXT-X-KEY:"))
        #expect(tag.contains("METHOD=AES-128"))
        #expect(
            tag.contains(
                "URI=\"https://cdn.example.com/keys/v1.bin\""
            )
        )
    }

    @Test("Explicit IV included in key tag")
    func explicitIV() throws {
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let iv = Data([
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01
        ])
        let config = EncryptionConfig(keyURL: url, iv: iv)
        let tag = builder.buildKeyTag(config: config, iv: iv)

        #expect(
            tag.contains(
                "IV=0x00000000000000000000000000000001"
            )
        )
    }

    @Test("No IV in key tag when using derived IV")
    func derivedIV() throws {
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        let tag = builder.buildKeyTag(config: config, iv: nil)

        #expect(!tag.contains("IV="))
    }

    @Test("KEYFORMAT attribute included when specified")
    func keyFormat() throws {
        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url,
            keyFormat: "com.apple.streamingkeydelivery",
            keyFormatVersions: "1"
        )
        let tag = builder.buildKeyTag(config: config, iv: nil)

        #expect(
            tag.contains(
                "KEYFORMAT=\"com.apple.streamingkeydelivery\""
            )
        )
        #expect(tag.contains("KEYFORMATVERSIONS=\"1\""))
    }

    // MARK: - Key Rotation

    @Test("Key rotation: multiple EXT-X-KEY at intervals")
    func keyRotation() throws {
        let playlist = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            segment_0.ts
            #EXTINF:6.0,
            segment_1.ts
            #EXTINF:6.0,
            segment_2.ts
            #EXTINF:6.0,
            segment_3.ts
            #EXT-X-ENDLIST
            """

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(
            keyURL: url, keyRotationInterval: 2
        )
        let result = builder.addEncryptionTags(
            to: playlist, config: config, segmentCount: 4
        )

        let keyCount =
            result.components(
                separatedBy: "#EXT-X-KEY:"
            ).count - 1
        // First tag at segment 0, rotation at segment 2
        #expect(keyCount == 2)
    }

    @Test("No rotation when interval is nil")
    func noRotation() throws {
        let playlist = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            segment_0.ts
            #EXTINF:6.0,
            segment_1.ts
            #EXTINF:6.0,
            segment_2.ts
            #EXT-X-ENDLIST
            """

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        let result = builder.addEncryptionTags(
            to: playlist, config: config, segmentCount: 3
        )

        let keyCount =
            result.components(
                separatedBy: "#EXT-X-KEY:"
            ).count - 1
        #expect(keyCount == 1)
    }

    // MARK: - Playlist Validity

    @Test("Encrypted playlist parseable by ManifestParser")
    func parseablePlaylist() throws {
        let playlist = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:6.0,
            segment_0.ts
            #EXTINF:6.0,
            segment_1.ts
            #EXT-X-ENDLIST
            """

        let url = try #require(
            URL(string: "https://example.com/key.bin")
        )
        let config = EncryptionConfig(keyURL: url)
        let result = builder.addEncryptionTags(
            to: playlist, config: config, segmentCount: 2
        )

        let parser = ManifestParser()
        let manifest = try parser.parse(result)

        if case .media(let media) = manifest {
            #expect(media.segments.count == 2)
        } else {
            Issue.record("Expected media playlist")
        }
    }
}
