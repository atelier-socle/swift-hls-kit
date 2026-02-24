// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Parses ADTS (Audio Data Transport Stream) frames from a byte stream.
///
/// ADTS wraps raw AAC frames with headers containing sync words, codec info,
/// and frame lengths. This parser extracts individual frames from a continuous
/// byte stream, handling partial data gracefully.
///
/// Compatible with ``ADTSConverter.AACConfig`` for codec parameter extraction.
///
/// ## Usage
/// ```swift
/// let parser = ADTSParser()
/// let result = parser.parseFrames(from: adtsData)
/// for frame in result.frames {
///     print("Frame: \(frame.payload.count) bytes at \(frame.sampleRate) Hz")
/// }
/// // Carry over unconsumed bytes for next parse call
/// let remaining = adtsData.suffix(from: adtsData.startIndex + result.bytesConsumed)
/// ```
///
/// - SeeAlso: ISO 14496-3, Section 1.A.2.2
public struct ADTSParser: Sendable {

    /// Creates an ADTS parser.
    public init() {}

    /// Result of parsing ADTS data.
    public struct ParseResult: Sendable {

        /// Parsed ADTS frames.
        public let frames: [ADTSFrame]

        /// Number of bytes consumed from the input data.
        public let bytesConsumed: Int
    }

    /// Parses ADTS frames from the given data.
    ///
    /// Scans for 0xFFF sync words, validates headers, and extracts complete
    /// frames. Stops when the remaining data is too short for a complete frame.
    ///
    /// - Parameter data: Raw ADTS byte stream.
    /// - Returns: Parsed frames and the number of bytes consumed.
    public func parseFrames(from data: Data) -> ParseResult {
        var frames: [ADTSFrame] = []
        var offset = data.startIndex
        let end = data.endIndex

        while offset < end {
            // Need at least 7 bytes for the minimum ADTS header
            guard offset + 7 <= end else { break }

            // Check sync word: 12 bits = 0xFFF
            let byte0 = data[offset]
            let byte1 = data[offset + 1]
            guard byte0 == 0xFF, (byte1 & 0xF0) == 0xF0 else {
                // Not a sync word — skip one byte and try again
                offset += 1
                continue
            }

            // Protection absent bit (bit 0 of byte 1): 1 = no CRC, 0 = CRC present
            let protectionAbsent = (byte1 & 0x01) == 1
            let headerSize = protectionAbsent ? 7 : 9

            guard offset + headerSize <= end else { break }

            // Parse header fields
            let byte2 = data[offset + 2]
            let byte3 = data[offset + 3]
            let byte4 = data[offset + 4]
            let byte5 = data[offset + 5]

            // Profile: 2 bits at byte2[7:6] (MPEG-4 Audio Object Type - 1)
            let profile = (byte2 >> 6) & 0x03

            // Sample rate index: 4 bits at byte2[5:2]
            let sampleRateIndex = (byte2 >> 2) & 0x0F

            // Channel configuration: 3 bits split across byte2[0] and byte3[7:6]
            let channelConfig = ((byte2 & 0x01) << 2) | ((byte3 >> 6) & 0x03)

            // Frame length: 13 bits across byte3[1:0], byte4[7:0], byte5[7:5]
            let frameLength =
                (Int(byte3 & 0x03) << 11)
                | (Int(byte4) << 3)
                | (Int(byte5 >> 5) & 0x07)

            // Validate frame length
            guard frameLength >= headerSize, offset + frameLength <= end else {
                break
            }

            // Extract payload (frame data after header)
            let payloadStart = offset + headerSize
            let payloadEnd = offset + frameLength
            let payload = Data(data[payloadStart..<payloadEnd])

            // Look up sample rate
            let sampleRate = Self.sampleRateTable[Int(sampleRateIndex)]

            let frame = ADTSFrame(
                payload: payload,
                profile: profile,
                sampleRateIndex: sampleRateIndex,
                sampleRate: sampleRate,
                channelConfig: channelConfig,
                frameLength: frameLength,
                headerSize: headerSize
            )

            frames.append(frame)
            offset += frameLength
        }

        return ParseResult(
            frames: frames,
            bytesConsumed: offset - data.startIndex
        )
    }
}

// MARK: - ADTSFrame

/// A single ADTS frame parsed from the byte stream.
public struct ADTSFrame: Sendable {

    /// Raw AAC payload (without the ADTS header).
    public let payload: Data

    /// AAC profile (0 = Main, 1 = LC, 2 = SSR, 3 = LTP).
    public let profile: UInt8

    /// Sample rate frequency index (ISO 14496-3 table).
    public let sampleRateIndex: UInt8

    /// Sample rate in Hz (resolved from the index).
    public let sampleRate: Int

    /// Channel configuration (1 = mono, 2 = stereo, etc.).
    public let channelConfig: UInt8

    /// Total frame length in bytes (header + payload).
    public let frameLength: Int

    /// Header size in bytes (7 without CRC, 9 with CRC).
    public let headerSize: Int
}

// MARK: - Sample Rate Table

extension ADTSParser {

    /// ISO 14496-3 sample rate frequency index table.
    static let sampleRateTable: [Int] = [
        96_000,  // 0x0
        88_200,  // 0x1
        64_000,  // 0x2
        48_000,  // 0x3
        44_100,  // 0x4
        32_000,  // 0x5
        24_000,  // 0x6
        22_050,  // 0x7
        16_000,  // 0x8
        12_000,  // 0x9
        11_025,  // 0xA
        8_000,  // 0xB
        7_350,  // 0xC
        0,  // 0xD (reserved)
        0,  // 0xE (reserved)
        0  // 0xF (escape value)
    ]
}
