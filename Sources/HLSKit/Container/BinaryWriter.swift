// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Low-level binary writer for ISOBMFF box construction.
///
/// Writes big-endian data to a growing buffer. This is the
/// inverse of `BinaryReader`.
///
/// ```swift
/// var writer = BinaryWriter()
/// writer.writeUInt32(42)
/// writer.writeFourCC("moov")
/// let data = writer.data
/// ```
public struct BinaryWriter: Sendable {

    /// The accumulated output data.
    public private(set) var data: Data

    /// Current byte count written.
    public var count: Int { data.count }

    /// Creates a new binary writer with an empty buffer.
    public init() {
        data = Data()
    }

    /// Creates a new binary writer with pre-allocated capacity.
    ///
    /// - Parameter capacity: Expected byte count for the output.
    public init(capacity: Int) {
        data = Data()
        data.reserveCapacity(capacity)
    }
}

// MARK: - Integer Writing (Big-Endian)

extension BinaryWriter {

    /// Write a single byte.
    public mutating func writeUInt8(_ value: UInt8) {
        data.append(value)
    }

    /// Write a 16-bit unsigned integer in big-endian.
    public mutating func writeUInt16(_ value: UInt16) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    /// Write a 32-bit unsigned integer in big-endian.
    public mutating func writeUInt32(_ value: UInt32) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    /// Write a 64-bit unsigned integer in big-endian.
    public mutating func writeUInt64(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            data.append(UInt8((value >> shift) & 0xFF))
        }
    }

    /// Write a 32-bit signed integer in big-endian.
    public mutating func writeInt32(_ value: Int32) {
        writeUInt32(UInt32(bitPattern: value))
    }

    /// Write a 64-bit signed integer in big-endian.
    public mutating func writeInt64(_ value: Int64) {
        writeUInt64(UInt64(bitPattern: value))
    }
}

// MARK: - Other Types

extension BinaryWriter {

    /// Write a 4-byte ASCII box type string.
    ///
    /// Pads with spaces if the string is shorter than 4 characters.
    ///
    /// - Parameter value: The four-character code to write.
    public mutating func writeFourCC(_ value: String) {
        let ascii = value.prefix(4)
        for char in ascii {
            data.append(char.asciiValue ?? 0x20)
        }
        for _ in ascii.count..<4 {
            data.append(0x20)
        }
    }

    /// Write raw bytes.
    ///
    /// - Parameter bytes: The data to append.
    public mutating func writeData(_ bytes: Data) {
        data.append(bytes)
    }

    /// Write zero bytes for padding.
    ///
    /// - Parameter count: Number of zero bytes to write.
    public mutating func writeZeros(_ count: Int) {
        guard count > 0 else { return }
        data.append(Data(repeating: 0, count: count))
    }

    /// Write a fixed-point 16.16 number.
    ///
    /// - Parameter value: The floating-point value to encode.
    public mutating func writeFixedPoint16x16(_ value: Double) {
        let fixed = Int32(value * 65536.0)
        writeUInt32(UInt32(bitPattern: fixed))
    }
}

// MARK: - Box Helpers

extension BinaryWriter {

    /// Write a complete ISOBMFF box (header + payload).
    ///
    /// Uses standard 32-bit size for boxes up to `UInt32.max` bytes.
    /// Falls back to 64-bit extended size for larger payloads.
    ///
    /// - Parameters:
    ///   - type: Four-character box type (e.g. "ftyp").
    ///   - payload: Box payload data.
    public mutating func writeBox(type: String, payload: Data) {
        let totalSize = 8 + payload.count
        if totalSize <= Int(UInt32.max) {
            writeUInt32(UInt32(totalSize))
            writeFourCC(type)
            writeData(payload)
        } else {
            let extendedSize = UInt64(16 + payload.count)
            writeUInt32(1)  // marker for extended size
            writeFourCC(type)
            writeUInt64(extendedSize)
            writeData(payload)
        }
    }

    /// Write a full box (header + version + flags + payload).
    ///
    /// A "full box" adds a 4-byte version/flags field after the header.
    ///
    /// - Parameters:
    ///   - type: Four-character box type.
    ///   - version: Box version (0 or 1).
    ///   - flags: 24-bit flags value.
    ///   - payload: Box payload after version/flags.
    public mutating func writeFullBox(
        type: String,
        version: UInt8,
        flags: UInt32,
        payload: Data
    ) {
        var fullPayload = Data(capacity: 4 + payload.count)
        fullPayload.append(version)
        fullPayload.append(UInt8((flags >> 16) & 0xFF))
        fullPayload.append(UInt8((flags >> 8) & 0xFF))
        fullPayload.append(UInt8(flags & 0xFF))
        fullPayload.append(payload)
        writeBox(type: type, payload: fullPayload)
    }

    /// Write a container box with child boxes.
    ///
    /// - Parameters:
    ///   - type: Four-character container type (e.g. "moov").
    ///   - children: Child box data to concatenate.
    public mutating func writeContainerBox(
        type: String,
        children: [Data]
    ) {
        var payload = Data()
        for child in children {
            payload.append(child)
        }
        writeBox(type: type, payload: payload)
    }
}
