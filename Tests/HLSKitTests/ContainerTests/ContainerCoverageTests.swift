// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - MP4BoxReader Coverage

@Suite("MP4BoxReader — Coverage Gaps")
struct MP4BoxReaderCoverageTests {

    let reader = MP4BoxReader()

    @Test("readBoxes from URL — valid file")
    func readFromURL() throws {
        let data = MP4TestDataBuilder.minimalMP4()
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(
            "test_\(UUID().uuidString).mp4"
        )
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let boxes = try reader.readBoxes(from: url)
        #expect(boxes.count == 3)
    }

    @Test("readBoxes from URL — missing file throws")
    func readFromMissingURL() {
        let url = URL(fileURLWithPath: "/nonexistent/file.mp4")
        #expect(throws: MP4Error.self) {
            try reader.readBoxes(from: url)
        }
    }

    @Test("Box with size smaller than header — error")
    func boxSizeSmallerThanHeader() {
        // Size = 4 (less than 8-byte header minimum)
        var data = Data()
        data.appendUInt32(4)
        data.appendFourCC("test")
        #expect(throws: MP4Error.self) {
            try reader.readBoxes(from: data)
        }
    }

    @Test("Free box with oversized size — generic error catch")
    func freeBoxOversizedSize() {
        // free box claims size 100 but total data is only 16
        var data = Data()
        data.appendUInt32(100)
        data.appendFourCC("free")
        data.append(Data(repeating: 0, count: 8))
        #expect(throws: MP4Error.self) {
            try reader.readBoxes(from: data)
        }
    }

    @Test("Extended size with insufficient data — readUInt64 error")
    func extendedSizeInsufficientData() {
        // rawSize=1 signals extended size, but only 4 extra bytes
        var data = Data()
        data.appendUInt32(1)  // extended size marker
        data.appendFourCC("test")
        data.append(Data(repeating: 0, count: 4))  // only 4, need 8
        #expect(throws: MP4Error.self) {
            try reader.readBoxes(from: data)
        }
    }
}

// MARK: - MP4InfoParser Coverage

@Suite("MP4InfoParser — Coverage Gaps")
struct MP4InfoParserCoverageTests {

    let boxReader = MP4BoxReader()
    let parser = MP4InfoParser()

    @Test("No ftyp — empty brands")
    func noFtyp() throws {
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                )
            ]
        )
        let boxes = try boxReader.readBoxes(from: moovBox)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.brands.isEmpty)
    }

    @Test("tkhd v1 — 64-bit time fields")
    func tkhdV1() throws {
        // Build a video track with v1 tkhd
        let tkhdPayload = buildTkhdV1(
            trackId: 1, duration: 900000,
            width: 1280, height: 720
        )
        let tkhdBox = MP4TestDataBuilder.box(
            type: "tkhd", payload: tkhdPayload
        )
        let stblBox = MP4TestDataBuilder.minimalStbl(
            codec: "avc1", hasSyncSamples: true
        )
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: 90000, duration: 900000
                ),
                MP4TestDataBuilder.hdlr(handlerType: "vide"),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak", children: [tkhdBox, mdiaBox]
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                ),
                trakBox
            ]
        )
        let ftypBox = MP4TestDataBuilder.ftyp()
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].trackId == 1)
        #expect(info.tracks[0].dimensions?.width == 1280)
    }

    @Test("mdhd v1 — 64-bit duration")
    func mdhdV1() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let mdhdBox = MP4TestDataBuilder.mdhdV1(
            timescale: 48000, duration: 480000,
            language: "fra"
        )
        let stblBox = MP4TestDataBuilder.minimalStbl(
            codec: "mp4a"
        )
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                mdhdBox,
                MP4TestDataBuilder.hdlr(handlerType: "soun"),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: 6000
                ),
                mdiaBox
            ]
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                ),
                trakBox
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].timescale == 48000)
        #expect(info.tracks[0].duration == 480000)
        #expect(info.tracks[0].language == "fra")
    }

    @Test("Unknown handler type — MediaTrackType.unknown")
    func unknownHandlerType() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let stblBox = MP4TestDataBuilder.minimalStbl(
            codec: "data"
        )
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: 1000, duration: 1000
                ),
                MP4TestDataBuilder.hdlr(
                    handlerType: "hint"
                ),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: 1000
                ),
                mdiaBox
            ]
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 1000, duration: 1000
                ),
                trakBox
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let info = try parser.parseFileInfo(from: boxes)
        #expect(info.tracks[0].mediaType == .unknown)
    }

    @Test("Track missing mdia — throws missingBox")
    func missingMdia() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: 1000
                )
            ]
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                ),
                trakBox
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        #expect(throws: MP4Error.self) {
            try parser.parseFileInfo(from: boxes)
        }
    }

    @Test("Track missing minf — throws missingBox")
    func missingMinf() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: 90000, duration: 900000
                ),
                MP4TestDataBuilder.hdlr(handlerType: "vide")
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: 6000
                ),
                mdiaBox
            ]
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                ),
                trakBox
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        #expect(throws: MP4Error.self) {
            try parser.parseFileInfo(from: boxes)
        }
    }

    @Test("Language — zero packed returns nil")
    func languageZero() {
        let result = MP4InfoParser().decodeLanguage(0)
        #expect(result == nil)
    }

    // MARK: - Helpers

    private func buildTkhdV1(
        trackId: UInt32, duration: UInt64,
        width: Double, height: Double
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(1)  // version 1
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt64(0)  // creation time
        payload.appendUInt64(0)  // modification time
        payload.appendUInt32(trackId)
        payload.appendUInt32(0)  // reserved
        payload.appendUInt64(duration)
        // reserved(8) + layer(2) + alternateGroup(2)
        // + volume(2) + reserved(2) + matrix(36) = 52
        payload.append(Data(repeating: 0, count: 52))
        payload.appendFixedPoint16x16(width)
        payload.appendFixedPoint16x16(height)
        return payload
    }
}
