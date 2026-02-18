// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("BinaryWriter")
struct BinaryWriterTests {

    // MARK: - Initialization

    @Test("init — empty buffer")
    func initEmpty() {
        let writer = BinaryWriter()
        #expect(writer.count == 0)
        #expect(writer.data.isEmpty)
    }

    @Test("init with capacity — empty but pre-allocated")
    func initCapacity() {
        let writer = BinaryWriter(capacity: 1024)
        #expect(writer.count == 0)
    }

    // MARK: - Integer Writing

    @Test("writeUInt8 — single byte")
    func writeUInt8() {
        var writer = BinaryWriter()
        writer.writeUInt8(0xAB)
        #expect(writer.data == Data([0xAB]))
    }

    @Test("writeUInt16 — big-endian")
    func writeUInt16() {
        var writer = BinaryWriter()
        writer.writeUInt16(0x0102)
        #expect(writer.data == Data([0x01, 0x02]))
    }

    @Test("writeUInt32 — big-endian")
    func writeUInt32() {
        var writer = BinaryWriter()
        writer.writeUInt32(65536)
        #expect(writer.data == Data([0x00, 0x01, 0x00, 0x00]))
    }

    @Test("writeUInt64 — big-endian")
    func writeUInt64() {
        var writer = BinaryWriter()
        writer.writeUInt64(0x0000_0001_0000_0000)
        #expect(
            writer.data
                == Data([
                    0x00, 0x00, 0x00, 0x01,
                    0x00, 0x00, 0x00, 0x00
                ])
        )
    }

    @Test("writeInt32 — negative value")
    func writeInt32Negative() {
        var writer = BinaryWriter()
        writer.writeInt32(-1)
        #expect(
            writer.data == Data([0xFF, 0xFF, 0xFF, 0xFF])
        )
    }

    @Test("writeInt64 — negative value")
    func writeInt64Negative() {
        var writer = BinaryWriter()
        writer.writeInt64(-1)
        #expect(writer.data == Data(repeating: 0xFF, count: 8))
    }

    // MARK: - Roundtrip with BinaryReader

    @Test("UInt32 roundtrip — writer then reader")
    func uint32Roundtrip() throws {
        var writer = BinaryWriter()
        writer.writeUInt32(0xDEAD_BEEF)
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readUInt32()
        #expect(value == 0xDEAD_BEEF)
    }

    @Test("UInt16 roundtrip")
    func uint16Roundtrip() throws {
        var writer = BinaryWriter()
        writer.writeUInt16(0x1234)
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readUInt16()
        #expect(value == 0x1234)
    }

    @Test("UInt64 roundtrip")
    func uint64Roundtrip() throws {
        var writer = BinaryWriter()
        writer.writeUInt64(0x0102_0304_0506_0708)
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readUInt64()
        #expect(value == 0x0102_0304_0506_0708)
    }

    @Test("Int32 roundtrip — negative")
    func int32Roundtrip() throws {
        var writer = BinaryWriter()
        writer.writeInt32(-42)
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readInt32()
        #expect(value == -42)
    }

    @Test("Int64 roundtrip — negative")
    func int64Roundtrip() throws {
        var writer = BinaryWriter()
        writer.writeInt64(-999_999)
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readInt64()
        #expect(value == -999_999)
    }

    // MARK: - Other Types

    @Test("writeFourCC — ASCII string")
    func writeFourCC() throws {
        var writer = BinaryWriter()
        writer.writeFourCC("moov")
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readFourCC()
        #expect(value == "moov")
    }

    @Test("writeFourCC — pads short string")
    func writeFourCCShort() {
        var writer = BinaryWriter()
        writer.writeFourCC("ab")
        #expect(writer.count == 4)
        // 'a', 'b', space, space
        #expect(writer.data[2] == 0x20)
        #expect(writer.data[3] == 0x20)
    }

    @Test("writeData — appends raw bytes")
    func writeData() {
        var writer = BinaryWriter()
        writer.writeData(Data([1, 2, 3]))
        #expect(writer.data == Data([1, 2, 3]))
    }

    @Test("writeZeros — writes zero padding")
    func writeZeros() {
        var writer = BinaryWriter()
        writer.writeZeros(5)
        #expect(writer.data == Data(repeating: 0, count: 5))
    }

    @Test("writeZeros — zero count is no-op")
    func writeZerosNone() {
        var writer = BinaryWriter()
        writer.writeZeros(0)
        #expect(writer.count == 0)
    }

    @Test("writeFixed16_16 — integer value roundtrip")
    func writeFixed16_16Integer() throws {
        var writer = BinaryWriter()
        writer.writeFixed16_16(1.0)
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readFixedPoint16x16()
        #expect(value == 1.0)
    }

    @Test("writeFixed16_16 — fractional value roundtrip")
    func writeFixed16_16Fractional() throws {
        var writer = BinaryWriter()
        writer.writeFixed16_16(1.5)
        var reader = BinaryReader(data: writer.data)
        let value = try reader.readFixedPoint16x16()
        #expect(value == 1.5)
    }

    // MARK: - Box Helpers

    @Test("writeBox — standard box header")
    func writeBox() throws {
        var writer = BinaryWriter()
        writer.writeBox(type: "test", payload: Data([0xAA]))
        // Box: size(4) + type(4) + payload(1) = 9 bytes
        #expect(writer.count == 9)
        var reader = BinaryReader(data: writer.data)
        let size = try reader.readUInt32()
        let boxType = try reader.readFourCC()
        let byte = try reader.readUInt8()
        #expect(size == 9)
        #expect(boxType == "test")
        #expect(byte == 0xAA)
    }

    @Test("writeBox — empty payload")
    func writeBoxEmpty() throws {
        var writer = BinaryWriter()
        writer.writeBox(type: "skip", payload: Data())
        #expect(writer.count == 8)
        var reader = BinaryReader(data: writer.data)
        let size = try reader.readUInt32()
        let boxType = try reader.readFourCC()
        #expect(size == 8)
        #expect(boxType == "skip")
    }

    @Test("writeFullBox — version and flags")
    func writeFullBox() throws {
        var writer = BinaryWriter()
        writer.writeFullBox(
            type: "tfhd", version: 0, flags: 0x020000,
            payload: Data([0x01])
        )
        // size(4)+type(4)+version(1)+flags(3)+payload(1) = 13
        #expect(writer.count == 13)
        var reader = BinaryReader(data: writer.data)
        let size = try reader.readUInt32()
        let boxType = try reader.readFourCC()
        let version = try reader.readUInt8()
        let flag1 = try reader.readUInt8()
        let flag2 = try reader.readUInt8()
        let flag3 = try reader.readUInt8()
        #expect(size == 13)
        #expect(boxType == "tfhd")
        #expect(version == 0)
        #expect(flag1 == 0x02)
        #expect(flag2 == 0x00)
        #expect(flag3 == 0x00)
    }

    @Test("writeFullBox — version 1")
    func writeFullBoxV1() throws {
        var writer = BinaryWriter()
        writer.writeFullBox(
            type: "tfdt", version: 1, flags: 0,
            payload: Data()
        )
        var reader = BinaryReader(data: writer.data)
        _ = try reader.readUInt32()  // size
        _ = try reader.readFourCC()  // type
        let version = try reader.readUInt8()
        #expect(version == 1)
    }

    @Test("writeContainerBox — children concatenated")
    func writeContainerBox() throws {
        var child1 = BinaryWriter()
        child1.writeBox(type: "aaaa", payload: Data())
        var child2 = BinaryWriter()
        child2.writeBox(type: "bbbb", payload: Data())
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "moov",
            children: [child1.data, child2.data]
        )
        var reader = BinaryReader(data: writer.data)
        let totalSize = try reader.readUInt32()
        let containerType = try reader.readFourCC()
        #expect(containerType == "moov")
        // total = 8 (header) + 8 (child1) + 8 (child2) = 24
        #expect(totalSize == 24)
        // First child
        let c1Size = try reader.readUInt32()
        let c1Type = try reader.readFourCC()
        #expect(c1Size == 8)
        #expect(c1Type == "aaaa")
        // Second child
        let c2Size = try reader.readUInt32()
        let c2Type = try reader.readFourCC()
        #expect(c2Size == 8)
        #expect(c2Type == "bbbb")
    }

    // MARK: - Sequential Writes

    @Test("sequential writes accumulate correctly")
    func sequentialWrites() {
        var writer = BinaryWriter()
        writer.writeUInt8(0x01)
        writer.writeUInt16(0x0203)
        writer.writeUInt32(0x0405_0607)
        #expect(writer.count == 7)
        #expect(
            writer.data
                == Data([
                    0x01, 0x02, 0x03,
                    0x04, 0x05, 0x06, 0x07
                ])
        )
    }
}
