// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates MPEG-TS Program Specific Information (PSI) tables.
///
/// Creates PAT (Program Association Table) and PMT (Program Map Table)
/// for HLS transport streams.
///
/// - SeeAlso: ISO 13818-1, Section 2.4.4
public struct ProgramTableGenerator: Sendable {

    /// Creates a new program table generator.
    public init() {}

    /// Stream type codes for PMT.
    public enum StreamType: UInt8, Sendable, Hashable {
        /// H.264 / AVC.
        case h264 = 0x1B
        /// H.265 / HEVC.
        case h265 = 0x24
        /// AAC (ADTS).
        case aac = 0x0F
        /// MPEG-1 Audio (MP3).
        case mp3 = 0x03
    }

    /// A stream entry for the PMT.
    public struct StreamEntry: Sendable, Hashable {
        /// The stream type code.
        public let streamType: StreamType
        /// The PID for this elementary stream.
        public let pid: UInt16

        /// Creates a stream entry.
        ///
        /// - Parameters:
        ///   - streamType: The stream type code.
        ///   - pid: The PID for this elementary stream.
        public init(streamType: StreamType, pid: UInt16) {
            self.streamType = streamType
            self.pid = pid
        }
    }

    /// Generate a PAT section.
    ///
    /// - Parameters:
    ///   - transportStreamId: TS ID (default: 1).
    ///   - programNumber: Program number (default: 1).
    ///   - pmtPid: PID of the PMT (default: 0x0100).
    /// - Returns: Complete PAT section data (including CRC-32).
    public func generatePAT(
        transportStreamId: UInt16 = 1,
        programNumber: UInt16 = 1,
        pmtPid: UInt16 = TSPacket.PID.pmt
    ) -> Data {
        var section = Data()

        // table_id: 0x00 (PAT)
        section.append(0x00)

        // section_syntax_indicator(1) + 0(1) + reserved(2)
        // + section_length(12)
        // Section length = 5 (header after length) + 4 (entry) + 4 (CRC)
        let sectionLength: UInt16 = 5 + 4 + 4
        let lengthHigh = UInt8(
            0x80 | 0x30 | ((sectionLength >> 8) & 0x0F)
        )
        section.append(lengthHigh)
        section.append(UInt8(sectionLength & 0xFF))

        // transport_stream_id
        section.append(UInt8((transportStreamId >> 8) & 0xFF))
        section.append(UInt8(transportStreamId & 0xFF))

        // reserved(2) + version_number(5) + current_next(1)
        // version=0, current_next=1
        section.append(0xC1)

        // section_number
        section.append(0x00)

        // last_section_number
        section.append(0x00)

        // Program entry: program_number(2) + reserved(3)
        // + program_map_PID(13)
        section.append(UInt8((programNumber >> 8) & 0xFF))
        section.append(UInt8(programNumber & 0xFF))
        let pmtPidHigh = UInt8(0xE0 | ((pmtPid >> 8) & 0x1F))
        section.append(pmtPidHigh)
        section.append(UInt8(pmtPid & 0xFF))

        // CRC-32
        let crc = crc32MPEG2(section)
        section.append(UInt8((crc >> 24) & 0xFF))
        section.append(UInt8((crc >> 16) & 0xFF))
        section.append(UInt8((crc >> 8) & 0xFF))
        section.append(UInt8(crc & 0xFF))

        return section
    }

    /// Generate a PMT section.
    ///
    /// - Parameters:
    ///   - programNumber: Program number (default: 1).
    ///   - pcrPid: PID that carries PCR (typically video PID).
    ///   - streams: Elementary stream entries.
    /// - Returns: Complete PMT section data (including CRC-32).
    public func generatePMT(
        programNumber: UInt16 = 1,
        pcrPid: UInt16 = TSPacket.PID.video,
        streams: [StreamEntry]
    ) -> Data {
        var section = Data()

        // table_id: 0x02 (PMT)
        section.append(0x02)

        // Each stream entry: stream_type(1) + reserved(3) + PID(13)
        // = 2 bytes for PID + 1 for type + ES_info_length(2) = 5
        let streamDataLength = streams.count * 5
        // section_length = 5 (header) + 4 (PCR + info_length)
        //                + streamData + 4 (CRC)
        let sectionLength = UInt16(5 + 4 + streamDataLength + 4)
        let lengthHigh = UInt8(
            0x80 | 0x30 | ((sectionLength >> 8) & 0x0F)
        )
        section.append(lengthHigh)
        section.append(UInt8(sectionLength & 0xFF))

        // program_number
        section.append(UInt8((programNumber >> 8) & 0xFF))
        section.append(UInt8(programNumber & 0xFF))

        // reserved(2) + version_number(5) + current_next(1)
        section.append(0xC1)

        // section_number
        section.append(0x00)

        // last_section_number
        section.append(0x00)

        // reserved(3) + PCR_PID(13)
        let pcrPidHigh = UInt8(0xE0 | ((pcrPid >> 8) & 0x1F))
        section.append(pcrPidHigh)
        section.append(UInt8(pcrPid & 0xFF))

        // reserved(4) + program_info_length(12) = 0
        section.append(0xF0)
        section.append(0x00)

        // Stream entries
        for stream in streams {
            // stream_type
            section.append(stream.streamType.rawValue)
            // reserved(3) + elementary_PID(13)
            let esPidHigh = UInt8(
                0xE0 | ((stream.pid >> 8) & 0x1F)
            )
            section.append(esPidHigh)
            section.append(UInt8(stream.pid & 0xFF))
            // reserved(4) + ES_info_length(12) = 0
            section.append(0xF0)
            section.append(0x00)
        }

        // CRC-32
        let crc = crc32MPEG2(section)
        section.append(UInt8((crc >> 24) & 0xFF))
        section.append(UInt8((crc >> 16) & 0xFF))
        section.append(UInt8((crc >> 8) & 0xFF))
        section.append(UInt8(crc & 0xFF))

        return section
    }
}

// MARK: - CRC-32/MPEG-2

/// Calculate MPEG-2 CRC-32 for PSI sections.
///
/// Uses polynomial 0x04C11DB7 as specified in ISO 13818-1.
/// Initial value: 0xFFFFFFFF. No final XOR. No bit reversal.
///
/// - Parameter data: The data to compute CRC over.
/// - Returns: CRC-32 value.
public func crc32MPEG2(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0xFFFF_FFFF
    for byte in data {
        crc ^= UInt32(byte) << 24
        for _ in 0..<8 {
            if crc & 0x8000_0000 != 0 {
                crc = (crc << 1) ^ 0x04C1_1DB7
            } else {
                crc = crc << 1
            }
        }
    }
    return crc
}
