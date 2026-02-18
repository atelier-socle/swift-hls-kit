// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Reads ISOBMFF box structure from MP4 data.
///
/// Parses the box hierarchy without interpreting box-specific payloads.
/// Container boxes (moov, trak, mdia, etc.) are recursively parsed.
/// Leaf boxes store their raw payload data for later interpretation.
///
/// The `mdat` box (media data) is special: its payload is NOT loaded
/// into memory, since it can be gigabytes in size.
///
/// ```swift
/// let reader = MP4BoxReader()
/// let boxes = try reader.readBoxes(from: mp4Data)
/// let moov = boxes.first { $0.type == "moov" }
/// ```
///
/// - SeeAlso: ISO 14496-12, Section 4.2
public struct MP4BoxReader: Sendable {

    /// Creates a new MP4 box reader.
    public init() {}

    /// Read all top-level boxes from MP4 data.
    ///
    /// - Parameter data: The MP4 file data.
    /// - Returns: An array of top-level boxes.
    /// - Throws: `MP4Error` if the data is not valid ISOBMFF.
    public func readBoxes(
        from data: Data
    ) throws(MP4Error) -> [MP4Box] {
        guard !data.isEmpty else {
            throw .invalidMP4("Empty data")
        }
        do {
            var reader = BinaryReader(data: data)
            return try readBoxes(
                from: &reader,
                startOffset: 0,
                endOffset: UInt64(data.count)
            )
        } catch let error as MP4Error {
            throw error
        } catch {
            throw .invalidBoxData(
                box: "root",
                reason: error.localizedDescription
            )
        }
    }

    /// Read boxes from a file URL.
    ///
    /// - Parameter url: The file URL to read.
    /// - Returns: An array of top-level boxes.
    /// - Throws: `MP4Error` if the file cannot be read or is invalid.
    public func readBoxes(
        from url: URL
    ) throws(MP4Error) -> [MP4Box] {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .ioError(error.localizedDescription)
        }
        return try readBoxes(from: data)
    }
}

// MARK: - Box Reading

extension MP4BoxReader {

    private func readBoxes(
        from reader: inout BinaryReader,
        startOffset: UInt64,
        endOffset: UInt64
    ) throws -> [MP4Box] {
        var boxes: [MP4Box] = []
        try reader.seek(to: Int(startOffset))

        while reader.position < Int(endOffset)
            && reader.remaining >= 8
        {
            let box = try readSingleBox(
                from: &reader, containerEnd: endOffset
            )
            boxes.append(box)
        }
        return boxes
    }

    private func readSingleBox(
        from reader: inout BinaryReader,
        containerEnd: UInt64
    ) throws -> MP4Box {
        let boxOffset = UInt64(reader.position)

        // Read header
        let rawSize = try readUInt32(from: &reader, box: "header")
        let type = try readFourCC(from: &reader, box: "header")

        // Resolve actual size and header size
        let (boxSize, headerSize) = try resolveSize(
            rawSize: rawSize,
            reader: &reader,
            boxOffset: boxOffset,
            containerEnd: containerEnd,
            type: type
        )

        // Validate box size
        guard boxSize >= UInt64(headerSize) else {
            throw MP4Error.invalidBoxData(
                box: type,
                reason: "Box size \(boxSize) < header size"
            )
        }

        let payloadSize = Int(boxSize) - headerSize

        // Determine box content
        if type == MP4Box.BoxType.mdat
            || type == MP4Box.BoxType.free
            || type == MP4Box.BoxType.skip
        {
            // Large or padding boxes: skip payload
            let box = MP4Box(
                type: type, size: boxSize,
                offset: boxOffset, headerSize: headerSize,
                payload: nil, children: []
            )
            try reader.seek(to: Int(boxOffset + boxSize))
            return box
        }

        if MP4Box.BoxType.containerTypes.contains(type) {
            // Container box: parse children recursively
            let childEnd = boxOffset + boxSize
            let children = try readBoxes(
                from: &reader,
                startOffset: boxOffset + UInt64(headerSize),
                endOffset: childEnd
            )
            try reader.seek(to: Int(childEnd))
            return MP4Box(
                type: type, size: boxSize,
                offset: boxOffset, headerSize: headerSize,
                payload: nil, children: children
            )
        }

        // Leaf box: read payload
        guard payloadSize <= reader.remaining else {
            throw MP4Error.invalidBoxData(
                box: type,
                reason:
                    "Payload size \(payloadSize) exceeds "
                    + "remaining data \(reader.remaining)"
            )
        }
        let payload = try readPayload(
            from: &reader, count: payloadSize, box: type
        )
        return MP4Box(
            type: type, size: boxSize,
            offset: boxOffset, headerSize: headerSize,
            payload: payload, children: []
        )
    }
}

// MARK: - Size Resolution

extension MP4BoxReader {

    private func resolveSize(
        rawSize: UInt32,
        reader: inout BinaryReader,
        boxOffset: UInt64,
        containerEnd: UInt64,
        type: String
    ) throws -> (size: UInt64, headerSize: Int) {
        switch rawSize {
        case 1:
            // Extended size: next 8 bytes
            let extendedSize = try readUInt64(
                from: &reader, box: type
            )
            return (extendedSize, 16)
        case 0:
            // Box extends to end of container
            return (containerEnd - boxOffset, 8)
        default:
            return (UInt64(rawSize), 8)
        }
    }
}

// MARK: - Error-Wrapped Reading

extension MP4BoxReader {

    private func readUInt32(
        from reader: inout BinaryReader, box: String
    ) throws -> UInt32 {
        do {
            return try reader.readUInt32()
        } catch {
            throw MP4Error.invalidBoxData(
                box: box,
                reason: "Cannot read UInt32: \(error)"
            )
        }
    }

    private func readUInt64(
        from reader: inout BinaryReader, box: String
    ) throws -> UInt64 {
        do {
            return try reader.readUInt64()
        } catch {
            throw MP4Error.invalidBoxData(
                box: box,
                reason: "Cannot read UInt64: \(error)"
            )
        }
    }

    private func readFourCC(
        from reader: inout BinaryReader, box: String
    ) throws -> String {
        do {
            return try reader.readFourCC()
        } catch {
            throw MP4Error.invalidBoxData(
                box: box,
                reason: "Cannot read FourCC: \(error)"
            )
        }
    }

    private func readPayload(
        from reader: inout BinaryReader, count: Int,
        box: String
    ) throws -> Data {
        do {
            return try reader.readBytes(count)
        } catch {
            throw MP4Error.invalidBoxData(
                box: box,
                reason: "Cannot read payload: \(error)"
            )
        }
    }
}
