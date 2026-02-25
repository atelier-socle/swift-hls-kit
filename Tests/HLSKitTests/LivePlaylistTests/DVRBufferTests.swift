// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("DVRBuffer", .timeLimit(.minutes(1)))
struct DVRBufferTests {

    // MARK: - Append

    @Test("Append segments increases count")
    func appendSegments() {
        var buffer = DVRBuffer(windowDuration: 60)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        #expect(buffer.count == 3)
        #expect(!buffer.isEmpty)
    }

    // MARK: - Eviction

    @Test("evictExpired removes old segments")
    func evictExpired() {
        var buffer = DVRBuffer(windowDuration: 15)
        // 5 segments of 6s each (0-6, 6-12, 12-18, 18-24, 24-30)
        // Latest timestamp = 24, cutoff = 24 - 15 = 9
        // Segment 0: ends at 6 < 9 → evict
        // Segment 1: ends at 12 >= 9 → keep
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            buffer.append(seg)
        }
        let evicted = buffer.evictExpired()
        #expect(evicted.count == 1)
        #expect(evicted[0].index == 0)
        #expect(buffer.count == 4)
    }

    @Test("evictExpired returns evicted segments")
    func evictedReturned() {
        var buffer = DVRBuffer(windowDuration: 10)
        // 5 segments of 6s: timestamps 0, 6, 12, 18, 24
        // Latest = 24, cutoff = 24 - 10 = 14
        // Seg 0: ends 6 < 14 → evict
        // Seg 1: ends 12 < 14 → evict
        // Seg 2: ends 18 >= 14 → keep
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            buffer.append(seg)
        }
        let evicted = buffer.evictExpired()
        #expect(evicted.count == 2)
        #expect(evicted[0].index == 0)
        #expect(evicted[1].index == 1)
    }

    @Test("No eviction within window")
    func noEviction() {
        var buffer = DVRBuffer(windowDuration: 120)
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            buffer.append(seg)
        }
        let evicted = buffer.evictExpired()
        #expect(evicted.isEmpty)
        #expect(buffer.count == 5)
    }

    // MARK: - Lookup

    @Test("segment(at:) finds segment by index")
    func segmentLookup() {
        var buffer = DVRBuffer(windowDuration: 60)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        let found = buffer.segment(at: 1)
        #expect(found?.index == 1)
    }

    @Test("segment(at:) returns nil for evicted")
    func segmentLookupEvicted() {
        var buffer = DVRBuffer(windowDuration: 10)
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            buffer.append(seg)
        }
        buffer.evictExpired()
        #expect(buffer.segment(at: 0) == nil)
    }

    @Test("segment(at:) returns nil for unknown index")
    func segmentLookupUnknown() {
        let buffer = DVRBuffer(windowDuration: 60)
        #expect(buffer.segment(at: 99) == nil)
    }

    // MARK: - Properties

    @Test("allSegments returns ordered segments")
    func allSegmentsOrdered() {
        var buffer = DVRBuffer(windowDuration: 60)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        let all = buffer.allSegments
        #expect(all.count == 3)
        #expect(all[0].index == 0)
        #expect(all[1].index == 1)
        #expect(all[2].index == 2)
    }

    @Test("count and isEmpty")
    func countAndEmpty() {
        var buffer = DVRBuffer(windowDuration: 60)
        #expect(buffer.count == 0)
        #expect(buffer.isEmpty)
        buffer.append(LiveSegmentFactory.makeSegment())
        #expect(buffer.count == 1)
        #expect(!buffer.isEmpty)
    }

    @Test("totalDuration sums all segment durations")
    func totalDuration() {
        var buffer = DVRBuffer(windowDuration: 60)
        let segments = LiveSegmentFactory.makeSegments(
            count: 3, duration: 6.0
        )
        for seg in segments {
            buffer.append(seg)
        }
        #expect(abs(buffer.totalDuration - 18.0) < 0.01)
    }

    @Test("totalDataSize sums all segment data")
    func totalDataSize() {
        var buffer = DVRBuffer(windowDuration: 60)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        // Each segment has 64 bytes of data
        #expect(buffer.totalDataSize == 192)
    }

    @Test("oldest and newest")
    func oldestNewest() {
        var buffer = DVRBuffer(windowDuration: 60)
        #expect(buffer.oldest == nil)
        #expect(buffer.newest == nil)

        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        #expect(buffer.oldest?.index == 0)
        #expect(buffer.newest?.index == 2)
    }

    // MARK: - Range Queries

    @Test("segmentsFromOffset: negative offset (rewind)")
    func segmentsFromOffsetRewind() {
        var buffer = DVRBuffer(windowDuration: 120)
        // 10 segments of 6s, timestamps: 0, 6, 12, 18, 24, 30, 36, 42, 48, 54
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            buffer.append(seg)
        }
        // Offset -18: target = 54 + (-18) = 36
        let result = buffer.segmentsFromOffset(-18)
        #expect(result.count == 4)  // segments 6(36), 7(42), 8(48), 9(54)
        #expect(result[0].index == 6)
    }

    @Test("segmentsFromOffset: offset=0 returns live edge")
    func segmentsFromOffsetLiveEdge() {
        var buffer = DVRBuffer(windowDuration: 120)
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            buffer.append(seg)
        }
        // Offset 0: target = 24 + 0 = 24
        let result = buffer.segmentsFromOffset(0)
        #expect(result.count == 1)  // Only segment at timestamp 24
        #expect(result[0].index == 4)
    }

    @Test("segmentsFromOffset: beyond buffer returns from beginning")
    func segmentsFromOffsetBeyond() {
        var buffer = DVRBuffer(windowDuration: 120)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        // Offset -1000: target = 12 + (-1000) = -988 → all qualify
        let result = buffer.segmentsFromOffset(-1000)
        #expect(result.count == 3)
    }

    @Test("segmentsFromOffset: with maxCount")
    func segmentsFromOffsetMaxCount() {
        var buffer = DVRBuffer(windowDuration: 120)
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            buffer.append(seg)
        }
        let result = buffer.segmentsFromOffset(-1000, maxCount: 3)
        #expect(result.count == 3)
        #expect(result[0].index == 0)
    }

    @Test("segmentsFromOffset: empty buffer returns empty")
    func segmentsFromOffsetEmpty() {
        let buffer = DVRBuffer(windowDuration: 60)
        let result = buffer.segmentsFromOffset(-10)
        #expect(result.isEmpty)
    }

    // MARK: - Date Range

    @Test("segmentsInDateRange: matching segments")
    func dateRangeMatch() {
        var buffer = DVRBuffer(windowDuration: 120)
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for i in 0..<5 {
            let seg = LiveSegmentFactory.makeSegment(
                index: i,
                programDateTime: base.addingTimeInterval(
                    Double(i) * 6.0
                )
            )
            buffer.append(seg)
        }
        let from = base.addingTimeInterval(6)
        let to = base.addingTimeInterval(18)
        let result = buffer.segmentsInDateRange(from: from, to: to)
        #expect(result.count == 3)  // indices 1, 2, 3
    }

    @Test("segmentsInDateRange: no programDateTime returns empty")
    func dateRangeNoProgramDate() {
        var buffer = DVRBuffer(windowDuration: 120)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        let from = Date(timeIntervalSince1970: 0)
        let to = Date()
        let result = buffer.segmentsInDateRange(from: from, to: to)
        #expect(result.isEmpty)
    }

    // MARK: - Clear

    @Test("clear empties buffer")
    func clear() {
        var buffer = DVRBuffer(windowDuration: 60)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        buffer.clear()
        #expect(buffer.count == 0)
        #expect(buffer.isEmpty)
        #expect(buffer.segment(at: 0) == nil)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatable() {
        var a = DVRBuffer(windowDuration: 60)
        var b = DVRBuffer(windowDuration: 60)
        let seg = LiveSegmentFactory.makeSegment()
        a.append(seg)
        b.append(seg)
        #expect(a == b)
    }

    @Test("Different windowDuration not equal")
    func notEqual() {
        let a = DVRBuffer(windowDuration: 60)
        let b = DVRBuffer(windowDuration: 120)
        #expect(a != b)
    }

    // MARK: - Index Map Correctness After Eviction

    @Test("Append + evict + append keeps index map correct")
    func indexMapAfterEviction() {
        var buffer = DVRBuffer(windowDuration: 15)
        // Add 5 segments, evict some, add more
        let batch1 = LiveSegmentFactory.makeSegments(count: 5)
        for seg in batch1 {
            buffer.append(seg)
        }
        buffer.evictExpired()
        // Add segment index 5
        let seg5 = LiveSegmentFactory.makeSegment(index: 5)
        buffer.append(seg5)
        #expect(buffer.segment(at: 5)?.index == 5)
        // Evicted segments not findable
        #expect(buffer.segment(at: 0) == nil)
    }
}
