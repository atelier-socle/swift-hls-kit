// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - LL-HLS Parsing

@Suite("ManifestParser — Low-Latency HLS")
struct LLHLSParserTests {

    let parser = ManifestParser()

    @Test("Parse LL-HLS live playlist")
    func parseLLHLS() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:9
            #EXT-X-TARGETDURATION:4
            #EXT-X-SERVER-CONTROL:\
            CAN-BLOCK-RELOAD=YES,\
            CAN-SKIP-UNTIL=24.0,PART-HOLD-BACK=3.012
            #EXT-X-PART-INF:PART-TARGET=1.004

            #EXT-X-MEDIA-SEQUENCE:100
            #EXT-X-MAP:URI="init.mp4"

            #EXTINF:4.000,
            segment100.mp4
            #EXTINF:4.000,
            segment101.mp4
            #EXT-X-PART:DURATION=1.001,URI="segment102.0.mp4"
            #EXT-X-PART:DURATION=1.001,URI="segment102.1.mp4"
            #EXT-X-PART:DURATION=1.001,URI="segment102.2.mp4"
            #EXT-X-PART:DURATION=0.997,\
            URI="segment102.3.mp4",INDEPENDENT=YES
            #EXTINF:4.000,
            segment102.mp4

            #EXT-X-PART:DURATION=1.001,URI="segment103.0.mp4"
            #EXT-X-PART:DURATION=1.001,\
            URI="segment103.1.mp4",INDEPENDENT=YES
            #EXT-X-PRELOAD-HINT:\
            TYPE=PART,URI="segment103.2.mp4"

            #EXT-X-RENDITION-REPORT:\
            URI="../720p/playlist.m3u8",\
            LAST-MSN=103,LAST-PART=1
            #EXT-X-RENDITION-REPORT:\
            URI="../480p/playlist.m3u8",\
            LAST-MSN=103,LAST-PART=1
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.version == .v9)
        #expect(playlist.targetDuration == 4)
        #expect(playlist.mediaSequence == 100)
        #expect(playlist.segments.count == 3)
        #expect(playlist.partTargetDuration == 1.004)

        // Server control
        #expect(playlist.serverControl?.canBlockReload == true)
        #expect(playlist.serverControl?.canSkipUntil == 24.0)
        #expect(playlist.serverControl?.partHoldBack == 3.012)

        // Partial segments
        #expect(playlist.partialSegments.count == 6)
        #expect(playlist.partialSegments[3].independent == true)

        // Preload hint
        #expect(playlist.preloadHints.count == 1)
        #expect(playlist.preloadHints[0].type == .part)
        #expect(playlist.preloadHints[0].uri == "segment103.2.mp4")

        // Rendition reports
        #expect(playlist.renditionReports.count == 2)
        #expect(playlist.renditionReports[0].lastMediaSequence == 103)

        // MAP propagates to segments
        #expect(playlist.segments[0].map?.uri == "init.mp4")
    }
}

// MARK: - Common Parsing Behavior

@Suite("ManifestParser — Common Behavior")
struct ManifestParserCommonTests {

    let parser = ManifestParser()

    @Test("Comments and blank lines are ignored")
    func commentsAndBlankLines() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10

            # This is a comment
            #EXTINF:9.009,
            segment001.ts

            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.segments.count == 1)
    }

    @Test("Version detection — EXT-X-VERSION parsed correctly")
    func versionDetection() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-TARGETDURATION:10
            #EXTINF:9.009,
            segment001.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.version == .v7)
    }

    @Test("Parse media playlist with START tag")
    func parseWithStart() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-START:TIME-OFFSET=10.5
            #EXTINF:9.009,
            segment001.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.startOffset?.timeOffset == 10.5)
    }

    @Test("Parse media playlist with DEFINE variables")
    func parseWithDefine() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:10
            #EXT-X-DEFINE:NAME="path",VALUE="/video"
            #EXTINF:9.009,
            segment001.ts
            """
        let result = try parser.parse(m3u8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(playlist.definitions.count == 1)
    }
}

// MARK: - Real-World Playlists

@Suite("ManifestParser — Real-World Playlists")
struct RealWorldParserTests {

    let parser = ManifestParser()

    private static let vodM3U8 = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-TARGETDURATION:6
        #EXT-X-MEDIA-SEQUENCE:0
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-INDEPENDENT-SEGMENTS

        #EXT-X-MAP:URI="init.mp4"

        #EXT-X-KEY:METHOD=AES-128,\
        URI="https://example.com/key",\
        IV=0x00000000000000000000000000000001

        #EXT-X-PROGRAM-DATE-TIME:2026-02-18T10:00:00.000Z
        #EXTINF:6.006,Episode 1 - Opening
        segment0.ts
        #EXT-X-BYTERANGE:1024@0
        #EXTINF:5.839,
        segment1.ts
        #EXT-X-DISCONTINUITY
        #EXTINF:6.006,Episode 1 - Main Content
        segment2.ts
        #EXT-X-GAP
        #EXTINF:6.006,
        segment3.ts
        #EXT-X-BITRATE:1500
        #EXTINF:5.505,Episode 1 - Closing
        segment4.ts

        #EXT-X-DATERANGE:ID="ad-break",\
        START-DATE="2026-02-18T10:00:30.000Z",\
        DURATION=30.0,PLANNED-DURATION=30.0,\
        CLASS="com.example.ad",X-CUSTOM="value"

        #EXT-X-ENDLIST
        """

    @Test("Real-world VOD — metadata")
    func realWorldVODMetadata() throws {
        let result = try parser.parse(Self.vodM3U8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.version == .v7)
        #expect(playlist.targetDuration == 6)
        #expect(playlist.playlistType == .vod)
        #expect(playlist.hasEndList == true)
        #expect(playlist.independentSegments == true)
        #expect(playlist.segments.count == 5)
        #expect(playlist.segments[0].duration == 6.006)
        #expect(playlist.segments[0].title == "Episode 1 - Opening")
        #expect(playlist.segments[0].key?.method == .aes128)
        #expect(playlist.segments[0].map?.uri == "init.mp4")
        #expect(playlist.segments[0].programDateTime != nil)
    }

    @Test("Real-world VOD — segment features")
    func realWorldVODSegments() throws {
        let result = try parser.parse(Self.vodM3U8)
        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.segments[1].byteRange?.length == 1024)
        #expect(playlist.segments[1].byteRange?.offset == 0)
        #expect(playlist.segments[2].discontinuity == true)
        #expect(
            playlist.segments[2].title == "Episode 1 - Main Content"
        )
        #expect(playlist.segments[3].isGap == true)
        #expect(playlist.segments[4].bitrate == 1500)
        #expect(playlist.segments[4].title == "Episode 1 - Closing")
        #expect(playlist.dateRanges.count == 1)
        #expect(playlist.dateRanges[0].id == "ad-break")
        #expect(
            playlist.dateRanges[0].clientAttributes["X-CUSTOM"]
                == "value"
        )
    }

    @Test("Real-world Apple sample master playlist")
    func realWorldMaster() throws {
        let m3u8 = """
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

            #EXT-X-SESSION-DATA:\
            DATA-ID="com.example.title",\
            VALUE="My Great Show",LANGUAGE="en"

            #EXT-X-CONTENT-STEERING:\
            SERVER-URI="https://example.com/steering",\
            PATHWAY-ID="CDN-A"
            """
        let result = try parser.parse(m3u8)
        guard case .master(let playlist) = result else {
            Issue.record("Expected master playlist")
            return
        }

        #expect(playlist.variants.count == 3)
        #expect(playlist.renditions.count == 3)
        #expect(playlist.iFrameVariants.count == 1)
    }
}
