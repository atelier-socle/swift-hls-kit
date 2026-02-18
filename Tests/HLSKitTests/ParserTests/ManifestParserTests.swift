// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Master Playlist Parsing

@Suite("ManifestParser — Master Playlist")
struct MasterPlaylistParserTests {

    let parser = ManifestParser()

    @Test("Parse minimal master playlist with single variant")
    func parseMinimalMaster() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8
            """
        let result = try parser.parse(m3u8)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(playlist.variants.count == 1)
        #expect(playlist.variants[0].bandwidth == 800_000)
        #expect(playlist.variants[0].uri == "480p/playlist.m3u8")
    }

    private static let fullMasterM3U8 = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-INDEPENDENT-SEGMENTS

        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-aac",\
        NAME="English",DEFAULT=YES,AUTOSELECT=YES,\
        LANGUAGE="en",URI="audio/en/playlist.m3u8"
        #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio-aac",\
        NAME="Français",DEFAULT=NO,AUTOSELECT=YES,\
        LANGUAGE="fr",URI="audio/fr/playlist.m3u8"

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
        #EXT-X-STREAM-INF:BANDWIDTH=5000000,\
        AVERAGE-BANDWIDTH=4000000,\
        RESOLUTION=1920x1080,FRAME-RATE=30.000,\
        CODECS="avc1.640028,mp4a.40.2",\
        AUDIO="audio-aac",SUBTITLES="subs",\
        HDCP-LEVEL=TYPE-1
        1080p/playlist.m3u8

        #EXT-X-I-FRAME-STREAM-INF:BANDWIDTH=200000,\
        RESOLUTION=640x480,CODECS="avc1.4d401e",\
        URI="480p/iframe.m3u8"

        #EXT-X-SESSION-DATA:DATA-ID="com.example.title",\
        VALUE="My Great Show",LANGUAGE="en"

        #EXT-X-CONTENT-STEERING:\
        SERVER-URI="https://example.com/steering",\
        PATHWAY-ID="CDN-A"
        """

    @Test("Parse full master playlist — counts")
    func parseFullMasterCounts() throws {
        let result = try parser.parse(Self.fullMasterM3U8)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }

        #expect(playlist.version == .v7)
        #expect(playlist.independentSegments == true)
        #expect(playlist.variants.count == 3)
        #expect(playlist.renditions.count == 3)
        #expect(playlist.iFrameVariants.count == 1)
        #expect(playlist.sessionData.count == 1)
        #expect(
            playlist.contentSteering?.serverUri
                == "https://example.com/steering"
        )
        #expect(playlist.contentSteering?.pathwayId == "CDN-A")
    }

    @Test("Parse full master playlist — details")
    func parseFullMasterDetails() throws {
        let result = try parser.parse(Self.fullMasterM3U8)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }

        #expect(playlist.variants[0].bandwidth == 800_000)
        #expect(
            playlist.variants[0].resolution
                == Resolution(width: 640, height: 480)
        )
        #expect(playlist.variants[0].codecs == "avc1.4d401e,mp4a.40.2")
        #expect(playlist.variants[0].audio == "audio-aac")

        #expect(playlist.variants[1].bandwidth == 2_800_000)
        #expect(playlist.variants[1].hdcpLevel == .type0)

        #expect(playlist.variants[2].bandwidth == 5_000_000)
        #expect(playlist.variants[2].resolution == .p1080)

        let audioEn = playlist.renditions.first {
            $0.language == "en" && $0.type == .audio
        }
        #expect(audioEn?.name == "English")
        #expect(audioEn?.isDefault == true)

        #expect(playlist.iFrameVariants[0].bandwidth == 200_000)
        #expect(playlist.iFrameVariants[0].uri == "480p/iframe.m3u8")

        #expect(playlist.sessionData[0].dataId == "com.example.title")
        #expect(playlist.sessionData[0].value == "My Great Show")
    }

    @Test("Parse master playlist with DEFINE variables")
    func parseWithDefine() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-DEFINE:NAME="base",\
            VALUE="https://cdn.example.com"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            480p/playlist.m3u8
            """
        let result = try parser.parse(m3u8)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(playlist.definitions.count == 1)
        #expect(playlist.definitions[0].name == "base")
        #expect(
            playlist.definitions[0].value == "https://cdn.example.com"
        )
    }

    @Test("Parse master playlist with START tag")
    func parseWithStart() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-START:TIME-OFFSET=25.0,PRECISE=YES
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            video.m3u8
            """
        let result = try parser.parse(m3u8)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }
        #expect(playlist.startOffset?.timeOffset == 25.0)
        #expect(playlist.startOffset?.precise == true)
    }
}

// MARK: - Media Playlist Parsing

@Suite("ManifestParser — Media Playlist")
struct MediaPlaylistParserTests {

    let parser = ManifestParser()

    @Test("Parse minimal media playlist")
    func parseMinimalMedia() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.targetDuration == 10)
        #expect(playlist.segments.count == 1)
        #expect(playlist.segments[0].duration == 9.009)
        #expect(playlist.segments[0].uri == "segment001.ts")
    }

    @Test("Parse VOD media playlist with ENDLIST")
    func parseVOD() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:3
            #EXT-X-TARGETDURATION:10
            #EXT-X-PLAYLIST-TYPE:VOD
            #EXTINF:9.009,
            segment001.ts
            #EXTINF:9.009,
            segment002.ts
            #EXT-X-ENDLIST
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.version == .v3)
        #expect(playlist.playlistType == .vod)
        #expect(playlist.hasEndList == true)
        #expect(playlist.segments.count == 2)
    }

    @Test("Parse EVENT media playlist")
    func parseEvent() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:9.009,
            segment001.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.playlistType == .event)
    }

    @Test("Parse media playlist with encryption")
    func parseWithEncryption() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-KEY:METHOD=AES-128,\
            URI="https://example.com/key",IV=0x00000001
            #EXTINF:9.009,
            segment001.ts
            #EXTINF:9.009,
            segment002.ts
            #EXT-X-KEY:METHOD=NONE
            #EXTINF:9.009,
            segment003.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments[0].key?.method == .aes128)
        #expect(playlist.segments[0].key?.uri == "https://example.com/key")
        #expect(playlist.segments[1].key?.method == .aes128)
        #expect(playlist.segments[2].key?.method == EncryptionMethod.none)
    }

    @Test("Parse media playlist with MAP")
    func parseWithMap() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-MAP:URI="init.mp4"
            #EXTINF:6.006,
            segment001.mp4
            #EXTINF:5.839,
            segment002.mp4
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments[0].map?.uri == "init.mp4")
        #expect(playlist.segments[1].map?.uri == "init.mp4")
    }

    @Test("Parse media playlist with BYTERANGE")
    func parseWithByteRange() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-BYTERANGE:1024@0
            #EXTINF:9.009,
            bigfile.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments[0].byteRange?.length == 1024)
        #expect(playlist.segments[0].byteRange?.offset == 0)
    }

    @Test("Parse media playlist with DISCONTINUITY")
    func parseWithDiscontinuity() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            #EXT-X-DISCONTINUITY
            #EXTINF:9.009,
            segment002.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments[0].discontinuity == false)
        #expect(playlist.segments[1].discontinuity == true)
    }

    @Test("Parse media playlist with GAP")
    func parseWithGap() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-GAP
            #EXTINF:9.009,
            segment001.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments[0].isGap == true)
    }

    @Test("Parse media playlist with PROGRAM-DATE-TIME")
    func parseWithProgramDateTime() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-PROGRAM-DATE-TIME:2026-02-18T10:00:00.000Z
            #EXTINF:9.009,
            segment001.ts
            #EXTINF:9.009,
            segment002.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments[0].programDateTime != nil)
        #expect(playlist.segments[1].programDateTime == nil)
    }

    @Test("Parse media playlist with DATERANGE")
    func parseWithDateRange() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            #EXT-X-DATERANGE:ID="ad-break",\
            START-DATE="2026-02-18T10:00:30.000Z",\
            DURATION=30.0
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.dateRanges.count == 1)
        #expect(playlist.dateRanges[0].id == "ad-break")
        #expect(playlist.dateRanges[0].duration == 30.0)
    }

    @Test("Parse media playlist with BITRATE")
    func parseWithBitrate() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-BITRATE:1500
            #EXTINF:9.009,
            segment001.ts
            #EXTINF:9.009,
            segment002.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments[0].bitrate == 1500)
        #expect(playlist.segments[1].bitrate == 1500)
    }

    @Test("Parse media playlist with INDEPENDENT-SEGMENTS")
    func parseWithIndependentSegments() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-INDEPENDENT-SEGMENTS
            #EXTINF:9.009,
            segment001.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.independentSegments == true)
    }

    @Test("Parse media playlist with media sequence")
    func parseWithMediaSequence() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-MEDIA-SEQUENCE:100
            #EXTINF:9.009,
            segment100.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.mediaSequence == 100)
    }
}

// MARK: - Error Handling

@Suite("ManifestParser — Error Handling")
struct ManifestParserErrorTests {

    let parser = ManifestParser()

    @Test("Error — empty string throws emptyManifest")
    func emptyString() {
        #expect(throws: ParserError.emptyManifest) {
            try parser.parse("")
        }
    }

    @Test("Error — whitespace-only string throws emptyManifest")
    func whitespaceOnly() {
        #expect(throws: ParserError.emptyManifest) {
            try parser.parse("   \n  \n  ")
        }
    }

    @Test("Error — missing EXTM3U throws missingHeader")
    func missingHeader() {
        #expect(throws: ParserError.missingHeader) {
            try parser.parse("not a playlist")
        }
    }

    @Test("Error — ambiguous playlist type")
    func ambiguousType() {
        #expect(throws: ParserError.ambiguousPlaylistType) {
            try parser.parse("#EXTM3U\n#EXT-X-VERSION:7")
        }
    }

    @Test("Error — missing TARGETDURATION in media playlist")
    func missingTargetDuration() {
        #expect(throws: ParserError.self) {
            try parser.parse(
                """
                #EXTM3U
                #EXTINF:9.009,
                segment.ts
                """
            )
        }
    }

    @Test("Error — invalid EXTINF duration")
    func invalidDuration() {
        #expect(throws: ParserError.self) {
            try parser.parse(
                """
                #EXTM3U
                #EXT-X-TARGETDURATION:10
                #EXTINF:abc,
                segment.ts
                """
            )
        }
    }

    @Test("Error — missing URI after STREAM-INF")
    func missingURIAfterStreamInf() {
        #expect(throws: ParserError.self) {
            try parser.parse(
                """
                #EXTM3U
                #EXT-X-STREAM-INF:BANDWIDTH=800000
                """
            )
        }
    }

    @Test("Error — invalid version")
    func invalidVersion() {
        #expect(throws: ParserError.self) {
            try parser.parse(
                """
                #EXTM3U
                #EXT-X-VERSION:99
                #EXT-X-STREAM-INF:BANDWIDTH=800000
                video.m3u8
                """
            )
        }
    }
}
