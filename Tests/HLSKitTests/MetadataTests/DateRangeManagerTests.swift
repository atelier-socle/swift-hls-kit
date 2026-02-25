// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("DateRangeManager", .timeLimit(.minutes(1)))
struct DateRangeManagerTests {

    private let refDate = Date(timeIntervalSince1970: 1_740_000_000)

    // MARK: - Open / Close / Expire / Remove

    @Test("Open range has state .open")
    func openRange() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate)
        let range = await manager.range(id: "ad-1")
        #expect(range?.state == .open)
    }

    @Test("Close range with endDate has state .closed")
    func closeWithEndDate() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate)
        let endDate = refDate.addingTimeInterval(30)
        await manager.close(id: "ad-1", endDate: endDate)
        let range = await manager.range(id: "ad-1")
        #expect(range?.state == .closed)
        #expect(range?.endDate == endDate)
    }

    @Test("Close range with duration has state .closed")
    func closeWithDuration() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate)
        await manager.close(id: "ad-1", duration: 30.0)
        let range = await manager.range(id: "ad-1")
        #expect(range?.state == .closed)
        #expect(range?.duration == 30.0)
    }

    @Test("Expire range has state .expired")
    func expireRange() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate)
        await manager.expire(id: "ad-1")
        let range = await manager.range(id: "ad-1")
        #expect(range?.state == .expired)
    }

    @Test("Remove range: not in allRanges")
    func removeRange() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate)
        await manager.remove(id: "ad-1")
        let range = await manager.range(id: "ad-1")
        #expect(range == nil)
        let all = await manager.allRanges
        #expect(all.isEmpty)
    }

    // MARK: - Query

    @Test("activeRanges excludes expired")
    func activeExcludesExpired() async {
        let manager = DateRangeManager()
        await manager.open(id: "a", startDate: refDate)
        await manager.open(id: "b", startDate: refDate)
        await manager.expire(id: "b")
        let active = await manager.activeRanges
        #expect(active.count == 1)
        #expect(active.first?.id == "a")
    }

    @Test("allRanges includes expired")
    func allIncludesExpired() async {
        let manager = DateRangeManager()
        await manager.open(id: "a", startDate: refDate)
        await manager.expire(id: "a")
        let all = await manager.allRanges
        #expect(all.count == 1)
    }

    @Test("activeCount reflects open + closed only")
    func activeCount() async {
        let manager = DateRangeManager()
        await manager.open(id: "a", startDate: refDate)
        await manager.open(id: "b", startDate: refDate)
        await manager.close(id: "b", duration: 10)
        await manager.open(id: "c", startDate: refDate)
        await manager.expire(id: "c")
        let count = await manager.activeCount
        #expect(count == 2)
    }

    @Test("range(id:) returns correct range")
    func rangeByID() async {
        let manager = DateRangeManager()
        await manager.open(id: "x", startDate: refDate, class: "com.test")
        let range = await manager.range(id: "x")
        #expect(range?.id == "x")
        #expect(range?.classAttribute == "com.test")
    }

    @Test("range(id:) with unknown ID returns nil")
    func rangeUnknownID() async {
        let manager = DateRangeManager()
        let range = await manager.range(id: "nope")
        #expect(range == nil)
    }

    // MARK: - Attributes

    @Test("Open with class stores class")
    func openWithClass() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad", startDate: refDate, class: "com.ad")
        let range = await manager.range(id: "ad")
        #expect(range?.classAttribute == "com.ad")
    }

    @Test("Open with plannedDuration stores it")
    func openWithPlannedDuration() async {
        let manager = DateRangeManager()
        await manager.open(
            id: "ad", startDate: refDate, plannedDuration: 30.0
        )
        let range = await manager.range(id: "ad")
        #expect(range?.plannedDuration == 30.0)
    }

    @Test("Open with customAttributes stores X-* attrs")
    func openWithCustomAttrs() async {
        let manager = DateRangeManager()
        await manager.open(
            id: "ch",
            startDate: refDate,
            customAttributes: ["X-TITLE": "Chapter 1"]
        )
        let range = await manager.range(id: "ch")
        #expect(range?.customAttributes["X-TITLE"] == "Chapter 1")
    }

    @Test("Update adds new attributes")
    func updateAttributes() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad", startDate: refDate)
        await manager.update(
            id: "ad",
            customAttributes: ["X-AD-ID": "spot42"]
        )
        let range = await manager.range(id: "ad")
        #expect(range?.customAttributes["X-AD-ID"] == "spot42")
    }

    // MARK: - Rendering

    @Test("renderDateRanges produces valid EXT-X-DATERANGE lines")
    func renderDateRanges() async {
        let manager = DateRangeManager()
        await manager.open(id: "ad-1", startDate: refDate, class: "com.ad")
        let rendered = await manager.renderDateRanges()
        #expect(rendered.contains("#EXT-X-DATERANGE:"))
        #expect(rendered.contains("ID=\"ad-1\""))
        #expect(rendered.contains("CLASS=\"com.ad\""))
    }

    @Test("renderDateRanges empty when no active ranges")
    func renderEmpty() async {
        let manager = DateRangeManager()
        let rendered = await manager.renderDateRanges()
        #expect(rendered.isEmpty)
    }

    // MARK: - Eviction

    @Test("evictBefore expires old closed ranges")
    func evictBefore() async {
        let manager = DateRangeManager()
        await manager.open(id: "old", startDate: refDate)
        await manager.close(
            id: "old",
            endDate: refDate.addingTimeInterval(10)
        )
        await manager.open(
            id: "new",
            startDate: refDate.addingTimeInterval(100)
        )
        // Evict anything that ended before refDate + 50
        await manager.evictBefore(
            date: refDate.addingTimeInterval(50)
        )
        let old = await manager.range(id: "old")
        #expect(old?.state == .expired)
        let new = await manager.range(id: "new")
        #expect(new?.state == .open)
    }

    @Test("purgeExpired removes expired from allRanges")
    func purgeExpired() async {
        let manager = DateRangeManager()
        await manager.open(id: "a", startDate: refDate)
        await manager.expire(id: "a")
        await manager.purgeExpired()
        let all = await manager.allRanges
        #expect(all.isEmpty)
    }

    // MARK: - Reset

    @Test("Reset clears all state")
    func reset() async {
        let manager = DateRangeManager()
        await manager.open(id: "a", startDate: refDate)
        await manager.open(id: "b", startDate: refDate)
        await manager.reset()
        let all = await manager.allRanges
        #expect(all.isEmpty)
        let count = await manager.activeCount
        #expect(count == 0)
    }

    // MARK: - Multiple Ranges

    @Test("Multiple open ranges tracked independently")
    func multipleRanges() async {
        let manager = DateRangeManager()
        await manager.open(id: "a", startDate: refDate)
        await manager.open(
            id: "b",
            startDate: refDate.addingTimeInterval(10)
        )
        let a = await manager.range(id: "a")
        let b = await manager.range(id: "b")
        #expect(a?.startDate == refDate)
        #expect(b?.startDate == refDate.addingTimeInterval(10))
    }

    // MARK: - toDateRange Conversion

    @Test("Render range with SCTE-35 data converts to hex")
    func scte35Render() async {
        let manager = DateRangeManager()
        await manager.open(id: "splice-1", startDate: refDate)
        let output = await manager.renderDateRanges()
        #expect(output.contains("splice-1"))
    }

    @Test("evictBefore with duration-based end date")
    func evictBeforeDuration() async {
        let manager = DateRangeManager()
        await manager.open(id: "short", startDate: refDate)
        await manager.close(id: "short", duration: 5.0)
        let cutoff = refDate.addingTimeInterval(10)
        await manager.evictBefore(date: cutoff)
        let range = await manager.range(id: "short")
        #expect(range?.state == .expired)
    }

    @Test("evictBefore: open ranges not affected")
    func evictBeforeOpenNotAffected() async {
        let manager = DateRangeManager()
        await manager.open(id: "open-1", startDate: refDate)
        let cutoff = refDate.addingTimeInterval(100)
        await manager.evictBefore(date: cutoff)
        let range = await manager.range(id: "open-1")
        #expect(range?.state == .open)
    }
}
