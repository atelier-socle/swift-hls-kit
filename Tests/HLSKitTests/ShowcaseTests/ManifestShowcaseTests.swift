// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Parsing

@Suite("Manifest Showcase — Parsing")
struct ManifestParsingShowcase {

    @Test("Parse master playlist — extract variants with bandwidth, resolution, codecs")
    func parseMasterPlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-INDEPENDENT-SEGMENTS
            #EXT-X-STREAM-INF:BANDWIDTH=800000,AVERAGE-BANDWIDTH=700000,\
            RESOLUTION=640x360,CODECS="avc1.4d401e,mp4a.40.2",FRAME-RATE=30.000
            360p/playlist.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=2800000,AVERAGE-BANDWIDTH=2500000,\
            RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2",FRAME-RATE=30.000
            720p/playlist.m3u8
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }
        #expect(playlist.variants.count == 2)
        #expect(playlist.variants[0].bandwidth == 800_000)
        #expect(playlist.variants[0].resolution == Resolution(width: 640, height: 360))
        #expect(playlist.variants[0].codecs == "avc1.4d401e,mp4a.40.2")
        #expect(playlist.variants[1].bandwidth == 2_800_000)
        #expect(playlist.variants[1].uri == "720p/playlist.m3u8")
    }

    @Test("Parse media playlist — extract segments with duration and URI")
    func parseMediaPlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-MEDIA-SEQUENCE:0
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:6.006,
            segment000.ts
            #EXTINF:5.839,
            segment001.ts
            #EXTINF:3.003,
            segment002.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .media(let playlist) = manifest else {
            Issue.record("Expected .media manifest")
            return
        }
        #expect(playlist.version == .v3)
        #expect(playlist.targetDuration == 6)
        #expect(playlist.playlistType == .vod)
        #expect(playlist.hasEndList == true)
        #expect(playlist.segments.count == 3)
        #expect(playlist.segments[0].duration == 6.006)
        #expect(playlist.segments[0].uri == "segment000.ts")
    }

    @Test("Parse media playlist with byte-range segments")
    func parseByteRangePlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:4
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            #EXT-X-BYTERANGE:1024@0
            main.ts
            #EXTINF:6.0,
            #EXT-X-BYTERANGE:1024@1024
            main.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .media(let playlist) = manifest else {
            Issue.record("Expected .media manifest")
            return
        }
        #expect(playlist.segments[0].byteRange?.length == 1024)
        #expect(playlist.segments[0].byteRange?.offset == 0)
        #expect(playlist.segments[1].byteRange?.offset == 1024)
    }

    @Test("Parse playlist with EXT-X-KEY encryption tags")
    func parseEncryptedPlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key",IV=0x00000000000000000000000000000001
            #EXTINF:6.0,
            segment000.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .media(let playlist) = manifest else {
            Issue.record("Expected .media manifest")
            return
        }
        let key = playlist.segments[0].key
        #expect(key?.method == .aes128)
        #expect(key?.uri == "https://example.com/key")
        #expect(key?.iv == "0x00000000000000000000000000000001")
    }

    @Test("Parse playlist with EXT-X-MAP init segment")
    func parseMapTag() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-TARGETDURATION:6
            #EXT-X-MAP:URI="init.mp4"
            #EXTINF:6.0,
            segment000.m4s
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .media(let playlist) = manifest else {
            Issue.record("Expected .media manifest")
            return
        }
        #expect(playlist.segments[0].map?.uri == "init.mp4")
    }

    @Test("Parse playlist with EXT-X-MEDIA audio renditions")
    func parseAudioRenditions() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="English",\
            LANGUAGE="en",DEFAULT=YES,AUTOSELECT=YES,URI="audio/en.m3u8"
            #EXT-X-STREAM-INF:BANDWIDTH=2800000,AUDIO="audio"
            video.m3u8
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }
        #expect(playlist.renditions.count == 1)
        #expect(playlist.renditions[0].type == .audio)
        #expect(playlist.renditions[0].language == "en")
        #expect(playlist.renditions[0].isDefault == true)
    }

    @Test("Parse I-Frame playlist (EXT-X-I-FRAMES-ONLY)")
    func parseIFramePlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:4
            #EXT-X-TARGETDURATION:6
            #EXT-X-I-FRAMES-ONLY
            #EXTINF:6.0,
            #EXT-X-BYTERANGE:1024@0
            main.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .media(let playlist) = manifest else {
            Issue.record("Expected .media manifest")
            return
        }
        #expect(playlist.iFramesOnly == true)
    }

    @Test("Parse live playlist (no EXT-X-ENDLIST)")
    func parseLivePlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-MEDIA-SEQUENCE:100
            #EXTINF:6.0,
            segment100.ts
            #EXTINF:6.0,
            segment101.ts
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .media(let playlist) = manifest else {
            Issue.record("Expected .media manifest")
            return
        }
        #expect(playlist.hasEndList == false)
        #expect(playlist.mediaSequence == 100)
    }

    @Test("Parse VOD playlist (EXT-X-PLAYLIST-TYPE:VOD)")
    func parseVODPlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:6.0,
            seg.ts
            #EXT-X-ENDLIST
            """
        let parser = ManifestParser()
        guard case .media(let p) = try parser.parse(m3u8) else {
            Issue.record("Expected .media")
            return
        }
        #expect(p.playlistType == .vod)
    }

    @Test("Parse event playlist (EXT-X-PLAYLIST-TYPE:EVENT)")
    func parseEventPlaylist() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:6.0,
            seg.ts
            """
        let parser = ManifestParser()
        guard case .media(let p) = try parser.parse(m3u8) else {
            Issue.record("Expected .media")
            return
        }
        #expect(p.playlistType == .event)
    }
}

// MARK: - Generation

@Suite("Manifest Showcase — Generation")
struct ManifestGenerationShowcase {

    @Test("Generate master playlist — M3U8 string with variants")
    func generateMaster() {
        let playlist = MasterPlaylist(
            version: .v7,
            variants: [
                Variant(
                    bandwidth: 800_000,
                    resolution: .p480,
                    uri: "480p/playlist.m3u8",
                    codecs: "avc1.4d401e,mp4a.40.2"
                ),
                Variant(
                    bandwidth: 2_800_000,
                    resolution: .p720,
                    uri: "720p/playlist.m3u8",
                    codecs: "avc1.4d401f,mp4a.40.2"
                )
            ],
            independentSegments: true
        )
        let output = ManifestGenerator().generateMaster(playlist)
        #expect(output.contains("#EXTM3U"))
        #expect(output.contains("#EXT-X-VERSION:7"))
        #expect(output.contains("BANDWIDTH=800000"))
        #expect(output.contains("BANDWIDTH=2800000"))
        #expect(output.contains("480p/playlist.m3u8"))
        #expect(output.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }

    @Test("Generate media playlist — segments with EXTINF and target duration")
    func generateMedia() {
        let playlist = MediaPlaylist(
            version: .v3,
            targetDuration: 6,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(duration: 6.006, uri: "segment000.ts"),
                Segment(duration: 5.839, uri: "segment001.ts")
            ]
        )
        let output = ManifestGenerator().generateMedia(playlist)
        #expect(output.contains("#EXT-X-TARGETDURATION:6"))
        #expect(output.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(output.contains("#EXTINF:6.006,"))
        #expect(output.contains("#EXTINF:5.839,"))
        #expect(output.contains("#EXT-X-ENDLIST"))
    }

    @Test("Generate byte-range playlist")
    func generateByteRange() {
        let playlist = MediaPlaylist(
            version: .v4,
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(
                    duration: 6.0, uri: "main.ts",
                    byteRange: ByteRange(length: 1024, offset: 0)
                ),
                Segment(
                    duration: 6.0, uri: "main.ts",
                    byteRange: ByteRange(length: 1024, offset: 1024)
                )
            ]
        )
        let output = ManifestGenerator().generateMedia(playlist)
        #expect(output.contains("#EXT-X-BYTERANGE:1024@0"))
        #expect(output.contains("#EXT-X-BYTERANGE:1024@1024"))
    }

    @Test("Generate encrypted playlist — EXT-X-KEY tags")
    func generateEncrypted() {
        let key = EncryptionKey(method: .aes128, uri: "https://example.com/key")
        let playlist = MediaPlaylist(
            targetDuration: 6,
            hasEndList: true,
            segments: [
                Segment(duration: 6.0, uri: "enc_seg0.ts", key: key)
            ]
        )
        let output = ManifestGenerator().generateMedia(playlist)
        #expect(output.contains("METHOD=AES-128"))
        #expect(output.contains("URI=\"https://example.com/key\""))
    }

    @Test("Generate playlist with alternate audio renditions")
    func generateWithRenditions() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 2_800_000, uri: "video.m3u8", audio: "audio-group")
            ],
            renditions: [
                Rendition(
                    type: .audio, groupId: "audio-group", name: "English",
                    uri: "audio/en.m3u8", language: "en", isDefault: true
                )
            ]
        )
        let output = ManifestGenerator().generateMaster(playlist)
        #expect(output.contains("TYPE=AUDIO"))
        #expect(output.contains("GROUP-ID=\"audio-group\""))
        #expect(output.contains("NAME=\"English\""))
        #expect(output.contains("LANGUAGE=\"en\""))
    }
}
