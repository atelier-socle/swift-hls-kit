// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("BinaryReader")
struct BinaryReaderTests {

    // MARK: - Properties

    @Test("init — position starts at 0")
    func initPosition() {
        let reader = BinaryReader(data: Data([1, 2, 3]))
        #expect(reader.position == 0)
        #expect(reader.count == 3)
        #expect(reader.remaining == 3)
        #expect(reader.hasRemaining)
    }

    @Test("empty data — no remaining")
    func emptyData() {
        let reader = BinaryReader(data: Data())
        #expect(reader.count == 0)
        #expect(reader.remaining == 0)
        #expect(!reader.hasRemaining)
    }

    // MARK: - Integer Reading

    @Test("readUInt8")
    func readUInt8() throws {
        var reader = BinaryReader(data: Data([0xAB]))
        let value = try reader.readUInt8()
        #expect(value == 0xAB)
        #expect(reader.position == 1)
    }

    @Test("readUInt16 — big-endian")
    func readUInt16() throws {
        var reader = BinaryReader(data: Data([0x01, 0x02]))
        let value = try reader.readUInt16()
        #expect(value == 0x0102)
    }

    @Test("readUInt32 — big-endian")
    func readUInt32() throws {
        var reader = BinaryReader(
            data: Data([0x00, 0x01, 0x00, 0x00])
        )
        let value = try reader.readUInt32()
        #expect(value == 65536)
    }

    @Test("readUInt64 — big-endian")
    func readUInt64() throws {
        var data = Data(repeating: 0, count: 8)
        data[0] = 0x00
        data[1] = 0x00
        data[2] = 0x00
        data[3] = 0x01
        data[4] = 0x00
        data[5] = 0x00
        data[6] = 0x00
        data[7] = 0x00
        var reader = BinaryReader(data: data)
        let value = try reader.readUInt64()
        #expect(value == 0x0000_0001_0000_0000)
    }

    @Test("readInt32 — negative value")
    func readInt32Negative() throws {
        // -1 in two's complement
        var reader = BinaryReader(
            data: Data([0xFF, 0xFF, 0xFF, 0xFF])
        )
        let value = try reader.readInt32()
        #expect(value == -1)
    }

    @Test("readInt64 — negative value")
    func readInt64Negative() throws {
        var reader = BinaryReader(
            data: Data(repeating: 0xFF, count: 8)
        )
        let value = try reader.readInt64()
        #expect(value == -1)
    }

    // MARK: - Other Types

    @Test("readFourCC — ASCII string")
    func readFourCC() throws {
        let data = try #require("moov".data(using: .ascii))
        var reader = BinaryReader(data: data)
        let value = try reader.readFourCC()
        #expect(value == "moov")
    }

    @Test("readBytes — fixed count")
    func readBytes() throws {
        var reader = BinaryReader(
            data: Data([1, 2, 3, 4, 5])
        )
        let bytes = try reader.readBytes(3)
        #expect(bytes == Data([1, 2, 3]))
        #expect(reader.position == 3)
    }

    @Test("readNullTerminatedString")
    func readNullTerminated() throws {
        let data = Data([0x48, 0x69, 0x00, 0xFF])
        var reader = BinaryReader(data: data)
        let str = try reader.readNullTerminatedString()
        #expect(str == "Hi")
        #expect(reader.position == 3)
    }

    @Test("readNullTerminatedString — at end of data")
    func readNullTerminatedAtEnd() throws {
        let data = Data([0x48, 0x69])
        var reader = BinaryReader(data: data)
        let str = try reader.readNullTerminatedString()
        #expect(str == "Hi")
        #expect(reader.position == 2)
    }

    @Test("readFixedPoint16x16 — integer value")
    func readFixedPoint16x16Integer() throws {
        // 1.0 = 0x00010000
        var reader = BinaryReader(
            data: Data([0x00, 0x01, 0x00, 0x00])
        )
        let value = try reader.readFixedPoint16x16()
        #expect(value == 1.0)
    }

    @Test("readFixedPoint16x16 — fractional value")
    func readFixedPoint16x16Fractional() throws {
        // 1.5 = 0x00018000
        var reader = BinaryReader(
            data: Data([0x00, 0x01, 0x80, 0x00])
        )
        let value = try reader.readFixedPoint16x16()
        #expect(value == 1.5)
    }

    @Test("readFixedPoint8x8 — value")
    func readFixedPoint8x8() throws {
        // 1.0 = 0x0100
        var reader = BinaryReader(
            data: Data([0x01, 0x00])
        )
        let value = try reader.readFixedPoint8x8()
        #expect(value == 1.0)
    }

    // MARK: - Navigation

    @Test("skip — advances position")
    func skip() throws {
        var reader = BinaryReader(
            data: Data([1, 2, 3, 4, 5])
        )
        try reader.skip(3)
        #expect(reader.position == 3)
        let value = try reader.readUInt8()
        #expect(value == 4)
    }

    @Test("seek — absolute position")
    func seek() throws {
        var reader = BinaryReader(
            data: Data([1, 2, 3, 4, 5])
        )
        try reader.seek(to: 4)
        #expect(reader.position == 4)
        let value = try reader.readUInt8()
        #expect(value == 5)
    }

    @Test("seek — to end is valid")
    func seekToEnd() throws {
        var reader = BinaryReader(data: Data([1, 2, 3]))
        try reader.seek(to: 3)
        #expect(reader.remaining == 0)
    }

    @Test("readSubReader — independent reader")
    func readSubReader() throws {
        var reader = BinaryReader(
            data: Data([1, 2, 3, 4, 5])
        )
        try reader.skip(1)
        var sub = try reader.readSubReader(count: 3)
        #expect(sub.count == 3)
        #expect(reader.position == 4)
        let value = try sub.readUInt8()
        #expect(value == 2)
    }

    // MARK: - Error Cases

    @Test("readUInt8 — endOfData")
    func readPastEnd() {
        var reader = BinaryReader(data: Data())
        #expect(throws: BinaryReaderError.self) {
            try reader.readUInt8()
        }
    }

    @Test("readUInt32 — not enough bytes")
    func readUInt32NotEnough() {
        var reader = BinaryReader(data: Data([1, 2]))
        #expect(throws: BinaryReaderError.self) {
            try reader.readUInt32()
        }
    }

    @Test("skip — past end throws")
    func skipPastEnd() {
        var reader = BinaryReader(data: Data([1]))
        #expect(throws: BinaryReaderError.self) {
            try reader.skip(5)
        }
    }

    @Test("seek — out of bounds throws")
    func seekOutOfBounds() {
        var reader = BinaryReader(data: Data([1, 2, 3]))
        #expect(throws: BinaryReaderError.self) {
            try reader.seek(to: -1)
        }
    }

    @Test("seek — past end throws")
    func seekPastEnd() {
        var reader = BinaryReader(data: Data([1, 2, 3]))
        #expect(throws: BinaryReaderError.self) {
            try reader.seek(to: 4)
        }
    }

    @Test("sequential reads advance position correctly")
    func sequentialReads() throws {
        var reader = BinaryReader(
            data: Data([0x00, 0x01, 0x00, 0x02, 0xFF])
        )
        let a = try reader.readUInt16()
        let b = try reader.readUInt16()
        let c = try reader.readUInt8()
        #expect(a == 1)
        #expect(b == 2)
        #expect(c == 0xFF)
        #expect(reader.remaining == 0)
    }
}
