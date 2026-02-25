// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ProgramDateTimeSync", .timeLimit(.minutes(1)))
struct ProgramDateTimeSyncTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - shouldInsert

    @Test("everySegment: always returns true")
    func everySegmentAlwaysTrue() {
        let sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        for i in 0..<5 {
            #expect(sync.shouldInsert(forSegmentIndex: i))
        }
    }

    @Test("everyNSegments(3): true at 0, 3, 6; false at 1, 2, 4, 5")
    func everyNSegments() {
        let sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everyNSegments(3)
        )
        #expect(sync.shouldInsert(forSegmentIndex: 0))
        #expect(!sync.shouldInsert(forSegmentIndex: 1))
        #expect(!sync.shouldInsert(forSegmentIndex: 2))
        #expect(sync.shouldInsert(forSegmentIndex: 3))
        #expect(!sync.shouldInsert(forSegmentIndex: 4))
        #expect(!sync.shouldInsert(forSegmentIndex: 5))
        #expect(sync.shouldInsert(forSegmentIndex: 6))
    }

    @Test("onDiscontinuity: true at index 0 and discontinuity")
    func onDiscontinuity() {
        let sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .onDiscontinuity
        )
        #expect(sync.shouldInsert(forSegmentIndex: 0))
        #expect(!sync.shouldInsert(forSegmentIndex: 1))
        #expect(!sync.shouldInsert(forSegmentIndex: 5))
        #expect(sync.shouldInsert(forSegmentIndex: 5, isDiscontinuity: true))
    }

    // MARK: - advanceAndGetDate

    @Test("advanceAndGetDate advances by segment duration")
    func advanceDate() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        let date0 = sync.advanceAndGetDate(segmentDuration: 6.0)
        #expect(date0 == refDate)
        let date1 = sync.advanceAndGetDate(segmentDuration: 6.0)
        #expect(date1 == refDate.addingTimeInterval(6.0))
        let date2 = sync.advanceAndGetDate(segmentDuration: 4.0)
        #expect(date2 == refDate.addingTimeInterval(12.0))
    }

    // MARK: - tagForSegment

    @Test("tagForSegment produces correct ISO 8601 format")
    func tagFormat() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        let tag = sync.tagForSegment(index: 0, segmentDuration: 6.0)
        #expect(tag != nil)
        #expect(tag?.hasPrefix("#EXT-X-PROGRAM-DATE-TIME:") == true)
        // Check ISO 8601 format with T and Z
        let dateStr = tag?.replacingOccurrences(
            of: "#EXT-X-PROGRAM-DATE-TIME:", with: ""
        )
        #expect(dateStr?.contains("T") == true)
    }

    @Test("tagForSegment returns nil when not needed")
    func tagNilWhenNotNeeded() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everyNSegments(3)
        )
        // Index 0 → tag emitted (advances clock)
        let tag0 = sync.tagForSegment(index: 0, segmentDuration: 6.0)
        #expect(tag0 != nil)
        // Index 1 → no tag (but still advances clock)
        let tag1 = sync.tagForSegment(index: 1, segmentDuration: 6.0)
        #expect(tag1 == nil)
    }

    // MARK: - formatDate

    @Test("formatDate produces millisecond precision")
    func formatDatePrecision() {
        let date = Date(timeIntervalSince1970: 1_740_000_000.123)
        let formatted = ProgramDateTimeSync.formatDate(date)
        #expect(formatted.contains("."))
        #expect(formatted.contains("T"))
    }

    @Test("formatDate produces UTC timezone")
    func formatDateUTC() {
        let formatted = ProgramDateTimeSync.formatDate(refDate)
        #expect(formatted.hasSuffix("Z"))
    }

    // MARK: - Accumulated State

    @Test("accumulatedMediaTime tracks sum of durations")
    func accumulatedTime() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        _ = sync.advanceAndGetDate(segmentDuration: 6.0)
        _ = sync.advanceAndGetDate(segmentDuration: 4.0)
        _ = sync.advanceAndGetDate(segmentDuration: 8.0)
        #expect(sync.accumulatedMediaTime == 18.0)
    }

    @Test("segmentCount increments")
    func segmentCountIncrements() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        #expect(sync.segmentCount == 0)
        _ = sync.advanceAndGetDate(segmentDuration: 6.0)
        #expect(sync.segmentCount == 1)
        _ = sync.advanceAndGetDate(segmentDuration: 6.0)
        #expect(sync.segmentCount == 2)
    }

    // MARK: - Reset

    @Test("Reset clears accumulated time and count")
    func resetClears() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        _ = sync.advanceAndGetDate(segmentDuration: 6.0)
        _ = sync.advanceAndGetDate(segmentDuration: 6.0)
        sync.reset()
        #expect(sync.accumulatedMediaTime == 0)
        #expect(sync.segmentCount == 0)
    }

    @Test("Reset with new start date uses new reference")
    func resetNewDate() {
        let newDate = refDate.addingTimeInterval(1000)
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        sync.reset(newStartDate: newDate)
        #expect(sync.streamStartDate == newDate)
    }

    // MARK: - Clock Drift

    @Test("clockDrift is non-negative for immediate check")
    func clockDriftNonNegative() {
        let sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        // Immediately after creation, drift ≈ 0
        #expect(sync.clockDrift >= 0)
    }

    // MARK: - Chained Dates

    @Test("Multiple segments: dates chain correctly")
    func chainedDates() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        let d0 = sync.advanceAndGetDate(segmentDuration: 6.0)
        let d1 = sync.advanceAndGetDate(segmentDuration: 4.0)
        let d2 = sync.advanceAndGetDate(segmentDuration: 8.0)
        #expect(d0 == refDate)
        #expect(d1 == refDate.addingTimeInterval(6.0))
        #expect(d2 == refDate.addingTimeInterval(10.0))
    }

    @Test("Zero-duration segment: date unchanged")
    func zeroDurationDate() {
        var sync = ProgramDateTimeSync(
            streamStartDate: refDate,
            interval: .everySegment
        )
        let d0 = sync.advanceAndGetDate(segmentDuration: 0.0)
        let d1 = sync.advanceAndGetDate(segmentDuration: 0.0)
        #expect(d0 == refDate)
        #expect(d1 == refDate)
    }
}
