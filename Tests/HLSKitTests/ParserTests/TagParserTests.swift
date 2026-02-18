// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Media Segment Tag Tests

@Suite("TagParser — Media Segment Tags")
struct TagParserSegmentTests {

    let parser = TagParser()

    @Test("Parse EXTINF — integer duration")
    func extInfInteger() throws {
        let (duration, title) = try parser.parseExtInf("10,")
        #expect(duration == 10.0)
        #expect(title == nil)
    }

    @Test("Parse EXTINF — decimal duration")
    func extInfDecimal() throws {
        let (duration, title) = try parser.parseExtInf("6.006,")
        #expect(duration == 6.006)
        #expect(title == nil)
    }

    @Test("Parse EXTINF — duration with title")
    func extInfWithTitle() throws {
        let (duration, title) = try parser.parseExtInf(
            "9.009,Episode 1 - Opening"
        )
        #expect(duration == 9.009)
        #expect(title == "Episode 1 - Opening")
    }

    @Test("Parse EXTINF — duration without title or comma")
    func extInfNoComma() throws {
        let (duration, title) = try parser.parseExtInf("5.5")
        #expect(duration == 5.5)
        #expect(title == nil)
    }

    @Test("Parse EXT-X-BYTERANGE — length only")
    func byteRangeLengthOnly() throws {
        let range = try parser.parseByteRange("2048")
        #expect(range.length == 2048)
        #expect(range.offset == nil)
    }

    @Test("Parse EXT-X-BYTERANGE — length and offset")
    func byteRangeLengthAndOffset() throws {
        let range = try parser.parseByteRange("1024@512")
        #expect(range.length == 1024)
        #expect(range.offset == 512)
    }

    @Test("Parse EXT-X-KEY — AES-128 with URI and IV")
    func keyAES128() throws {
        let input =
            "METHOD=AES-128,"
            + "URI=\"https://example.com/key\","
            + "IV=0x00000000000000000000000000000001"
        let key = try parser.parseKey(input)
        #expect(key.method == .aes128)
        #expect(key.uri == "https://example.com/key")
        #expect(key.iv == "0x00000000000000000000000000000001")
    }

    @Test("Parse EXT-X-KEY — NONE method")
    func keyNone() throws {
        let key = try parser.parseKey("METHOD=NONE")
        #expect(key.method == EncryptionMethod.none)
        #expect(key.uri == nil)
    }

    @Test("Parse EXT-X-KEY — SAMPLE-AES")
    func keySampleAES() throws {
        let input =
            "METHOD=SAMPLE-AES,"
            + "URI=\"key.bin\",KEYFORMAT=\"identity\""
        let key = try parser.parseKey(input)
        #expect(key.method == .sampleAES)
        #expect(key.keyFormat == "identity")
    }

    @Test("Parse EXT-X-MAP — URI only")
    func mapURIOnly() throws {
        let map = try parser.parseMap("URI=\"init.mp4\"")
        #expect(map.uri == "init.mp4")
        #expect(map.byteRange == nil)
    }

    @Test("Parse EXT-X-MAP — URI with BYTERANGE")
    func mapWithByteRange() throws {
        let map = try parser.parseMap(
            "URI=\"init.mp4\",BYTERANGE=\"720@0\""
        )
        #expect(map.uri == "init.mp4")
        #expect(map.byteRange?.length == 720)
        #expect(map.byteRange?.offset == 0)
    }

    @Test("Parse EXT-X-PROGRAM-DATE-TIME — fractional seconds")
    func programDateTimeFractional() throws {
        let date = try parser.parseProgramDateTime(
            "2026-02-18T10:00:00.000Z"
        )
        #expect(date.timeIntervalSince1970 > 0)
    }

    @Test("Parse EXT-X-PROGRAM-DATE-TIME — without fractional")
    func programDateTimeNoFractional() throws {
        let date = try parser.parseProgramDateTime(
            "2026-02-18T10:00:00Z"
        )
        #expect(date.timeIntervalSince1970 > 0)
    }
}

// MARK: - Master Playlist Tag Tests

@Suite("TagParser — Master Playlist Tags")
struct TagParserMasterTests {

    let parser = TagParser()

    @Test("Parse EXT-X-STREAM-INF — minimal (bandwidth only)")
    func streamInfMinimal() throws {
        let variant = try parser.parseStreamInf("BANDWIDTH=800000")
        #expect(variant.bandwidth == 800_000)
        #expect(variant.resolution == nil)
        #expect(variant.codecs == nil)
    }

    @Test("Parse EXT-X-STREAM-INF — full attributes")
    func streamInfFull() throws {
        let input =
            "BANDWIDTH=2800000,"
            + "AVERAGE-BANDWIDTH=2200000,"
            + "RESOLUTION=1280x720,FRAME-RATE=30.000,"
            + "CODECS=\"avc1.4d401f,mp4a.40.2\","
            + "AUDIO=\"audio-aac\",SUBTITLES=\"subs\","
            + "HDCP-LEVEL=TYPE-0"
        let variant = try parser.parseStreamInf(input)
        #expect(variant.bandwidth == 2_800_000)
        #expect(variant.averageBandwidth == 2_200_000)
        #expect(variant.resolution == .p720)
        #expect(variant.frameRate == 30.0)
        #expect(variant.codecs == "avc1.4d401f,mp4a.40.2")
        #expect(variant.audio == "audio-aac")
        #expect(variant.subtitles == "subs")
        #expect(variant.hdcpLevel == .type0)
    }

    @Test("Parse EXT-X-I-FRAME-STREAM-INF")
    func iFrameStreamInf() throws {
        let input =
            "BANDWIDTH=200000,"
            + "RESOLUTION=640x480,"
            + "CODECS=\"avc1.4d401e\","
            + "URI=\"480p/iframe.m3u8\""
        let variant = try parser.parseIFrameStreamInf(input)
        #expect(variant.bandwidth == 200_000)
        #expect(variant.resolution == Resolution(width: 640, height: 480))
        #expect(variant.codecs == "avc1.4d401e")
        #expect(variant.uri == "480p/iframe.m3u8")
    }

    @Test("Parse EXT-X-MEDIA — audio rendition")
    func mediaAudio() throws {
        let input =
            "TYPE=AUDIO,GROUP-ID=\"audio-aac\","
            + "NAME=\"English\",DEFAULT=YES,AUTOSELECT=YES,"
            + "LANGUAGE=\"en\",URI=\"audio/en/playlist.m3u8\""
        let rendition = try parser.parseMedia(input)
        #expect(rendition.type == .audio)
        #expect(rendition.groupId == "audio-aac")
        #expect(rendition.name == "English")
        #expect(rendition.isDefault == true)
        #expect(rendition.autoselect == true)
        #expect(rendition.language == "en")
        #expect(rendition.uri == "audio/en/playlist.m3u8")
    }

    @Test("Parse EXT-X-MEDIA — subtitle rendition")
    func mediaSubtitles() throws {
        let input =
            "TYPE=SUBTITLES,GROUP-ID=\"subs\","
            + "NAME=\"English\",DEFAULT=YES,AUTOSELECT=YES,"
            + "FORCED=NO,LANGUAGE=\"en\","
            + "URI=\"subs/en/playlist.m3u8\""
        let rendition = try parser.parseMedia(input)
        #expect(rendition.type == .subtitles)
        #expect(rendition.forced == false)
    }

    @Test("Parse EXT-X-MEDIA — closed-captions rendition")
    func mediaClosedCaptions() throws {
        let input =
            "TYPE=CLOSED-CAPTIONS,GROUP-ID=\"cc\","
            + "NAME=\"CC\",INSTREAM-ID=\"CC1\",DEFAULT=YES"
        let rendition = try parser.parseMedia(input)
        #expect(rendition.type == .closedCaptions)
        #expect(rendition.instreamId == "CC1")
        #expect(rendition.uri == nil)
    }

    @Test("Parse EXT-X-SESSION-DATA — with VALUE")
    func sessionDataValue() throws {
        let input =
            "DATA-ID=\"com.example.title\","
            + "VALUE=\"My Great Show\",LANGUAGE=\"en\""
        let data = try parser.parseSessionData(input)
        #expect(data.dataId == "com.example.title")
        #expect(data.value == "My Great Show")
        #expect(data.language == "en")
        #expect(data.uri == nil)
    }

    @Test("Parse EXT-X-SESSION-DATA — with URI")
    func sessionDataURI() throws {
        let input =
            "DATA-ID=\"com.example.metadata\","
            + "URI=\"metadata.json\""
        let data = try parser.parseSessionData(input)
        #expect(data.dataId == "com.example.metadata")
        #expect(data.uri == "metadata.json")
        #expect(data.value == nil)
    }

    @Test("Parse EXT-X-CONTENT-STEERING")
    func contentSteering() throws {
        let input =
            "SERVER-URI=\"https://example.com/steering\","
            + "PATHWAY-ID=\"CDN-A\""
        let steering = try parser.parseContentSteering(input)
        #expect(steering.serverUri == "https://example.com/steering")
        #expect(steering.pathwayId == "CDN-A")
    }
}

// MARK: - Date Range Tests

@Suite("TagParser — DateRange")
struct TagParserDateRangeTests {

    let parser = TagParser()

    @Test("Parse EXT-X-DATERANGE with duration and custom attributes")
    func dateRangeWithCustom() throws {
        let input =
            "ID=\"ad-break\","
            + "START-DATE=\"2026-02-18T10:00:30.000Z\","
            + "DURATION=30.0,PLANNED-DURATION=30.0,"
            + "CLASS=\"com.example.ad\",X-CUSTOM=\"value\""
        let range = try parser.parseDateRange(input)
        #expect(range.id == "ad-break")
        #expect(range.duration == 30.0)
        #expect(range.plannedDuration == 30.0)
        #expect(range.classAttribute == "com.example.ad")
        #expect(range.clientAttributes["X-CUSTOM"] == "value")
    }
}

// MARK: - Common Tag Tests

@Suite("TagParser — Common Tags")
struct TagParserCommonTests {

    let parser = TagParser()

    @Test("Parse EXT-X-START — time offset with precise")
    func startWithPrecise() throws {
        let start = try parser.parseStart(
            "TIME-OFFSET=25.0,PRECISE=YES"
        )
        #expect(start.timeOffset == 25.0)
        #expect(start.precise == true)
    }

    @Test("Parse EXT-X-START — time offset without precise")
    func startWithoutPrecise() throws {
        let start = try parser.parseStart("TIME-OFFSET=-10.5")
        #expect(start.timeOffset == -10.5)
        #expect(start.precise == false)
    }

    @Test("Parse EXT-X-DEFINE — NAME/VALUE pair")
    func defineNameValue() throws {
        let def = try parser.parseDefine(
            "NAME=\"base-url\",VALUE=\"https://cdn.example.com\""
        )
        #expect(def?.name == "base-url")
        #expect(def?.value == "https://cdn.example.com")
    }

    @Test("Parse EXT-X-DEFINE — IMPORT returns nil")
    func defineImport() throws {
        let def = try parser.parseDefine("IMPORT=\"base-url\"")
        #expect(def == nil)
    }
}

// MARK: - LL-HLS Tag Tests

@Suite("TagParser — Low-Latency HLS")
struct TagParserLLHLSTests {

    let parser = TagParser()

    @Test("Parse EXT-X-PART")
    func parsePart() throws {
        let part = try parser.parsePart(
            "DURATION=1.001,URI=\"segment102.0.mp4\""
        )
        #expect(part.duration == 1.001)
        #expect(part.uri == "segment102.0.mp4")
        #expect(part.independent == false)
    }

    @Test("Parse EXT-X-PART with INDEPENDENT=YES")
    func parsePartIndependent() throws {
        let part = try parser.parsePart(
            "DURATION=0.997,URI=\"segment102.3.mp4\",INDEPENDENT=YES"
        )
        #expect(part.independent == true)
    }

    @Test("Parse EXT-X-PART-INF")
    func parsePartInf() throws {
        let target = try parser.parsePartInf("PART-TARGET=1.004")
        #expect(target == 1.004)
    }

    @Test("Parse EXT-X-SERVER-CONTROL")
    func parseServerControl() {
        let input =
            "CAN-BLOCK-RELOAD=YES,"
            + "CAN-SKIP-UNTIL=24.0,PART-HOLD-BACK=3.012"
        let control = parser.parseServerControl(input)
        #expect(control.canBlockReload == true)
        #expect(control.canSkipUntil == 24.0)
        #expect(control.partHoldBack == 3.012)
    }

    @Test("Parse EXT-X-PRELOAD-HINT")
    func parsePreloadHint() throws {
        let hint = try parser.parsePreloadHint(
            "TYPE=PART,URI=\"segment103.2.mp4\""
        )
        #expect(hint.type == .part)
        #expect(hint.uri == "segment103.2.mp4")
    }

    @Test("Parse EXT-X-RENDITION-REPORT")
    func parseRenditionReport() throws {
        let report = try parser.parseRenditionReport(
            "URI=\"../720p/playlist.m3u8\",LAST-MSN=103,LAST-PART=1"
        )
        #expect(report.uri == "../720p/playlist.m3u8")
        #expect(report.lastMediaSequence == 103)
        #expect(report.lastPartIndex == 1)
    }

    @Test("Parse EXT-X-SKIP")
    func parseSkip() throws {
        let skip = try parser.parseSkip("SKIPPED-SEGMENTS=10")
        #expect(skip.skippedSegments == 10)
        #expect(skip.recentlyRemovedDateRanges.isEmpty)
    }
}
