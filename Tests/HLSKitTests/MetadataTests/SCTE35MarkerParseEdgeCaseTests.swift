// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "SCTE35Marker — Parse & Serialize Edge Cases",
    .timeLimit(.minutes(1))
)
struct SCTE35MarkerParseEdgeCaseTests {

    // MARK: - parseHex Edge Cases

    @Test("parseHex with uppercase 0X prefix works")
    func parseHexUppercasePrefix() {
        let hex = SCTE35Marker.spliceNull().serializeHex()
        let upper = "0X" + String(hex.dropFirst(2))
        let parsed = SCTE35Marker.parseHex(upper)
        #expect(parsed != nil)
        #expect(parsed?.commandType == .spliceNull)
    }

    @Test("parseHex with odd-length string returns nil")
    func parseHexOddLength() {
        let result = SCTE35Marker.parseHex("0xABC")
        #expect(result == nil)
    }

    @Test("parseHex with invalid hex characters returns nil")
    func parseHexInvalidChars() {
        let result = SCTE35Marker.parseHex("0xZZZZ")
        #expect(result == nil)
    }

    // MARK: - parse Data Edge Cases

    @Test("parse with wrong table_id returns nil")
    func parseWrongTableId() {
        var data = SCTE35Marker.spliceNull().serialize()
        data[0] = 0x00
        let result = SCTE35Marker.parse(from: data)
        #expect(result == nil)
    }

    @Test("parse with wrong protocol_version returns nil")
    func parseWrongProtocolVersion() {
        var data = SCTE35Marker.spliceNull().serialize()
        data[3] = 0x01
        let result = SCTE35Marker.parse(from: data)
        #expect(result == nil)
    }

    @Test("parse with unknown command type returns nil")
    func parseUnknownCommandType() {
        var data = SCTE35Marker.spliceNull().serialize()
        data[13] = 0xFF
        let result = SCTE35Marker.parse(from: data)
        #expect(result == nil)
    }

    @Test("parse with too-short data returns nil")
    func parseTooShort() {
        let result = SCTE35Marker.parse(from: Data([0xFC, 0x00]))
        #expect(result == nil)
    }

    // MARK: - splice_insert Cancel Indicator

    @Test("splice_insert with cancel indicator set parses correctly")
    func spliceInsertCancelIndicator() {
        var data = SCTE35Marker.spliceInsert(
            eventId: 100, duration: 30.0, outOfNetwork: true
        ).serialize()
        // Cancel indicator is at byte offset: cmdStart(14) + 4 bytes eventId = 18
        // Set cancel bit (0x80)
        if data.count > 18 {
            data[18] = 0x80
        }
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.commandType == .spliceInsert)
        #expect(parsed?.eventId == 100)
    }

    // MARK: - splice_insert Immediate Mode

    @Test("splice_insert immediate mode (no splice time) round-trips")
    func spliceInsertImmediateMode() {
        let original = SCTE35Marker.spliceInsert(
            eventId: 50,
            outOfNetwork: true,
            spliceTime: nil
        )
        let data = original.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.commandType == .spliceInsert)
        #expect(parsed?.eventId == 50)
        #expect(parsed?.outOfNetwork == true)
    }

    // MARK: - splice_insert with All Fields

    @Test(
        "splice_insert round-trip preserves uniqueProgramId, availNum, availsExpected"
    )
    func spliceInsertFullFields() {
        let marker = SCTE35Marker(
            commandType: .spliceInsert,
            eventId: 999,
            outOfNetwork: true,
            spliceTime: .fromSeconds(10.0),
            breakDuration: .fromSeconds(30.0, autoReturn: false),
            uniqueProgramId: 42,
            availNum: 3,
            availsExpected: 5
        )
        let data = marker.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.uniqueProgramId == 42)
        #expect(parsed?.availNum == 3)
        #expect(parsed?.availsExpected == 5)
        #expect(parsed?.breakDuration?.autoReturn == false)
    }

    // MARK: - BreakDuration.seconds

    @Test("BreakDuration.seconds converts ticks to seconds")
    func breakDurationSeconds() {
        let bd = SCTE35Marker.BreakDuration(
            autoReturn: true, duration: 2_700_000
        )
        let seconds = bd.seconds
        #expect(abs(seconds - 30.0) < 0.001)
    }

    // MARK: - SpliceTime Edge Cases

    @Test("SpliceTime with timeSpecified true but nil pts returns nil seconds")
    func spliceTimeSpecifiedNoPts() {
        let time = SCTE35Marker.SpliceTime(timeSpecified: true, pts: nil)
        #expect(time.seconds == nil)
    }

    // MARK: - Serialize with nil eventId

    @Test("splice_insert with nil eventId serializes with 0")
    func spliceInsertNilEventId() {
        let marker = SCTE35Marker(
            commandType: .spliceInsert,
            outOfNetwork: true
        )
        let data = marker.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.eventId == 0)
    }

    // MARK: - Crafted Binary Parse Edge Cases

    /// Build a minimal SCTE-35 packet with the given command type and data.
    private func makePacket(
        commandType: UInt8, commandData: [UInt8]
    ) -> Data {
        let cmdLen = commandData.count
        var bytes: [UInt8] = [
            0xFC,  // table_id
            0x30, 0x00,  // flags + section_length placeholder
            0x00,  // protocol_version
            0x00,  // encrypted_packet
            0x00, 0x00, 0x00, 0x00,  // pts_adjustment
            0x00,  // cw_index
            0xFF,  // tier high
            UInt8(0xF0 | ((cmdLen >> 8) & 0x0F)),  // tier low | cmdLen high
            UInt8(cmdLen & 0xFF),  // cmdLen low
            commandType
        ]
        bytes.append(contentsOf: commandData)
        bytes.append(contentsOf: [0x00, 0x00])  // descriptor_loop_length
        bytes.append(contentsOf: [0xFF, 0xFF, 0xFF, 0xFF])  // CRC
        return Data(bytes)
    }

    @Test("parse splice_insert with cmdLength exceeding data returns nil")
    func parseSpliceInsertTruncatedCommand() {
        // Valid header but claims 50 bytes of cmd while only providing 1
        var data = makePacket(commandType: 0x05, commandData: [0x00])
        // Override cmdLength to 50
        data[11] = 0xF0
        data[12] = 0x32  // 50
        let result = SCTE35Marker.parse(from: data)
        #expect(result == nil)
    }

    @Test("parse splice_insert with less than 5 bytes cmd data returns nil")
    func parseSpliceInsertTooShortCmd() {
        let result = SCTE35Marker.parse(
            from: makePacket(
                commandType: 0x05,
                commandData: [0x00, 0x00, 0x00]
            )
        )
        #expect(result == nil)
    }

    @Test(
        "parse splice_insert with 5 bytes and cancel=false returns nil"
    )
    func parseSpliceInsertFiveBytesNoCancel() {
        // 5 bytes: eventId(4) + cancel=0x00 → needs >= 6 for flags
        let result = SCTE35Marker.parse(
            from: makePacket(
                commandType: 0x05,
                commandData: [0x00, 0x00, 0x00, 0x01, 0x00]
            )
        )
        #expect(result == nil)
    }

    @Test("parse splice_insert with truncated break duration returns nil")
    func parseSpliceInsertTruncatedBreakDuration() {
        // 6 bytes: eventId(4) + cancel(1)=0x00 + flags(1)
        // flags: program_splice=1, hasDuration=1, splice_immediate=1
        let flags: UInt8 = 0x40 | 0x20 | 0x10 | 0x0F
        let result = SCTE35Marker.parse(
            from: makePacket(
                commandType: 0x05,
                commandData: [0x00, 0x00, 0x00, 0x01, 0x00, flags]
            )
        )
        #expect(result == nil)
    }

    @Test("parse time_signal with empty command data returns nil")
    func parseTimeSignalEmptyCmd() {
        let result = SCTE35Marker.parse(
            from: makePacket(commandType: 0x06, commandData: [])
        )
        #expect(result == nil)
    }

    @Test("parse splice_insert with splice time at data boundary")
    func parseSpliceInsertSpliceTimeAtBoundary() {
        // 6 bytes: eventId(4) + cancel(1)=0 + flags(1)
        // flags: program_splice=1, no duration, NOT immediate → reads splice time
        let flags: UInt8 = 0x40 | 0x0F
        let result = SCTE35Marker.parse(
            from: makePacket(
                commandType: 0x05,
                commandData: [0x00, 0x00, 0x00, 0x01, 0x00, flags]
            )
        )
        // readSpliceTime: offset=6, data.count=6 → guard fails → time=nil
        #expect(result != nil)
        #expect(result?.spliceTime?.timeSpecified == false)
    }

    @Test("parse splice_insert with truncated PTS in splice time")
    func parseSpliceInsertTruncatedPTS() {
        // 7 bytes: eventId(4) + cancel(1) + flags(1) + 1 byte splice time
        // flags: program_splice, not immediate
        let flags: UInt8 = 0x40 | 0x0F
        let result = SCTE35Marker.parse(
            from: makePacket(
                commandType: 0x05,
                commandData: [
                    0x00, 0x00, 0x00, 0x01, 0x00, flags,
                    0x80  // time_specified=true but no PTS bytes
                ]
            )
        )
        // readSpliceTime: specified=true, data.count=7 < offset(6)+5=11 → fallback
        #expect(result != nil)
        #expect(result?.spliceTime?.timeSpecified == false)
    }
}
