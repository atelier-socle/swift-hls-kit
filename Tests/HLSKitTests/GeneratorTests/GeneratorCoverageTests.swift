// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - TagWriter Coverage

@Suite("TagWriter — Coverage Gaps")
struct TagWriterCoverageTests {

    let writer = TagWriter()

    @Test("writeKey — with KEYFORMATVERSIONS")
    func keyWithFormatVersions() {
        let key = EncryptionKey(
            method: .aes128, uri: "key.bin",
            keyFormat: "identity",
            keyFormatVersions: "1"
        )
        let result = writer.writeKey(key)
        #expect(result.contains("KEYFORMATVERSIONS=\"1\""))
    }

    @Test("writeStreamInf — with VIDEO group")
    func streamInfWithVideo() {
        let variant = Variant(
            bandwidth: 800_000,
            uri: "v.m3u8",
            video: "video-group"
        )
        let result = writer.writeStreamInf(variant)
        #expect(result.contains("VIDEO=\"video-group\""))
    }

    @Test("writeStreamInf — with CLOSED-CAPTIONS")
    func streamInfWithCC() {
        let variant = Variant(
            bandwidth: 800_000,
            uri: "v.m3u8",
            closedCaptions: .groupId("cc1")
        )
        let result = writer.writeStreamInf(variant)
        #expect(result.contains("CLOSED-CAPTIONS=\"cc1\""))
    }

    @Test("writeStreamInf — CC NONE")
    func streamInfCCNone() {
        let variant = Variant(
            bandwidth: 800_000,
            uri: "v.m3u8",
            closedCaptions: ClosedCaptionsValue.none
        )
        let result = writer.writeStreamInf(variant)
        #expect(result.contains("CLOSED-CAPTIONS=NONE"))
    }

    @Test("writeIFrameStreamInf — with HDCP")
    func iFrameStreamInfHDCP() {
        let variant = IFrameVariant(
            bandwidth: 200_000,
            uri: "iframe.m3u8",
            hdcpLevel: .type1
        )
        let result = writer.writeIFrameStreamInf(variant)
        #expect(result.contains("HDCP-LEVEL=TYPE-1"))
    }

    @Test("writeIFrameStreamInf — with VIDEO")
    func iFrameStreamInfVideo() {
        let variant = IFrameVariant(
            bandwidth: 200_000,
            uri: "iframe.m3u8",
            video: "video-group"
        )
        let result = writer.writeIFrameStreamInf(variant)
        #expect(result.contains("VIDEO=\"video-group\""))
    }

    @Test("writeIFrameStreamInf — average bandwidth")
    func iFrameStreamInfAvgBW() {
        let variant = IFrameVariant(
            bandwidth: 200_000,
            uri: "iframe.m3u8",
            averageBandwidth: 150_000
        )
        let result = writer.writeIFrameStreamInf(variant)
        #expect(result.contains("AVERAGE-BANDWIDTH=150000"))
    }

    @Test("writeMedia — video rendition no URI")
    func mediaVideoNoURI() {
        let rendition = Rendition(
            type: .video, groupId: "vid",
            name: "Main"
        )
        let result = writer.writeMedia(rendition)
        #expect(result.contains("TYPE=VIDEO"))
        #expect(!result.contains("URI="))
    }

    @Test("writeMedia — with CHARACTERISTICS")
    func mediaWithCharacteristics() {
        let rendition = Rendition(
            type: .audio, groupId: "audio",
            name: "English", uri: "en.m3u8",
            characteristics: "public.accessibility"
        )
        let result = writer.writeMedia(rendition)
        #expect(
            result.contains(
                "CHARACTERISTICS=\"public.accessibility\""
            ))
    }

    @Test("writeMedia — with CHANNELS")
    func mediaWithChannels() {
        let rendition = Rendition(
            type: .audio, groupId: "audio",
            name: "English", uri: "en.m3u8",
            channels: "2"
        )
        let result = writer.writeMedia(rendition)
        #expect(result.contains("CHANNELS=\"2\""))
    }

    @Test("writeMedia — with ASSOC-LANGUAGE")
    func mediaWithAssocLanguage() {
        let rendition = Rendition(
            type: .audio, groupId: "audio",
            name: "English", uri: "en.m3u8",
            language: "en", assocLanguage: "fr"
        )
        let result = writer.writeMedia(rendition)
        #expect(result.contains("ASSOC-LANGUAGE=\"fr\""))
    }

    @Test("writeSessionKey — outputs EXT-X-SESSION-KEY")
    func sessionKey() {
        let key = EncryptionKey(
            method: .aes128, uri: "key.bin"
        )
        let result = writer.writeSessionKey(key)
        #expect(result.hasPrefix("#EXT-X-SESSION-KEY:"))
        #expect(result.contains("METHOD=AES-128"))
    }

    @Test("writePart — with BYTERANGE and GAP")
    func partWithByteRangeAndGap() {
        let part = PartialSegment(
            uri: "seg.mp4", duration: 1.0,
            byteRange: ByteRange(length: 512, offset: 0),
            isGap: true
        )
        let result = writer.writePart(part)
        #expect(result.contains("BYTERANGE=\"512@0\""))
        #expect(result.contains("GAP=YES"))
    }

    @Test("writePreloadHint — MAP type with byte range")
    func preloadHintMapType() {
        let hint = PreloadHint(
            type: .map, uri: "init.mp4",
            byteRangeStart: 0, byteRangeLength: 720
        )
        let result = writer.writePreloadHint(hint)
        #expect(result.contains("TYPE=MAP"))
        #expect(result.contains("BYTERANGE-START=0"))
        #expect(result.contains("BYTERANGE-LENGTH=720"))
    }

    @Test("writeServerControl — with CAN-SKIP-DATERANGES")
    func serverControlSkipDateRanges() {
        let control = ServerControl(
            canBlockReload: true,
            canSkipUntil: 24.0,
            canSkipDateRanges: true,
            partHoldBack: 3.0
        )
        let result = writer.writeServerControl(control)
        #expect(result.contains("CAN-SKIP-DATERANGES=YES"))
    }

    @Test("writeServerControl — with HOLD-BACK")
    func serverControlHoldBack() {
        let control = ServerControl(
            canBlockReload: true,
            holdBack: 12.0
        )
        let result = writer.writeServerControl(control)
        #expect(result.contains("HOLD-BACK=12.0"))
    }

    @Test("writeRenditionReport — without optional fields")
    func renditionReportMinimal() {
        let report = RenditionReport(uri: "other.m3u8")
        let result = writer.writeRenditionReport(report)
        #expect(result.contains("URI=\"other.m3u8\""))
        #expect(!result.contains("LAST-MSN"))
    }

    @Test("writeSkip — with recently removed date ranges")
    func skipWithDateRanges() {
        let skip = SkipInfo(
            skippedSegments: 5,
            recentlyRemovedDateRanges: ["range1", "range2"]
        )
        let result = writer.writeSkip(skip)
        #expect(result.contains("SKIPPED-SEGMENTS=5"))
        #expect(
            result.contains(
                "RECENTLY-REMOVED-DATERANGES=\"range1\trange2\""
            ))
    }

    @Test("writeSessionData — VALUE format")
    func sessionDataValue() {
        let data = SessionData(
            dataId: "com.example.title",
            value: "Title"
        )
        let result = writer.writeSessionData(data)
        #expect(result.contains("VALUE=\"Title\""))
        #expect(!result.contains("URI="))
    }

    @Test("writeDefine — IMPORT form")
    func defineImport() {
        let def = VariableDefinition(
            name: "base-url", value: ""
        )
        let result = writer.writeDefine(def)
        #expect(result.contains("NAME=\"base-url\""))
    }

    @Test("EXTINF — integer duration v1")
    func extInfIntegerV1() {
        let result = writer.writeExtInf(
            duration: 10.0, title: nil, version: .v1
        )
        #expect(result == "#EXTINF:10,")
    }

    @Test("formatDecimal — negative value")
    func formatDecimalNegative() {
        #expect(writer.formatDecimal(-10.5) == "-10.5")
    }

    @Test("writeDateRange — endDate, endOnNext, SCTE35")
    func dateRangeFullCoverage() {
        let start = Date(timeIntervalSince1970: 1_771_322_400)
        let end = Date(timeIntervalSince1970: 1_771_326_000)
        let dateRange = DateRange(
            id: "ad1",
            startDate: start,
            endDate: end,
            endOnNext: true,
            scte35Cmd: "0xFC00",
            scte35Out: "0xFC01",
            scte35In: "0xFC02"
        )
        let result = writer.writeDateRange(dateRange)
        #expect(result.contains("END-DATE="))
        #expect(result.contains("END-ON-NEXT=YES"))
        #expect(result.contains("SCTE35-CMD=0xFC00"))
        #expect(result.contains("SCTE35-OUT=0xFC01"))
        #expect(result.contains("SCTE35-IN=0xFC02"))
    }

    @Test("writeSessionKey — with IV and KEYFORMAT")
    func sessionKeyIVAndKeyFormat() {
        let key = EncryptionKey(
            method: .aes128,
            uri: "key.bin",
            iv: "0x00000001",
            keyFormat: "identity",
            keyFormatVersions: "1"
        )
        let result = writer.writeSessionKey(key)
        #expect(result.contains("IV=0x00000001"))
        #expect(result.contains("KEYFORMAT=\"identity\""))
        #expect(
            result.contains(
                "KEYFORMATVERSIONS=\"1\""
            ))
    }

    @Test("formatByteRange — without offset")
    func formatByteRangeNoOffset() {
        let br = ByteRange(length: 512)
        let result = writer.formatByteRange(br)
        #expect(result == "512")
    }

    @Test("formatDuration — version < 3 integer format")
    func formatDurationV2() {
        let result = writer.formatDuration(
            6.006, version: .v2
        )
        #expect(result == "6")
    }
}

// MARK: - ManifestGenerator Coverage

@Suite("ManifestGenerator — Coverage Gaps")
struct ManifestGeneratorCoverageTests {

    let generator = ManifestGenerator()

    @Test("Master with session keys")
    func masterWithSessionKeys() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ],
            sessionKeys: [
                EncryptionKey(
                    method: .aes128, uri: "key.bin"
                )
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(output.contains("#EXT-X-SESSION-KEY:"))
    }

    @Test("Media with skip info")
    func mediaWithSkip() {
        let playlist = MediaPlaylist(
            targetDuration: 4,
            mediaSequence: 100,
            segments: [
                Segment(duration: 4.0, uri: "seg.mp4")
            ],
            skip: SkipInfo(skippedSegments: 10)
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-SKIP:"))
    }

    @Test("Media with PROGRAM-DATE-TIME")
    func mediaWithProgramDateTime() {
        let date = Date(timeIntervalSince1970: 1_771_322_400)
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0, uri: "seg.ts",
                    programDateTime: date
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    @Test("Media with discontinuity sequence")
    func mediaWithDiscontinuitySequence() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            discontinuitySequence: 5,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(
            output.contains(
                "#EXT-X-DISCONTINUITY-SEQUENCE:5"
            ))
    }

    @Test("Media version v1 — no VERSION tag")
    func mediaVersionV1() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            segments: [
                Segment(duration: 10, uri: "seg.ts")
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(!output.contains("#EXT-X-VERSION:"))
    }

    @Test("Master version v1 — no VERSION tag")
    func masterVersionV1() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(bandwidth: 800_000, uri: "v.m3u8")
            ]
        )
        let output = generator.generateMaster(playlist)
        #expect(!output.contains("#EXT-X-VERSION:"))
    }

    @Test("Generate via Manifest enum — master")
    func generateManifestMaster() {
        let manifest = Manifest.master(
            MasterPlaylist(
                variants: [
                    Variant(bandwidth: 800_000, uri: "v.m3u8")
                ]
            ))
        let output = generator.generate(manifest)
        #expect(output.contains("#EXT-X-STREAM-INF:"))
    }

    @Test("Generate via Manifest enum — media")
    func generateManifestMedia() {
        let manifest = Manifest.media(
            MediaPlaylist(
                targetDuration: 6,
                segments: [
                    Segment(duration: 6.0, uri: "seg.ts")
                ]
            ))
        let output = generator.generate(manifest)
        #expect(output.contains("#EXT-X-TARGETDURATION:6"))
    }

    @Test("Media with I-FRAMES-ONLY")
    func mediaIFramesOnly() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            iFramesOnly: true,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-I-FRAMES-ONLY"))
    }

    @Test("Media with INDEPENDENT-SEGMENTS")
    func mediaIndependentSegments() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ],
            independentSegments: true
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }

    @Test("Media with START offset")
    func mediaStartOffset() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ],
            startOffset: StartOffset(timeOffset: 10.0)
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-START:"))
    }

    @Test("Media with variable definitions")
    func mediaDefinitions() {
        let playlist = MediaPlaylist(
            version: .v8,
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg.ts")
            ],
            definitions: [
                VariableDefinition(
                    name: "base", value: "https://cdn.example.com"
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-DEFINE:"))
    }

    @Test("Media with key format version encryption")
    func mediaKeyFormatVersion() {
        let playlist = MediaPlaylist(
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0, uri: "seg.ts",
                    key: EncryptionKey(
                        method: .aes128,
                        uri: "key.bin",
                        keyFormat: "identity",
                        keyFormatVersions: "1"
                    )
                )
            ]
        )
        let output = generator.generateMedia(playlist)
        #expect(output.contains("#EXT-X-VERSION:5"))
    }
}
