// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MP4Box")
struct MP4BoxTests {

    // MARK: - Properties

    @Test("dataOffset — standard header")
    func dataOffsetStandard() {
        let box = MP4Box(
            type: "test", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: []
        )
        #expect(box.dataOffset == 8)
    }

    @Test("dataOffset — extended header")
    func dataOffsetExtended() {
        let box = MP4Box(
            type: "test", size: 100, offset: 50,
            headerSize: 16, payload: nil, children: []
        )
        #expect(box.dataOffset == 66)
    }

    @Test("dataSize — calculated correctly")
    func dataSize() {
        let box = MP4Box(
            type: "test", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: []
        )
        #expect(box.dataSize == 92)
    }

    // MARK: - findChild

    @Test("findChild — existing child")
    func findChildExisting() {
        let child = MP4Box(
            type: "mvhd", size: 20, offset: 8,
            headerSize: 8, payload: Data(), children: []
        )
        let parent = MP4Box(
            type: "moov", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: [child]
        )
        let found = parent.findChild("mvhd")
        #expect(found != nil)
        #expect(found?.type == "mvhd")
    }

    @Test("findChild — missing child")
    func findChildMissing() {
        let parent = MP4Box(
            type: "moov", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: []
        )
        #expect(parent.findChild("trak") == nil)
    }

    // MARK: - findChildren

    @Test("findChildren — multiple results")
    func findChildrenMultiple() {
        let trak1 = MP4Box(
            type: "trak", size: 20, offset: 8,
            headerSize: 8, payload: nil, children: []
        )
        let trak2 = MP4Box(
            type: "trak", size: 20, offset: 28,
            headerSize: 8, payload: nil, children: []
        )
        let mvhd = MP4Box(
            type: "mvhd", size: 20, offset: 48,
            headerSize: 8, payload: Data(), children: []
        )
        let moov = MP4Box(
            type: "moov", size: 200, offset: 0,
            headerSize: 8, payload: nil,
            children: [trak1, mvhd, trak2]
        )
        let traks = moov.findChildren("trak")
        #expect(traks.count == 2)
    }

    @Test("findChildren — none found")
    func findChildrenNone() {
        let moov = MP4Box(
            type: "moov", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: []
        )
        #expect(moov.findChildren("trak").isEmpty)
    }

    // MARK: - findByPath

    @Test("findByPath — nested path")
    func findByPathNested() {
        let hdlr = MP4Box(
            type: "hdlr", size: 20, offset: 0,
            headerSize: 8, payload: Data(), children: []
        )
        let mdia = MP4Box(
            type: "mdia", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: [hdlr]
        )
        let trak = MP4Box(
            type: "trak", size: 200, offset: 0,
            headerSize: 8, payload: nil, children: [mdia]
        )
        let moov = MP4Box(
            type: "moov", size: 300, offset: 0,
            headerSize: 8, payload: nil, children: [trak]
        )
        let found = moov.findByPath("trak/mdia/hdlr")
        #expect(found != nil)
        #expect(found?.type == "hdlr")
    }

    @Test("findByPath — missing intermediate")
    func findByPathMissing() {
        let moov = MP4Box(
            type: "moov", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: []
        )
        #expect(moov.findByPath("trak/mdia/hdlr") == nil)
    }

    // MARK: - tracks

    @Test("tracks — returns trak children")
    func tracks() {
        let trak = MP4Box(
            type: "trak", size: 20, offset: 8,
            headerSize: 8, payload: nil, children: []
        )
        let moov = MP4Box(
            type: "moov", size: 100, offset: 0,
            headerSize: 8, payload: nil, children: [trak]
        )
        #expect(moov.tracks.count == 1)
    }

    // MARK: - BoxType Constants

    @Test("containerTypes — contains expected types")
    func containerTypes() {
        let types = MP4Box.BoxType.containerTypes
        #expect(types.contains("moov"))
        #expect(types.contains("trak"))
        #expect(types.contains("mdia"))
        #expect(types.contains("minf"))
        #expect(types.contains("stbl"))
        #expect(types.contains("moof"))
        #expect(types.contains("traf"))
        #expect(!types.contains("mvhd"))
        #expect(!types.contains("mdat"))
    }

    // MARK: - Hashable

    @Test("Hashable — equal boxes")
    func hashableEqual() {
        let payload = Data([1, 2, 3])
        let a = MP4Box(
            type: "test", size: 11, offset: 0,
            headerSize: 8, payload: payload, children: []
        )
        let b = MP4Box(
            type: "test", size: 11, offset: 0,
            headerSize: 8, payload: payload, children: []
        )
        #expect(a == b)
    }
}
