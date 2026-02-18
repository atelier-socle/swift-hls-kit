// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - EXTINF Tests

@Suite("TagWriter — EXTINF")
struct TagWriterExtInfTests {

    let writer = TagWriter()

    @Test("EXTINF — integer duration v2")
    func extInfIntegerV2() {
        let result = writer.writeExtInf(
            duration: 10.0, title: nil, version: .v2
        )
        #expect(result == "#EXTINF:10,")
    }

    @Test("EXTINF — decimal duration v3")
    func extInfDecimalV3() {
        let result = writer.writeExtInf(
            duration: 6.006, title: nil, version: .v3
        )
        #expect(result == "#EXTINF:6.006,")
    }

    @Test("EXTINF — with title")
    func extInfWithTitle() {
        let result = writer.writeExtInf(
            duration: 9.009, title: "Episode 1 - Opening", version: .v3
        )
        #expect(result == "#EXTINF:9.009,Episode 1 - Opening")
    }

    @Test("EXTINF — whole number keeps one decimal v3")
    func extInfWholeDecimalV3() {
        let result = writer.writeExtInf(
            duration: 6.0, title: nil, version: .v3
        )
        #expect(result == "#EXTINF:6.0,")
    }

    @Test("EXTINF — nil version defaults to decimal")
    func extInfNilVersion() {
        let result = writer.writeExtInf(
            duration: 5.5, title: nil, version: nil
        )
        #expect(result == "#EXTINF:5.5,")
    }

    @Test("EXTINF — strips trailing zeros")
    func extInfStripsTrailingZeros() {
        let result = writer.writeExtInf(
            duration: 4.100, title: nil, version: .v7
        )
        #expect(result == "#EXTINF:4.1,")
    }
}

// MARK: - Segment Tag Tests

@Suite("TagWriter — Segment Tags")
struct TagWriterSegmentTests {

    let writer = TagWriter()

    @Test("BYTERANGE — length only")
    func byteRangeLengthOnly() {
        let result = writer.writeByteRange(ByteRange(length: 2048))
        #expect(result == "#EXT-X-BYTERANGE:2048")
    }

    @Test("BYTERANGE — length and offset")
    func byteRangeLengthOffset() {
        let result = writer.writeByteRange(
            ByteRange(length: 1024, offset: 512)
        )
        #expect(result == "#EXT-X-BYTERANGE:1024@512")
    }

    @Test("KEY — AES-128 with URI and IV")
    func keyAES128() {
        let key = EncryptionKey(
            method: .aes128,
            uri: "https://example.com/key",
            iv: "0x00000000000000000000000000000001"
        )
        let result = writer.writeKey(key)
        #expect(result.contains("METHOD=AES-128"))
        #expect(result.contains("URI=\"https://example.com/key\""))
        #expect(result.contains("IV=0x00000000000000000000000000000001"))
    }

    @Test("KEY — NONE method")
    func keyNone() {
        let key = EncryptionKey(method: .none)
        let result = writer.writeKey(key)
        #expect(result == "#EXT-X-KEY:METHOD=NONE")
    }

    @Test("KEY — SAMPLE-AES with KEYFORMAT")
    func keySampleAES() {
        let key = EncryptionKey(
            method: .sampleAES, uri: "key.bin", keyFormat: "identity"
        )
        let result = writer.writeKey(key)
        #expect(result.contains("METHOD=SAMPLE-AES"))
        #expect(result.contains("KEYFORMAT=\"identity\""))
    }

    @Test("MAP — URI only")
    func mapURIOnly() {
        let result = writer.writeMap(MapTag(uri: "init.mp4"))
        #expect(result == "#EXT-X-MAP:URI=\"init.mp4\"")
    }

    @Test("MAP — URI with BYTERANGE")
    func mapWithByteRange() {
        let map = MapTag(
            uri: "init.mp4",
            byteRange: ByteRange(length: 720, offset: 0)
        )
        let result = writer.writeMap(map)
        #expect(result.contains("URI=\"init.mp4\""))
        #expect(result.contains("BYTERANGE=\"720@0\""))
    }

    @Test("PROGRAM-DATE-TIME — ISO 8601 output")
    func programDateTime() {
        let date = Date(timeIntervalSince1970: 1_771_322_400)
        let result = writer.writeProgramDateTime(date)
        #expect(result.hasPrefix("#EXT-X-PROGRAM-DATE-TIME:"))
        #expect(result.contains("2026"))
    }

    @Test("DATERANGE — with duration and custom attributes")
    func dateRange() {
        let date = Date(timeIntervalSince1970: 1_771_322_430)
        let dr = DateRange(
            id: "ad-break",
            startDate: date,
            classAttribute: "com.example.ad",
            duration: 30.0,
            plannedDuration: 30.0,
            clientAttributes: ["X-CUSTOM": "value"]
        )
        let result = writer.writeDateRange(dr)
        #expect(result.contains("ID=\"ad-break\""))
        #expect(result.contains("DURATION=30.0"))
        #expect(result.contains("CLASS=\"com.example.ad\""))
        #expect(result.contains("X-CUSTOM=\"value\""))
    }
}

// MARK: - Master Playlist Tag Tests

@Suite("TagWriter — Master Tags")
struct TagWriterMasterTests {

    let writer = TagWriter()

    @Test("STREAM-INF — minimal")
    func streamInfMinimal() {
        let variant = Variant(bandwidth: 800_000, uri: "480p/playlist.m3u8")
        let result = writer.writeStreamInf(variant)
        #expect(result == "#EXT-X-STREAM-INF:BANDWIDTH=800000")
    }

    @Test("STREAM-INF — full attributes")
    func streamInfFull() {
        let variant = Variant(
            bandwidth: 2_800_000,
            resolution: .p720,
            uri: "720p/playlist.m3u8",
            averageBandwidth: 2_200_000,
            codecs: "avc1.4d401f,mp4a.40.2",
            frameRate: 30.0,
            hdcpLevel: .type0,
            audio: "audio-aac",
            subtitles: "subs"
        )
        let result = writer.writeStreamInf(variant)
        #expect(result.contains("BANDWIDTH=2800000"))
        #expect(result.contains("AVERAGE-BANDWIDTH=2200000"))
        #expect(result.contains("RESOLUTION=1280x720"))
        #expect(result.contains("FRAME-RATE=30.000"))
        #expect(result.contains("CODECS=\"avc1.4d401f,mp4a.40.2\""))
        #expect(result.contains("AUDIO=\"audio-aac\""))
        #expect(result.contains("SUBTITLES=\"subs\""))
        #expect(result.contains("HDCP-LEVEL=TYPE-0"))
    }

    @Test("I-FRAME-STREAM-INF — URI in attributes")
    func iFrameStreamInf() {
        let variant = IFrameVariant(
            bandwidth: 200_000,
            uri: "480p/iframe.m3u8",
            codecs: "avc1.4d401e",
            resolution: Resolution(width: 640, height: 480)
        )
        let result = writer.writeIFrameStreamInf(variant)
        #expect(result.contains("BANDWIDTH=200000"))
        #expect(result.contains("URI=\"480p/iframe.m3u8\""))
        #expect(result.contains("CODECS=\"avc1.4d401e\""))
        #expect(result.contains("RESOLUTION=640x480"))
    }

    @Test("MEDIA — audio rendition")
    func mediaAudio() {
        let rendition = Rendition(
            type: .audio, groupId: "audio-aac", name: "English",
            uri: "audio/en/playlist.m3u8", language: "en",
            isDefault: true, autoselect: true
        )
        let result = writer.writeMedia(rendition)
        #expect(result.contains("TYPE=AUDIO"))
        #expect(result.contains("GROUP-ID=\"audio-aac\""))
        #expect(result.contains("NAME=\"English\""))
        #expect(result.contains("DEFAULT=YES"))
        #expect(result.contains("AUTOSELECT=YES"))
        #expect(result.contains("LANGUAGE=\"en\""))
        #expect(result.contains("URI=\"audio/en/playlist.m3u8\""))
    }

    @Test("MEDIA — subtitle rendition with FORCED")
    func mediaSubtitles() {
        let rendition = Rendition(
            type: .subtitles, groupId: "subs", name: "English",
            uri: "subs/en/playlist.m3u8", language: "en",
            isDefault: true, autoselect: true, forced: false
        )
        let result = writer.writeMedia(rendition)
        #expect(result.contains("TYPE=SUBTITLES"))
        #expect(result.contains("FORCED=NO"))
    }

    @Test("MEDIA — closed-captions with INSTREAM-ID")
    func mediaClosedCaptions() {
        let rendition = Rendition(
            type: .closedCaptions, groupId: "cc", name: "CC",
            isDefault: true, instreamId: "CC1"
        )
        let result = writer.writeMedia(rendition)
        #expect(result.contains("TYPE=CLOSED-CAPTIONS"))
        #expect(result.contains("INSTREAM-ID=\"CC1\""))
        #expect(!result.contains("URI="))
    }

    @Test("SESSION-DATA — with VALUE")
    func sessionDataValue() {
        let data = SessionData(
            dataId: "com.example.title",
            value: "My Great Show",
            language: "en"
        )
        let result = writer.writeSessionData(data)
        #expect(result.contains("DATA-ID=\"com.example.title\""))
        #expect(result.contains("VALUE=\"My Great Show\""))
        #expect(result.contains("LANGUAGE=\"en\""))
    }

    @Test("SESSION-DATA — with URI")
    func sessionDataURI() {
        let data = SessionData(
            dataId: "com.example.metadata", uri: "metadata.json"
        )
        let result = writer.writeSessionData(data)
        #expect(result.contains("URI=\"metadata.json\""))
        #expect(!result.contains("VALUE="))
    }

    @Test("CONTENT-STEERING — full")
    func contentSteering() {
        let steering = ContentSteering(
            serverUri: "https://example.com/steering",
            pathwayId: "CDN-A"
        )
        let result = writer.writeContentSteering(steering)
        let expected =
            "#EXT-X-CONTENT-STEERING:"
            + "SERVER-URI=\"https://example.com/steering\","
            + "PATHWAY-ID=\"CDN-A\""
        #expect(result == expected)
    }
}

// MARK: - LL-HLS Tag Tests

@Suite("TagWriter — LL-HLS Tags")
struct TagWriterLLHLSTests {

    let writer = TagWriter()

    @Test("PART — basic")
    func partBasic() {
        let part = PartialSegment(
            uri: "segment102.0.mp4", duration: 1.001
        )
        let result = writer.writePart(part)
        #expect(result.contains("DURATION=1.001"))
        #expect(result.contains("URI=\"segment102.0.mp4\""))
        #expect(!result.contains("INDEPENDENT"))
    }

    @Test("PART — with INDEPENDENT")
    func partIndependent() {
        let part = PartialSegment(
            uri: "segment102.3.mp4", duration: 0.997, independent: true
        )
        let result = writer.writePart(part)
        #expect(result.contains("INDEPENDENT=YES"))
    }

    @Test("PART-INF")
    func partInf() {
        let result = writer.writePartInf(partTarget: 1.004)
        #expect(result == "#EXT-X-PART-INF:PART-TARGET=1.004")
    }

    @Test("SERVER-CONTROL")
    func serverControl() {
        let control = ServerControl(
            canBlockReload: true, canSkipUntil: 24.0,
            partHoldBack: 3.012
        )
        let result = writer.writeServerControl(control)
        #expect(result.contains("CAN-BLOCK-RELOAD=YES"))
        #expect(result.contains("CAN-SKIP-UNTIL=24.0"))
        #expect(result.contains("PART-HOLD-BACK=3.012"))
    }

    @Test("PRELOAD-HINT")
    func preloadHint() {
        let hint = PreloadHint(type: .part, uri: "segment103.2.mp4")
        let result = writer.writePreloadHint(hint)
        #expect(result.contains("TYPE=PART"))
        #expect(result.contains("URI=\"segment103.2.mp4\""))
    }

    @Test("RENDITION-REPORT")
    func renditionReport() {
        let report = RenditionReport(
            uri: "../720p/playlist.m3u8",
            lastMediaSequence: 103, lastPartIndex: 1
        )
        let result = writer.writeRenditionReport(report)
        #expect(result.contains("URI=\"../720p/playlist.m3u8\""))
        #expect(result.contains("LAST-MSN=103"))
        #expect(result.contains("LAST-PART=1"))
    }

    @Test("SKIP")
    func skip() {
        let skip = SkipInfo(skippedSegments: 10)
        let result = writer.writeSkip(skip)
        #expect(result == "#EXT-X-SKIP:SKIPPED-SEGMENTS=10")
    }
}

// MARK: - Common Tag Tests

@Suite("TagWriter — Common Tags")
struct TagWriterCommonTests {

    let writer = TagWriter()

    @Test("START — with PRECISE")
    func startWithPrecise() {
        let start = StartOffset(timeOffset: 25.0, precise: true)
        let result = writer.writeStart(start)
        #expect(result.contains("TIME-OFFSET=25.0"))
        #expect(result.contains("PRECISE=YES"))
    }

    @Test("START — without PRECISE")
    func startWithoutPrecise() {
        let start = StartOffset(timeOffset: -10.5)
        let result = writer.writeStart(start)
        #expect(result.contains("TIME-OFFSET=-10.5"))
        #expect(!result.contains("PRECISE"))
    }

    @Test("DEFINE — NAME/VALUE pair")
    func defineNameValue() {
        let def = VariableDefinition(
            name: "base-url", value: "https://cdn.example.com"
        )
        let result = writer.writeDefine(def)
        let expected =
            "#EXT-X-DEFINE:NAME=\"base-url\","
            + "VALUE=\"https://cdn.example.com\""
        #expect(result == expected)
    }
}

// MARK: - Formatting Helper Tests

@Suite("TagWriter — Formatting Helpers")
struct TagWriterFormattingTests {

    let writer = TagWriter()

    @Test("formatAttributes — key=value pairs")
    func formatAttributes() {
        let result = writer.formatAttributes([
            ("KEY1", "val1"),
            ("KEY2", "\"val2\"")
        ])
        #expect(result == "KEY1=val1,KEY2=\"val2\"")
    }

    @Test("quoted — wraps in double quotes")
    func quoted() {
        #expect(writer.quoted("hello") == "\"hello\"")
    }

    @Test("formatResolution — WIDTHxHEIGHT")
    func formatResolution() {
        let result = writer.formatResolution(.p1080)
        #expect(result == "1920x1080")
    }

    @Test("formatBool — YES/NO")
    func formatBool() {
        #expect(writer.formatBool(true) == "YES")
        #expect(writer.formatBool(false) == "NO")
    }

    @Test("formatDecimal — trims trailing zeros")
    func formatDecimal() {
        #expect(writer.formatDecimal(6.006) == "6.006")
        #expect(writer.formatDecimal(6.0) == "6.0")
        #expect(writer.formatDecimal(6.100) == "6.1")
    }
}
