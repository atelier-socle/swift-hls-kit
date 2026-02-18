// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ProgramTables")
struct ProgramTableTests {

    // MARK: - PAT

    @Test("PAT: table_id is 0x00")
    func patTableId() {
        let gen = ProgramTableGenerator()
        let pat = gen.generatePAT()
        #expect(pat[0] == 0x00)
    }

    @Test("PAT: section includes program entry with PMT PID")
    func patProgramEntry() {
        let gen = ProgramTableGenerator()
        let pat = gen.generatePAT(pmtPid: 0x0100)
        // Program number at offset 8-9, PMT PID at 10-11
        let programNumber =
            UInt16(pat[8]) << 8
            | UInt16(pat[9])
        #expect(programNumber == 1)
        let pmtPid =
            UInt16(pat[10] & 0x1F) << 8
            | UInt16(pat[11])
        #expect(pmtPid == 0x0100)
    }

    @Test("PAT: CRC-32 is valid")
    func patCRCValid() {
        let gen = ProgramTableGenerator()
        let pat = gen.generatePAT()
        // CRC covers everything except the last 4 bytes
        let dataWithoutCRC = pat[0..<(pat.count - 4)]
        let computedCRC = crc32MPEG2(Data(dataWithoutCRC))
        let storedCRC =
            UInt32(pat[pat.count - 4]) << 24
            | UInt32(pat[pat.count - 3]) << 16
            | UInt32(pat[pat.count - 2]) << 8
            | UInt32(pat[pat.count - 1])
        #expect(computedCRC == storedCRC)
    }

    @Test("PAT: custom transport stream ID and program number")
    func patCustomValues() {
        let gen = ProgramTableGenerator()
        let pat = gen.generatePAT(
            transportStreamId: 42,
            programNumber: 7,
            pmtPid: 0x0200
        )
        // transport_stream_id at offset 3-4
        let tsId = UInt16(pat[3]) << 8 | UInt16(pat[4])
        #expect(tsId == 42)
        // program_number at offset 8-9
        let progNum = UInt16(pat[8]) << 8 | UInt16(pat[9])
        #expect(progNum == 7)
        // PMT PID at offset 10-11
        let pmtPid =
            UInt16(pat[10] & 0x1F) << 8
            | UInt16(pat[11])
        #expect(pmtPid == 0x0200)
    }

    // MARK: - PMT

    @Test("PMT: table_id is 0x02")
    func pmtTableId() {
        let gen = ProgramTableGenerator()
        let pmt = gen.generatePMT(streams: [
            .init(streamType: .h264, pid: 0x0101)
        ])
        #expect(pmt[0] == 0x02)
    }

    @Test("PMT: PCR PID matches specified PID")
    func pmtPCRPid() {
        let gen = ProgramTableGenerator()
        let pmt = gen.generatePMT(
            pcrPid: 0x0101,
            streams: [
                .init(streamType: .h264, pid: 0x0101)
            ]
        )
        // PCR_PID at offset 8-9
        let pcrPid =
            UInt16(pmt[8] & 0x1F) << 8
            | UInt16(pmt[9])
        #expect(pcrPid == 0x0101)
    }

    @Test("PMT: stream entries match input (types and PIDs)")
    func pmtStreamEntries() {
        let gen = ProgramTableGenerator()
        let pmt = gen.generatePMT(streams: [
            .init(streamType: .h264, pid: 0x0101),
            .init(streamType: .aac, pid: 0x0102)
        ])
        // After header (12 bytes): stream entries at offset 12
        let videoType = pmt[12]
        #expect(videoType == 0x1B)
        let videoPid =
            UInt16(pmt[13] & 0x1F) << 8
            | UInt16(pmt[14])
        #expect(videoPid == 0x0101)

        let audioType = pmt[17]
        #expect(audioType == 0x0F)
        let audioPid =
            UInt16(pmt[18] & 0x1F) << 8
            | UInt16(pmt[19])
        #expect(audioPid == 0x0102)
    }

    @Test("PMT: CRC-32 is valid")
    func pmtCRCValid() {
        let gen = ProgramTableGenerator()
        let pmt = gen.generatePMT(streams: [
            .init(streamType: .h264, pid: 0x0101)
        ])
        let dataWithoutCRC = pmt[0..<(pmt.count - 4)]
        let computedCRC = crc32MPEG2(Data(dataWithoutCRC))
        let storedCRC =
            UInt32(pmt[pmt.count - 4]) << 24
            | UInt32(pmt[pmt.count - 3]) << 16
            | UInt32(pmt[pmt.count - 2]) << 8
            | UInt32(pmt[pmt.count - 1])
        #expect(computedCRC == storedCRC)
    }

    @Test("PMT: video + audio streams")
    func pmtVideoAndAudio() {
        let gen = ProgramTableGenerator()
        let pmt = gen.generatePMT(streams: [
            .init(streamType: .h264, pid: 0x0101),
            .init(streamType: .aac, pid: 0x0102)
        ])
        // Should have valid CRC (implying correct structure)
        let dataWithoutCRC = pmt[0..<(pmt.count - 4)]
        let computedCRC = crc32MPEG2(Data(dataWithoutCRC))
        let storedCRC =
            UInt32(pmt[pmt.count - 4]) << 24
            | UInt32(pmt[pmt.count - 3]) << 16
            | UInt32(pmt[pmt.count - 2]) << 8
            | UInt32(pmt[pmt.count - 1])
        #expect(computedCRC == storedCRC)
    }

    @Test("PMT: video only")
    func pmtVideoOnly() {
        let gen = ProgramTableGenerator()
        let pmt = gen.generatePMT(streams: [
            .init(streamType: .h264, pid: 0x0101)
        ])
        // Verify CRC is valid
        let dataWithoutCRC = pmt[0..<(pmt.count - 4)]
        let computedCRC = crc32MPEG2(Data(dataWithoutCRC))
        let storedCRC =
            UInt32(pmt[pmt.count - 4]) << 24
            | UInt32(pmt[pmt.count - 3]) << 16
            | UInt32(pmt[pmt.count - 2]) << 8
            | UInt32(pmt[pmt.count - 1])
        #expect(computedCRC == storedCRC)
    }

    // MARK: - CRC-32 MPEG-2

    @Test("CRC-32 MPEG-2: known test vectors")
    func crc32KnownVectors() {
        // "123456789" → 0x0376E6E7 for MPEG-2 CRC-32
        let testData = Data("123456789".utf8)
        let crc = crc32MPEG2(testData)
        #expect(crc == 0x0376_E6E7)
    }

    @Test("CRC-32 MPEG-2: empty data")
    func crc32EmptyData() {
        let crc = crc32MPEG2(Data())
        #expect(crc == 0xFFFF_FFFF)
    }

    @Test("CRC-32 MPEG-2: single byte")
    func crc32SingleByte() {
        let crc = crc32MPEG2(Data([0x00]))
        // Known: CRC-32/MPEG-2 of 0x00 = 0x4E08BFB4
        #expect(crc == 0x4E08_BFB4)
    }
}
