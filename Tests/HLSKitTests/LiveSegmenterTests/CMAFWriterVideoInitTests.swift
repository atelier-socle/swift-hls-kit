// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CMAFWriter — Video Init", .timeLimit(.minutes(1)))
struct CMAFWriterVideoInitTests {

    let writer = CMAFWriter()

    // MARK: - Helpers

    private func readBoxes(
        from data: Data
    ) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    private func findBox(
        _ type: String, in boxes: [MP4Box]
    ) -> MP4Box? {
        boxes.first { $0.type == type }
    }

    private func containsFourCC(
        _ fourCC: String, in data: Data
    ) -> Bool {
        let pattern = Data(fourCC.utf8)
        guard pattern.count == 4, data.count >= 4 else {
            return false
        }
        let range = data.startIndex...(data.endIndex - 4)
        return range.contains { data[$0..<($0 + 4)] == pattern }
    }

    private func makeVideoConfig() -> CMAFWriter.VideoConfig {
        CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1280, height: 720,
            sps: makeSPS(), pps: makePPS()
        )
    }

    private func makeSPS() -> Data {
        Data([0x67, 0x42, 0xC0, 0x1E, 0xD9, 0x00, 0xA0])
    }

    private func makePPS() -> Data {
        Data([0x68, 0xCE, 0x38, 0x80])
    }

    // MARK: - Video Init Segment

    @Test("Video init segment contains ftyp and moov")
    func videoInitSegmentStructure() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)

        #expect(findBox("ftyp", in: boxes) != nil)
        #expect(findBox("moov", in: boxes) != nil)
    }

    @Test("Video init segment trak has stsd with avc1")
    func videoInitTrakStsd() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let stsd = try #require(
            moov.findByPath("trak/mdia/minf/stbl/stsd")
        )
        let payload = try #require(stsd.payload)
        #expect(containsFourCC("avc1", in: payload))
    }

    @Test("Video init segment has avcC inside avc1")
    func videoInitAvcC() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let stsd = try #require(
            moov.findByPath("trak/mdia/minf/stbl/stsd")
        )
        let payload = try #require(stsd.payload)
        #expect(containsFourCC("avcC", in: payload))
    }

    @Test("Video init segment has correct dimensions in tkhd")
    func videoInitDimensions() throws {
        let config = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1920, height: 1080,
            sps: makeSPS(), pps: makePPS()
        )
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let tkhd = try #require(
            moov.findByPath("trak/tkhd")
        )
        #expect(tkhd.payload != nil)
    }

    @Test("Video init segment has vmhd in minf")
    func videoInitVmhd() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let minf = try #require(
            moov.findByPath("trak/mdia/minf")
        )
        #expect(minf.findChild("vmhd") != nil)
    }

    @Test("Video init segment mvex with trex")
    func videoInitMvex() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let mvex = try #require(moov.findChild("mvex"))
        #expect(mvex.findChild("trex") != nil)
    }

    @Test("Video init segment has VideoHandler in hdlr")
    func videoInitHdlr() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let hdlr = try #require(
            moov.findByPath("trak/mdia/hdlr")
        )
        let payload = try #require(hdlr.payload)
        let payloadString =
            String(
                data: payload, encoding: .ascii
            ) ?? ""
        #expect(payloadString.contains("vide"))
    }

    @Test("Video init segment round-trips through MP4BoxReader")
    func videoInitRoundTrip() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)

        #expect(boxes.count == 2)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    // MARK: - avc1 VisualSampleEntry Layout (ISO 14496-12 §12.1.3)

    @Test("avc1 VisualSampleEntry is 78 bytes before avcC box")
    func avc1VisualSampleEntrySize() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(config: config)
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let stsd = try #require(
            moov.findByPath("trak/mdia/minf/stbl/stsd")
        )
        let payload = try #require(stsd.payload)
        // stsd payload: 4-byte version/flags already stripped by reader,
        // then 4-byte entry_count, then avc1 box.
        // Find "avc1" fourCC in payload to locate the box header.
        let avc1FourCC = Data("avc1".utf8)
        var avc1Offset: Int?
        for i in 0...(payload.count - 4) {
            let start = payload.startIndex + i
            if payload[start..<(start + 4)] == avc1FourCC {
                avc1Offset = i
                break
            }
        }
        let boxStart = try #require(avc1Offset)
        // avc1 box: 4 size + 4 type + 78 VisualSampleEntry = 86 bytes
        // to the first child box (avcC).
        let avcCExpectedOffset = boxStart + 4 + 78  // after type + entry
        let remaining = payload.count - avcCExpectedOffset
        #expect(remaining > 8, "Not enough data after VisualSampleEntry")
        // Read the fourCC at that offset — must be "avcC"
        let fourCCStart = payload.startIndex + avcCExpectedOffset + 4
        let fourCCEnd = fourCCStart + 4
        #expect(fourCCEnd <= payload.endIndex)
        let fourCC = String(
            data: payload[fourCCStart..<fourCCEnd], encoding: .ascii
        )
        #expect(fourCC == "avcC", "avcC must start at offset 78 in avc1")
    }

    @Test("avc1 avcC box contains valid configurationVersion")
    func avc1AvcCConfigVersion() throws {
        let config = makeVideoConfig()
        let data = writer.generateVideoInitSegment(config: config)
        let boxes = try readBoxes(from: data)
        let moov = try #require(findBox("moov", in: boxes))
        let stsd = try #require(
            moov.findByPath("trak/mdia/minf/stbl/stsd")
        )
        let payload = try #require(stsd.payload)
        // Find "avcC" fourCC
        let avcCFourCC = Data("avcC".utf8)
        var avcCOffset: Int?
        for i in 0...(payload.count - 4) {
            let start = payload.startIndex + i
            if payload[start..<(start + 4)] == avcCFourCC {
                avcCOffset = i
                break
            }
        }
        let boxTypeOffset = try #require(avcCOffset)
        // After 4-byte type comes the avcC payload
        let configVersionOffset =
            payload.startIndex + boxTypeOffset + 4
        #expect(configVersionOffset < payload.endIndex)
        // configurationVersion must be 1
        #expect(payload[configVersionOffset] == 1)
    }

    // MARK: - VideoConfig

    @Test("VideoConfig equatable")
    func videoConfigEquatable() {
        let config1 = makeVideoConfig()
        let config2 = makeVideoConfig()
        #expect(config1 == config2)
    }

    @Test("VideoConfig default timescale is 90000")
    func videoConfigDefaultTimescale() {
        let config = makeVideoConfig()
        #expect(config.timescale == 90000)
    }
}
