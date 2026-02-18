// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MP4BoxReader")
struct MP4BoxReaderTests {

    let reader = MP4BoxReader()

    // MARK: - Basic Box Reading

    @Test("Read single ftyp box")
    func readFtyp() throws {
        let data = MP4TestDataBuilder.ftyp()
        let boxes = try reader.readBoxes(from: data)
        #expect(boxes.count == 1)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[0].payload != nil)
    }

    @Test("Read ftyp + moov + mdat structure")
    func readFtypMoovMdat() throws {
        let data = MP4TestDataBuilder.minimalMP4()
        let boxes = try reader.readBoxes(from: data)
        #expect(boxes.count == 3)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
        #expect(boxes[2].type == "mdat")
    }

    // MARK: - Container Boxes

    @Test("Container box has children")
    func containerChildren() throws {
        let data = MP4TestDataBuilder.minimalMP4()
        let boxes = try reader.readBoxes(from: data)
        let moov = boxes.first { $0.type == "moov" }
        #expect(moov != nil)
        #expect(moov?.children.isEmpty == false)
        #expect(moov?.payload == nil)
    }

    @Test("Nested containers — moov/trak/mdia/minf/stbl")
    func nestedContainers() throws {
        let data = MP4TestDataBuilder.videoMP4()
        let boxes = try reader.readBoxes(from: data)
        let moov = boxes.first { $0.type == "moov" }
        let trak = moov?.findChild("trak")
        let mdia = trak?.findChild("mdia")
        let minf = mdia?.findChild("minf")
        let stbl = minf?.findChild("stbl")
        #expect(moov != nil)
        #expect(trak != nil)
        #expect(mdia != nil)
        #expect(minf != nil)
        #expect(stbl != nil)
        #expect(stbl?.children.isEmpty == false)
    }

    // MARK: - Special Sizes

    @Test("Extended size box (size == 1)")
    func extendedSize() throws {
        let payload = Data(repeating: 0xAA, count: 4)
        let extBox = MP4TestDataBuilder.extendedSizeBox(
            type: "test", payload: payload
        )
        // Wrap in a container to avoid end-of-data issues
        let ftypBox = MP4TestDataBuilder.ftyp()
        var data = Data()
        data.append(ftypBox)
        data.append(extBox)
        let boxes = try reader.readBoxes(from: data)
        let test = boxes.first { $0.type == "test" }
        #expect(test != nil)
        #expect(test?.headerSize == 16)
        #expect(test?.size == 20)
        #expect(test?.payload?.count == 4)
    }

    @Test("Zero size box — extends to end of file")
    func zeroSize() throws {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let payload = Data(repeating: 0xBB, count: 10)
        let zeroBox = MP4TestDataBuilder.zeroSizeBox(
            type: "test", payload: payload
        )
        var data = Data()
        data.append(ftypBox)
        data.append(zeroBox)
        let boxes = try reader.readBoxes(from: data)
        let test = boxes.first { $0.type == "test" }
        #expect(test != nil)
        #expect(test?.payload?.count == 10)
    }

    // MARK: - mdat Handling

    @Test("mdat payload is NOT loaded")
    func mdatNotLoaded() throws {
        let data = MP4TestDataBuilder.minimalMP4()
        let boxes = try reader.readBoxes(from: data)
        let mdat = boxes.first { $0.type == "mdat" }
        #expect(mdat != nil)
        #expect(mdat?.payload == nil)
        #expect((mdat?.size ?? 0) > 0)
    }

    @Test("free box payload is NOT loaded")
    func freeNotLoaded() throws {
        let freeBox = MP4TestDataBuilder.box(
            type: "free",
            payload: Data(repeating: 0, count: 100)
        )
        let ftypBox = MP4TestDataBuilder.ftyp()
        var data = Data()
        data.append(ftypBox)
        data.append(freeBox)
        let boxes = try reader.readBoxes(from: data)
        let free = boxes.first { $0.type == "free" }
        #expect(free != nil)
        #expect(free?.payload == nil)
    }

    // MARK: - Unknown Box Types

    @Test("Unknown box types preserved")
    func unknownBox() throws {
        let customBox = MP4TestDataBuilder.box(
            type: "cust", payload: Data([1, 2, 3, 4])
        )
        let ftypBox = MP4TestDataBuilder.ftyp()
        var data = Data()
        data.append(ftypBox)
        data.append(customBox)
        let boxes = try reader.readBoxes(from: data)
        let custom = boxes.first { $0.type == "cust" }
        #expect(custom != nil)
        #expect(custom?.payload == Data([1, 2, 3, 4]))
    }

    // MARK: - Real Structure

    @Test("Video MP4 hierarchy — full structure")
    func videoMP4Structure() throws {
        let data = MP4TestDataBuilder.videoMP4()
        let boxes = try reader.readBoxes(from: data)
        let moov = boxes.first { $0.type == "moov" }
        #expect(moov != nil)
        // moov should have mvhd + trak
        #expect(moov?.findChild("mvhd") != nil)
        let trak = moov?.findChild("trak")
        #expect(trak != nil)
        #expect(trak?.findChild("tkhd") != nil)
        let mdia = trak?.findChild("mdia")
        #expect(mdia?.findChild("mdhd") != nil)
        #expect(mdia?.findChild("hdlr") != nil)
        let stbl = mdia?.findByPath("minf/stbl")
        #expect(stbl?.findChild("stsd") != nil)
        #expect(stbl?.findChild("stts") != nil)
    }

    // MARK: - Error Cases

    @Test("Empty data — throws")
    func emptyData() {
        #expect(throws: MP4Error.self) {
            try reader.readBoxes(from: Data())
        }
    }

    @Test("Truncated header — returns empty")
    func truncatedHeader() throws {
        let data = Data([0x00, 0x00, 0x00])
        let boxes = try reader.readBoxes(from: data)
        #expect(boxes.isEmpty)
    }

    @Test("Box size exceeds data — throws")
    func boxSizeExceedsData() {
        // Claim size of 1000 bytes but only provide 12
        var data = Data()
        data.appendUInt32(1000)
        data.appendFourCC("test")
        data.append(Data(repeating: 0, count: 4))
        #expect(throws: MP4Error.self) {
            try reader.readBoxes(from: data)
        }
    }

    // MARK: - Offset Tracking

    @Test("Box offsets are correct")
    func boxOffsets() throws {
        let data = MP4TestDataBuilder.minimalMP4()
        let boxes = try reader.readBoxes(from: data)
        #expect(boxes[0].offset == 0)
        #expect(boxes[1].offset == boxes[0].size)
    }
}
