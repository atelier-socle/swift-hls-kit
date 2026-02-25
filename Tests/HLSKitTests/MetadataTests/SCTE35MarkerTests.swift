// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SCTE35Marker", .timeLimit(.minutes(1)))
struct SCTE35MarkerTests {

    // MARK: - splice_null

    @Test("spliceNull has commandType .spliceNull")
    func spliceNullType() {
        let marker = SCTE35Marker.spliceNull()
        #expect(marker.commandType == .spliceNull)
    }

    @Test("spliceNull serialize has table_id 0xFC and protocol_version 0")
    func spliceNullHeader() {
        let data = SCTE35Marker.spliceNull().serialize()
        #expect(data[0] == 0xFC)
        #expect(data[3] == 0x00)
    }

    @Test("spliceNull round-trip: serialize → parse → equal")
    func spliceNullRoundTrip() {
        let original = SCTE35Marker.spliceNull()
        let data = original.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.commandType == .spliceNull)
    }

    // MARK: - splice_insert

    @Test("spliceInsert preserves eventId")
    func spliceInsertEventId() {
        let marker = SCTE35Marker.spliceInsert(eventId: 12345)
        #expect(marker.eventId == 12345)
    }

    @Test("spliceInsert with duration 30s → breakDuration.seconds ≈ 30.0")
    func spliceInsertDuration() {
        let marker = SCTE35Marker.spliceInsert(
            eventId: 1, duration: 30.0
        )
        #expect(marker.breakDuration != nil)
        let seconds = marker.breakDuration?.seconds ?? 0
        #expect(abs(seconds - 30.0) < 0.001)
    }

    @Test("spliceInsert outOfNetwork true → flag set")
    func spliceInsertOutOfNetwork() {
        let marker = SCTE35Marker.spliceInsert(
            eventId: 1, outOfNetwork: true
        )
        #expect(marker.outOfNetwork)
    }

    @Test("spliceInsert outOfNetwork false → return to program")
    func spliceInsertReturn() {
        let marker = SCTE35Marker.spliceInsert(
            eventId: 1, outOfNetwork: false
        )
        #expect(!marker.outOfNetwork)
    }

    @Test("spliceInsert with spliceTime → PTS correct")
    func spliceInsertSpliceTime() {
        let time = SCTE35Marker.SpliceTime.fromSeconds(10.0)
        let marker = SCTE35Marker.spliceInsert(
            eventId: 1, spliceTime: time
        )
        #expect(marker.spliceTime?.pts == 900_000)
    }

    @Test("spliceInsert autoReturn → breakDuration.autoReturn true")
    func spliceInsertAutoReturn() {
        let marker = SCTE35Marker.spliceInsert(
            eventId: 1, duration: 30.0, autoReturn: true
        )
        #expect(marker.breakDuration?.autoReturn == true)
    }

    @Test("spliceInsert round-trip: serialize → parse → fields match")
    func spliceInsertRoundTrip() {
        let original = SCTE35Marker.spliceInsert(
            eventId: 42,
            duration: 30.0,
            outOfNetwork: true
        )
        let data = original.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.commandType == .spliceInsert)
        #expect(parsed?.eventId == 42)
        #expect(parsed?.outOfNetwork == true)
        let seconds = parsed?.breakDuration?.seconds ?? 0
        #expect(abs(seconds - 30.0) < 0.001)
    }

    // MARK: - time_signal

    @Test("timeSignal has commandType .timeSignal")
    func timeSignalType() {
        let time = SCTE35Marker.SpliceTime.fromSeconds(5.0)
        let marker = SCTE35Marker.timeSignal(spliceTime: time)
        #expect(marker.commandType == .timeSignal)
    }

    @Test("timeSignal round-trip: serialize → parse → equal")
    func timeSignalRoundTrip() {
        let time = SCTE35Marker.SpliceTime.fromSeconds(5.0)
        let original = SCTE35Marker.timeSignal(spliceTime: time)
        let data = original.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.commandType == .timeSignal)
        #expect(parsed?.spliceTime?.pts == 450_000)
    }

    // MARK: - SpliceTime

    @Test("SpliceTime.fromSeconds(10.0) → pts = 900_000")
    func spliceTimeFromSeconds() {
        let time = SCTE35Marker.SpliceTime.fromSeconds(10.0)
        #expect(time.pts == 900_000)
        #expect(time.timeSpecified)
    }

    @Test("SpliceTime.seconds converts back correctly")
    func spliceTimeSeconds() {
        let time = SCTE35Marker.SpliceTime.fromSeconds(10.0)
        let seconds = time.seconds ?? 0
        #expect(abs(seconds - 10.0) < 0.001)
    }

    // MARK: - BreakDuration

    @Test("BreakDuration.fromSeconds(30.0) → duration = 2_700_000")
    func breakDurationFromSeconds() {
        let bd = SCTE35Marker.BreakDuration.fromSeconds(30.0)
        #expect(bd.duration == 2_700_000)
        #expect(bd.autoReturn)
    }

    // MARK: - Hex Serialization

    @Test("serializeHex starts with '0x' and is uppercase")
    func serializeHexFormat() {
        let hex = SCTE35Marker.spliceNull().serializeHex()
        #expect(hex.hasPrefix("0x"))
        let hexBody = String(hex.dropFirst(2))
        #expect(hexBody == hexBody.uppercased())
    }

    @Test("parseHex round-trip with serializeHex")
    func parseHexRoundTrip() {
        let original = SCTE35Marker.spliceInsert(
            eventId: 99, duration: 15.0
        )
        let hex = original.serializeHex()
        let parsed = SCTE35Marker.parseHex(hex)
        #expect(parsed != nil)
        #expect(parsed?.eventId == 99)
    }

    @Test("parseHex with '0x' prefix works")
    func parseHexWithPrefix() {
        let hex = SCTE35Marker.spliceNull().serializeHex()
        #expect(hex.hasPrefix("0x"))
        let parsed = SCTE35Marker.parseHex(hex)
        #expect(parsed != nil)
    }

    @Test("parseHex without prefix works")
    func parseHexWithoutPrefix() {
        let hex = SCTE35Marker.spliceNull().serializeHex()
        let stripped = String(hex.dropFirst(2))
        let parsed = SCTE35Marker.parseHex(stripped)
        #expect(parsed != nil)
    }

    // MARK: - Parse Invalid

    @Test("parse invalid data returns nil")
    func parseInvalid() {
        let result = SCTE35Marker.parse(from: Data([0x00, 0x01, 0x02]))
        #expect(result == nil)
    }

    // MARK: - DATERANGE Integration

    @Test("dateRangeAttributes contains SCTE35-CMD key with hex value")
    func dateRangeAttributes() {
        let marker = SCTE35Marker.spliceInsert(
            eventId: 1, outOfNetwork: true
        )
        let attrs = marker.dateRangeAttributes()
        #expect(attrs["SCTE35-CMD"] != nil)
        #expect(attrs["SCTE35-CMD"]?.hasPrefix("0x") == true)
        #expect(attrs["SCTE35-OUT"] != nil)
    }

    @Test("dateRangeAttributes for return has SCTE35-IN")
    func dateRangeAttributesReturn() {
        let marker = SCTE35Marker.spliceInsert(
            eventId: 1, outOfNetwork: false
        )
        let attrs = marker.dateRangeAttributes()
        #expect(attrs["SCTE35-IN"] != nil)
        #expect(attrs["SCTE35-OUT"] == nil)
    }

    // MARK: - Splice Insert with Splice Time (non-immediate)

    @Test("spliceInsert with spliceTime round-trip preserves time")
    func spliceInsertWithTimeRoundTrip() {
        let time = SCTE35Marker.SpliceTime.fromSeconds(5.0)
        let original = SCTE35Marker.spliceInsert(
            eventId: 7, duration: 20.0,
            outOfNetwork: true, spliceTime: time
        )
        let data = original.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed != nil)
        #expect(parsed?.spliceTime?.timeSpecified == true)
        let seconds = parsed?.spliceTime?.seconds ?? 0
        #expect(abs(seconds - 5.0) < 0.001)
    }

    @Test("timeSignal without pts → timeSpecified false")
    func timeSignalNoSpecified() {
        let time = SCTE35Marker.SpliceTime(timeSpecified: false)
        let marker = SCTE35Marker.timeSignal(spliceTime: time)
        let data = marker.serialize()
        let parsed = SCTE35Marker.parse(from: data)
        #expect(parsed?.spliceTime?.timeSpecified == false)
    }

    @Test("SpliceTime with no pts → seconds is nil")
    func spliceTimeNilPts() {
        let time = SCTE35Marker.SpliceTime(timeSpecified: false)
        #expect(time.seconds == nil)
    }

    // MARK: - CaseIterable

    @Test("SpliceCommandType has 3 cases")
    func commandTypeCases() {
        #expect(SCTE35Marker.SpliceCommandType.allCases.count == 3)
    }
}
