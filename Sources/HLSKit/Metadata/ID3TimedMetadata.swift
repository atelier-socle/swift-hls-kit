// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Creates ID3v2 timed metadata for injection into HLS segments.
///
/// For MPEG-TS segments: injected as private PES packets (stream type 0x15).
/// For fMP4 segments: wrapped in Event Message Box (emsg).
///
/// Common use cases:
/// - Track title/artist in audio streams (TIT2, TPE1)
/// - Custom metadata via TXXX frames
/// - Synchronized lyrics, chapter markers
///
/// ```swift
/// var metadata = ID3TimedMetadata()
/// metadata.addTextFrame(.title, value: "Episode 42: The Answer")
/// metadata.addTextFrame(.artist, value: "The Podcast")
/// metadata.addCustomFrame(description: "chapter", value: "Introduction")
/// let id3Data = metadata.serialize()
/// ```
public struct ID3TimedMetadata: Sendable, Equatable {

    // MARK: - Types

    /// Standard ID3v2 text frame identifiers.
    public enum FrameID: String, Sendable, Equatable, CaseIterable {
        /// Track title.
        case title = "TIT2"
        /// Artist/performer.
        case artist = "TPE1"
        /// Album name.
        case album = "TALB"
        /// Recording date.
        case year = "TDRC"
        /// Genre.
        case genre = "TCON"
        /// Track number.
        case trackNumber = "TRCK"
        /// Comment.
        case comment = "COMM"
    }

    /// A single ID3v2 frame.
    public struct Frame: Sendable, Equatable {

        /// 4-character frame identifier.
        public let id: String

        /// Frame payload (encoding byte + text data).
        public let value: Data

        /// Text encoding used for this frame.
        public let encoding: TextEncoding

        /// ID3v2.4 text encoding types.
        public enum TextEncoding: UInt8, Sendable, Equatable {
            /// ISO 8859-1 (Latin-1).
            case iso88591 = 0
            /// UTF-16 with BOM.
            case utf16 = 1
            /// UTF-16BE without BOM.
            case utf16be = 2
            /// UTF-8.
            case utf8 = 3
        }
    }

    // MARK: - Properties

    /// Presentation timestamp for this metadata (seconds).
    public var presentationTime: TimeInterval

    /// Frames in this metadata tag.
    public private(set) var frames: [Frame]

    /// Creates empty timed metadata.
    ///
    /// - Parameter presentationTime: Presentation timestamp in seconds.
    public init(presentationTime: TimeInterval = 0) {
        self.presentationTime = presentationTime
        self.frames = []
    }

    // MARK: - Frame Construction

    /// Add a standard text frame.
    ///
    /// - Parameters:
    ///   - frameID: The standard frame identifier.
    ///   - value: Text value for the frame.
    ///   - encoding: Text encoding (defaults to UTF-8).
    public mutating func addTextFrame(
        _ frameID: FrameID,
        value: String,
        encoding: Frame.TextEncoding = .utf8
    ) {
        var payload = Data()
        payload.append(encoding.rawValue)
        payload.append(contentsOf: encodeString(value, encoding: encoding))
        frames.append(Frame(id: frameID.rawValue, value: payload, encoding: encoding))
    }

    /// Add a custom TXXX frame.
    ///
    /// - Parameters:
    ///   - description: Description field for the custom frame.
    ///   - value: Text value for the frame.
    ///   - encoding: Text encoding (defaults to UTF-8).
    public mutating func addCustomFrame(
        description: String,
        value: String,
        encoding: Frame.TextEncoding = .utf8
    ) {
        var payload = Data()
        payload.append(encoding.rawValue)
        payload.append(contentsOf: encodeString(description, encoding: encoding))
        payload.append(0x00)  // null separator
        payload.append(contentsOf: encodeString(value, encoding: encoding))
        frames.append(Frame(id: "TXXX", value: payload, encoding: encoding))
    }

    /// Add a raw data frame.
    ///
    /// - Parameters:
    ///   - id: 4-character frame identifier.
    ///   - data: Raw frame payload.
    public mutating func addRawFrame(id: String, data: Data) {
        frames.append(Frame(id: id, value: data, encoding: .iso88591))
    }

    // MARK: - Serialization

    /// Serialize to ID3v2.4 binary data.
    ///
    /// Returns a complete ID3v2 tag with header and all frames.
    public func serialize() -> Data {
        let framesData = serializeFrames()
        var writer = BinaryWriter(capacity: 10 + framesData.count)
        // ID3v2 header
        writer.writeData(Data("ID3".utf8))
        writer.writeUInt8(0x04)  // version major: ID3v2.4
        writer.writeUInt8(0x00)  // version minor
        writer.writeUInt8(0x00)  // flags
        writeSynchsafe(&writer, UInt32(framesData.count))
        writer.writeData(framesData)
        return writer.data
    }

    /// Serialize as an Event Message Box (emsg) for fMP4.
    ///
    /// Uses scheme_id_uri `https://aomedia.org/emsg/ID3` (CMAF standard).
    ///
    /// - Parameter timescale: Timescale for timestamp calculation.
    /// - Returns: Complete emsg box data.
    public func serializeAsEmsg(timescale: UInt32 = 90_000) -> Data {
        let id3Data = serialize()
        let schemeURI = "https://aomedia.org/emsg/ID3"
        let presentationDelta = UInt64(presentationTime * Double(timescale))

        var payload = BinaryWriter(capacity: 256)
        // emsg version 1
        payload.writeUInt32(timescale)
        payload.writeUInt64(presentationDelta)  // presentation_time
        payload.writeUInt32(0)  // event_duration (unknown)
        payload.writeUInt32(0)  // id
        payload.writeData(Data(schemeURI.utf8))
        payload.writeUInt8(0x00)  // null terminator
        payload.writeUInt8(0x00)  // empty value string null terminator
        payload.writeData(id3Data)

        var box = BinaryWriter(capacity: 12 + payload.count)
        box.writeFullBox(
            type: "emsg",
            version: 1,
            flags: 0,
            payload: payload.data
        )
        return box.data
    }

    // MARK: - Parsing

    /// Parse ID3v2 data back into a structured metadata object.
    ///
    /// - Parameter data: Raw ID3v2 binary data.
    /// - Returns: Parsed metadata, or nil if data is invalid.
    public static func parse(from data: Data) -> ID3TimedMetadata? {
        guard data.count >= 10 else { return nil }
        // Verify "ID3" magic
        guard data[0] == 0x49, data[1] == 0x44, data[2] == 0x33 else {
            return nil
        }
        // Version check (2.4.x)
        guard data[3] == 0x04 else { return nil }

        let tagSize = readSynchsafe(data, offset: 6)
        guard data.count >= 10 + Int(tagSize) else { return nil }

        var metadata = ID3TimedMetadata()
        var offset = 10
        let endOffset = 10 + Int(tagSize)

        while offset + 10 <= endOffset {
            let frameID = String(
                bytes: data[offset..<(offset + 4)],
                encoding: .ascii
            )
            guard let frameID, frameID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else {
                break
            }
            let frameSize = Int(readSynchsafe(data, offset: offset + 4))
            // Skip 2-byte frame flags
            let frameDataStart = offset + 10
            guard frameDataStart + frameSize <= endOffset else { break }

            let frameData = Data(data[frameDataStart..<(frameDataStart + frameSize)])
            let encoding: Frame.TextEncoding
            if !frameData.isEmpty, let enc = Frame.TextEncoding(rawValue: frameData[0]) {
                encoding = enc
            } else {
                encoding = .iso88591
            }
            metadata.frames.append(
                Frame(id: frameID, value: frameData, encoding: encoding)
            )
            offset = frameDataStart + frameSize
        }

        return metadata
    }

    // MARK: - Private Helpers

    private func serializeFrames() -> Data {
        var writer = BinaryWriter()
        for frame in frames {
            // Frame ID (4 bytes)
            writer.writeData(Data(frame.id.prefix(4).utf8))
            // Frame size (synchsafe)
            writeSynchsafe(&writer, UInt32(frame.value.count))
            // Frame flags (2 bytes, all zero)
            writer.writeUInt16(0)
            // Frame payload
            writer.writeData(frame.value)
        }
        return writer.data
    }

    private func encodeString(
        _ string: String, encoding: Frame.TextEncoding
    ) -> Data {
        switch encoding {
        case .utf8:
            return Data(string.utf8)
        case .iso88591:
            return string.data(using: .isoLatin1) ?? Data(string.utf8)
        case .utf16:
            // BOM + UTF-16
            var result = Data([0xFF, 0xFE])  // BOM little-endian
            if let encoded = string.data(using: .utf16LittleEndian) {
                result.append(encoded)
            }
            return result
        case .utf16be:
            return string.data(using: .utf16BigEndian) ?? Data(string.utf8)
        }
    }

    private func writeSynchsafe(
        _ writer: inout BinaryWriter, _ value: UInt32
    ) {
        Self.writeSynchsafeInteger(&writer, value)
    }

    /// Encode a value as a 4-byte synchsafe integer.
    static func writeSynchsafeInteger(
        _ writer: inout BinaryWriter, _ value: UInt32
    ) {
        writer.writeUInt8(UInt8((value >> 21) & 0x7F))
        writer.writeUInt8(UInt8((value >> 14) & 0x7F))
        writer.writeUInt8(UInt8((value >> 7) & 0x7F))
        writer.writeUInt8(UInt8(value & 0x7F))
    }

    /// Read a 4-byte synchsafe integer from data at offset.
    static func readSynchsafe(_ data: Data, offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset]) & 0x7F
        let b1 = UInt32(data[offset + 1]) & 0x7F
        let b2 = UInt32(data[offset + 2]) & 0x7F
        let b3 = UInt32(data[offset + 3]) & 0x7F
        return (b0 << 21) | (b1 << 14) | (b2 << 7) | b3
    }
}
