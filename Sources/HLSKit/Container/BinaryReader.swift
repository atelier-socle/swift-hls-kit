// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors that can occur during binary reading.
public enum BinaryReaderError: Error, Sendable, Hashable {

    /// Attempted to read past the end of data.
    case endOfData(needed: Int, available: Int)

    /// Invalid data format.
    case invalidData(String)
}

// MARK: - LocalizedError

extension BinaryReaderError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .endOfData(let needed, let available):
            return
                "End of data: needed \(needed) bytes, "
                + "\(available) available"
        case .invalidData(let detail):
            return "Invalid data: \(detail)"
        }
    }
}

// MARK: - BinaryReader

/// Low-level binary reader for ISOBMFF parsing.
///
/// Reads big-endian data from a byte buffer, tracking position.
/// All MP4 data is big-endian (network byte order).
///
/// ```swift
/// var reader = BinaryReader(data: mp4Data)
/// let size = try reader.readUInt32()
/// let type = try reader.readFourCC()
/// ```
public struct BinaryReader: Sendable {

    private let data: Data

    /// Current read position (byte offset from start).
    public private(set) var position: Int

    /// Total bytes available.
    public var count: Int { data.count }

    /// Bytes remaining from current position.
    public var remaining: Int { data.count - position }

    /// Whether there are more bytes to read.
    public var hasRemaining: Bool { position < data.count }

    /// Initialize with raw bytes.
    ///
    /// - Parameter data: The binary data to read from.
    public init(data: Data) {
        self.data = data
        self.position = 0
    }
}

// MARK: - Integer Reading (Big-Endian)

extension BinaryReader {

    /// Read a UInt8.
    public mutating func readUInt8() throws(BinaryReaderError) -> UInt8 {
        try ensureAvailable(1)
        let value = data[data.startIndex + position]
        position += 1
        return value
    }

    /// Read a big-endian UInt16.
    public mutating func readUInt16() throws(BinaryReaderError) -> UInt16 {
        try ensureAvailable(2)
        let s = data.startIndex + position
        let value =
            UInt16(data[s]) << 8
            | UInt16(data[s + 1])
        position += 2
        return value
    }

    /// Read a big-endian UInt32.
    public mutating func readUInt32() throws(BinaryReaderError) -> UInt32 {
        try ensureAvailable(4)
        let s = data.startIndex + position
        let value =
            UInt32(data[s]) << 24
            | UInt32(data[s + 1]) << 16
            | UInt32(data[s + 2]) << 8
            | UInt32(data[s + 3])
        position += 4
        return value
    }

    /// Read a big-endian UInt64.
    public mutating func readUInt64() throws(BinaryReaderError) -> UInt64 {
        try ensureAvailable(8)
        let s = data.startIndex + position
        var value: UInt64 = 0
        for i in 0..<8 {
            value = (value << 8) | UInt64(data[s + i])
        }
        position += 8
        return value
    }

    /// Read a big-endian Int32.
    public mutating func readInt32() throws(BinaryReaderError) -> Int32 {
        Int32(bitPattern: try readUInt32())
    }

    /// Read a big-endian Int64.
    public mutating func readInt64() throws(BinaryReaderError) -> Int64 {
        Int64(bitPattern: try readUInt64())
    }
}

// MARK: - Other Types

extension BinaryReader {

    /// Read a 4-byte ASCII string (box type).
    public mutating func readFourCC() throws(BinaryReaderError) -> String {
        let bytes = try readBytes(4)
        guard let str = String(data: bytes, encoding: .ascii) else {
            throw .invalidData("Invalid FourCC encoding")
        }
        return str
    }

    /// Read a fixed number of bytes.
    public mutating func readBytes(
        _ count: Int
    ) throws(BinaryReaderError) -> Data {
        try ensureAvailable(count)
        let start = data.startIndex + position
        let result = data[start..<(start + count)]
        position += count
        return Data(result)
    }

    /// Read a null-terminated string.
    public mutating func readNullTerminatedString()
        throws(BinaryReaderError) -> String
    {
        let start = data.startIndex + position
        var end = start
        while end < data.endIndex && data[end] != 0 {
            end += 1
        }
        let bytes = data[start..<end]
        guard let str = String(data: bytes, encoding: .utf8) else {
            throw .invalidData("Invalid UTF-8 in string")
        }
        // Skip past the null terminator if present
        position = end - data.startIndex
        if end < data.endIndex {
            position += 1
        }
        return str
    }

    /// Read a fixed-point 16.16 number as Double.
    public mutating func readFixedPoint16x16()
        throws(BinaryReaderError) -> Double
    {
        let raw = try readInt32()
        return Double(raw) / 65536.0
    }

    /// Read a fixed-point 8.8 number as Double.
    public mutating func readFixedPoint8x8()
        throws(BinaryReaderError) -> Double
    {
        let raw = try readUInt16()
        return Double(raw) / 256.0
    }
}

// MARK: - Navigation

extension BinaryReader {

    /// Skip forward by count bytes.
    public mutating func skip(
        _ count: Int
    ) throws(BinaryReaderError) {
        try ensureAvailable(count)
        position += count
    }

    /// Seek to an absolute position.
    public mutating func seek(
        to position: Int
    ) throws(BinaryReaderError) {
        guard position >= 0, position <= data.count else {
            throw .endOfData(
                needed: position,
                available: data.count
            )
        }
        self.position = position
    }

    /// Read a sub-range as a new BinaryReader.
    public mutating func readSubReader(
        count: Int
    ) throws(BinaryReaderError) -> BinaryReader {
        let subData = try readBytes(count)
        return BinaryReader(data: subData)
    }
}

// MARK: - Private

extension BinaryReader {

    private func ensureAvailable(
        _ needed: Int
    ) throws(BinaryReaderError) {
        guard remaining >= needed else {
            throw .endOfData(
                needed: needed, available: remaining
            )
        }
    }
}
