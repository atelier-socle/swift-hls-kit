// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Round-Trip Helpers

private let parser = ManifestParser()
private let generator = ManifestGenerator()

private func assertRoundTrip(
    _ m3u8: String,
    sourceLocation: SourceLocation = #_sourceLocation
) throws {
    let parsed1 = try parser.parse(m3u8)
    let generated: String
    switch parsed1 {
    case .master(let playlist):
        generated = generator.generateMaster(playlist)
    case .media(let playlist):
        generated = generator.generateMedia(playlist)
    }
    let parsed2 = try parser.parse(generated)
    switch (parsed1, parsed2) {
    case (.master(let p1), .master(let p2)):
        #expect(
            p1 == p2,
            "Master playlists differ after round-trip",
            sourceLocation: sourceLocation
        )
    case (.media(let p1), .media(let p2)):
        #expect(
            p1 == p2,
            "Media playlists differ after round-trip",
            sourceLocation: sourceLocation
        )
    default:
        Issue.record(
            "Playlist type changed after round-trip",
            sourceLocation: sourceLocation
        )
    }
}

// MARK: - Master Playlist Round-Trips

@Suite("RoundTrip — Master Playlist")
struct MasterRoundTripTests {

    @Test("Minimal master — one variant")
    func minimalMaster() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8
            """
        try assertRoundTrip(m3u8)
    }

    private static let fullMasterM3U8 = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-INDEPENDENT-SEGMENTS

        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-aac",\
        NAME="English",DEFAULT=YES,AUTOSELECT=YES,\
        LANGUAGE="en",URI="audio/en/playlist.m3u8"
        #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",\
        NAME="English",DEFAULT=YES,AUTOSELECT=YES,\
        FORCED=NO,LANGUAGE="en",\
        URI="subs/en/playlist.m3u8"

        #EXT-X-STREAM-INF:BANDWIDTH=800000,\
        AVERAGE-BANDWIDTH=600000,RESOLUTION=640x480,\
        FRAME-RATE=30.000,\
        CODECS="avc1.4d401e,mp4a.40.2",\
        AUDIO="audio-aac",SUBTITLES="subs"
        480p/playlist.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=2800000,\
        AVERAGE-BANDWIDTH=2200000,\
        RESOLUTION=1280x720,FRAME-RATE=30.000,\
        CODECS="avc1.4d401f,mp4a.40.2",\
        AUDIO="audio-aac",SUBTITLES="subs",\
        HDCP-LEVEL=TYPE-0
        720p/playlist.m3u8
        """

    @Test("Full master with renditions and HDCP")
    func fullMaster() throws {
        try assertRoundTrip(Self.fullMasterM3U8)
    }

    @Test("Master with I-frame variants")
    func masterIFrame() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8

            #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=200000,\
            RESOLUTION=640x480,\
            CODECS="avc1.4d401e",URI="480p/iframe.m3u8"
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Master with session data")
    func masterSessionData() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8

            #EXT-X-SESSION-DATA:\
            DATA-ID="com.example.title",\
            VALUE="My Show",LANGUAGE="en"
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Master with START tag")
    func masterStart() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-START:TIME-OFFSET=25.0,PRECISE=YES
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Master with DEFINE variables")
    func masterDefine() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:8
            #EXT-X-DEFINE:NAME="path",VALUE="/video"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Master with CONTENT-STEERING")
    func masterSteering() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:10
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8

            #EXT-X-CONTENT-STEERING:\
            SERVER-URI="https://example.com/steering",\
            PATHWAY-ID="CDN-A"
            """
        try assertRoundTrip(m3u8)
    }
}

// MARK: - Media Playlist Round-Trips

@Suite("RoundTrip — Media Playlist")
struct MediaRoundTripTests {

    @Test("Minimal VOD")
    func minimalVOD() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:10
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:9.009,
            segment001.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with encryption")
    func mediaEncryption() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-KEY:METHOD=AES-128,\
            URI="https://example.com/key",\
            IV=0x00000000000000000000000000000001
            #EXTINF:6.006,
            segment0.ts
            #EXTINF:6.006,
            segment1.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with MAP")
    func mediaMap() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:6
            #EXT-X-TARGETDURATION:6
            #EXT-X-MAP:URI="init.mp4"
            #EXTINF:6.006,
            segment0.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with byte-range segments")
    func mediaByteRange() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:4
            #EXT-X-TARGETDURATION:6
            #EXT-X-BYTERANGE:1024@0
            #EXTINF:6.006,
            segment0.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with discontinuity")
    func mediaDiscontinuity() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.006,
            segment0.ts
            #EXT-X-DISCONTINUITY
            #EXTINF:6.006,
            segment1.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with GAP")
    func mediaGap() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-GAP
            #EXTINF:6.006,
            segment0.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with PROGRAM-DATE-TIME")
    func mediaProgramDateTime() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-PROGRAM-DATE-TIME:\
            2026-02-18T10:00:00.000Z
            #EXTINF:6.006,
            segment0.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media EVENT type — no ENDLIST")
    func mediaEvent() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:6.006,
            segment0.ts
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with EXTINF title")
    func mediaWithTitle() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.006,Episode 1 - Opening
            segment0.ts
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }

    @Test("Media with DATERANGE")
    func mediaDateRange() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.006,
            segment0.ts
            #EXT-X-DATERANGE:ID="ad-break",\
            START-DATE="2026-02-18T10:00:30.000Z",\
            DURATION=30.0,PLANNED-DURATION=30.0,\
            CLASS="com.example.ad",X-CUSTOM="value"
            #EXT-X-ENDLIST
            """
        try assertRoundTrip(m3u8)
    }
}

// MARK: - LL-HLS Round-Trip

@Suite("RoundTrip — LL-HLS")
struct LLHLSRoundTripTests {

    private static let llhlsM3U8 = """
        #EXTM3U
        #EXT-X-VERSION:9
        #EXT-X-TARGETDURATION:4
        #EXT-X-SERVER-CONTROL:\
        CAN-BLOCK-RELOAD=YES,\
        CAN-SKIP-UNTIL=24.0,PART-HOLD-BACK=3.012
        #EXT-X-PART-INF:PART-TARGET=1.004

        #EXT-X-MEDIA-SEQUENCE:100
        #EXT-X-MAP:URI="init.mp4"

        #EXTINF:4.0,
        segment100.mp4
        #EXTINF:4.0,
        segment101.mp4
        #EXT-X-PART:DURATION=1.001,URI="segment102.0.mp4"
        #EXT-X-PART:DURATION=1.001,URI="segment102.1.mp4"
        #EXT-X-PART:DURATION=0.997,\
        URI="segment102.3.mp4",INDEPENDENT=YES
        #EXT-X-PRELOAD-HINT:\
        TYPE=PART,URI="segment103.2.mp4"

        #EXT-X-RENDITION-REPORT:\
        URI="../720p/playlist.m3u8",\
        LAST-MSN=103,LAST-PART=1
        """

    @Test("LL-HLS live playlist round-trip")
    func llhlsRoundTrip() throws {
        try assertRoundTrip(Self.llhlsM3U8)
    }
}

// MARK: - Deduplication Round-Trip

@Suite("RoundTrip — Deduplication")
struct DeduplicationRoundTripTests {

    @Test("KEY deduplication — 3 segments same key")
    func keyDeduplication() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-KEY:METHOD=AES-128,\
            URI="https://example.com/key"
            #EXTINF:6.006,
            seg0.ts
            #EXTINF:6.006,
            seg1.ts
            #EXTINF:6.006,
            seg2.ts
            #EXT-X-ENDLIST
            """
        let parsed1 = try parser.parse(m3u8)
        guard case .media(let playlist) = parsed1 else {
            Issue.record("Expected media playlist")
            return
        }
        let generated = generator.generateMedia(playlist)
        let keyCount =
            generated.components(
                separatedBy: "#EXT-X-KEY:"
            ).count - 1
        #expect(keyCount == 1)
        try assertRoundTrip(m3u8)
    }

    @Test("Duration precision — 6.006 preserved")
    func durationPrecision() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:7
            #EXTINF:6.006,
            segment.ts
            #EXT-X-ENDLIST
            """
        let parsed = try parser.parse(m3u8)
        guard case .media(let playlist) = parsed else {
            Issue.record("Expected media playlist")
            return
        }
        let generated = generator.generateMedia(playlist)
        #expect(generated.contains("#EXTINF:6.006,"))
    }

    @Test("Hexadecimal IV preserved")
    func hexIVPreserved() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:6
            #EXT-X-KEY:METHOD=AES-128,\
            URI="https://example.com/key",\
            IV=0x00000000000000000000000000000001
            #EXTINF:6.006,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let parsed = try parser.parse(m3u8)
        guard case .media(let playlist) = parsed else {
            Issue.record("Expected media playlist")
            return
        }
        let generated = generator.generateMedia(playlist)
        #expect(
            generated.contains(
                "IV=0x00000000000000000000000000000001"
            )
        )
    }

    @Test("Quoted strings with commas preserved")
    func quotedCommasPreserved() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=2800000,\
            CODECS="avc1.4d401f,mp4a.40.2"
            720p/playlist.m3u8
            """
        let parsed = try parser.parse(m3u8)
        guard case .master(let playlist) = parsed else {
            Issue.record("Expected master playlist")
            return
        }
        let generated = generator.generateMaster(playlist)
        #expect(
            generated.contains(
                "CODECS=\"avc1.4d401f,mp4a.40.2\""
            )
        )
    }
}
