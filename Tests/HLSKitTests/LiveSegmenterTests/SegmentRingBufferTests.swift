// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SegmentRingBuffer", .timeLimit(.minutes(1)))
struct SegmentRingBufferTests {

    // MARK: - Helpers

    private func makeSegment(
        index: Int, dataSize: Int = 100,
        duration: TimeInterval = 6.0
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: UInt8(index % 256), count: dataSize),
            duration: duration,
            timestamp: MediaTimestamp(
                seconds: Double(index) * duration
            ),
            isIndependent: true,
            filename: "segment_\(index).m4s",
            frameCount: 180,
            codecs: [.aac]
        )
    }

    // MARK: - Append & Capacity

    @Test("Append segments within capacity")
    func appendWithinCapacity() {
        var buffer = SegmentRingBuffer(capacity: 5)
        for i in 0..<5 {
            buffer.append(makeSegment(index: i))
        }
        #expect(buffer.count == 5)
    }

    @Test("Append beyond capacity evicts oldest")
    func appendEvictsOldest() {
        var buffer = SegmentRingBuffer(capacity: 3)
        for i in 0..<5 {
            buffer.append(makeSegment(index: i))
        }
        #expect(buffer.count == 3)
        #expect(buffer.oldest?.index == 2)
        #expect(buffer.newest?.index == 4)
    }

    // MARK: - Lookup

    @Test("segment(at:) returns correct segment")
    func segmentAtIndex() {
        var buffer = SegmentRingBuffer(capacity: 5)
        for i in 0..<3 {
            buffer.append(makeSegment(index: i))
        }
        let seg = buffer.segment(at: 1)
        #expect(seg?.index == 1)
    }

    @Test("segment(at:) returns nil for evicted index")
    func segmentAtEvictedIndex() {
        var buffer = SegmentRingBuffer(capacity: 2)
        for i in 0..<5 {
            buffer.append(makeSegment(index: i))
        }
        #expect(buffer.segment(at: 0) == nil)
        #expect(buffer.segment(at: 1) == nil)
        #expect(buffer.segment(at: 2) == nil)
        #expect(buffer.segment(at: 3) != nil)
        #expect(buffer.segment(at: 4) != nil)
    }

    @Test("segment(at:) returns nil for future index")
    func segmentAtFutureIndex() {
        var buffer = SegmentRingBuffer(capacity: 5)
        buffer.append(makeSegment(index: 0))
        #expect(buffer.segment(at: 99) == nil)
    }

    // MARK: - allSegments

    @Test("allSegments returns ordered segments")
    func allSegmentsOrdered() {
        var buffer = SegmentRingBuffer(capacity: 5)
        for i in 0..<3 {
            buffer.append(makeSegment(index: i))
        }
        let all = buffer.allSegments
        #expect(all.count == 3)
        #expect(all[0].index == 0)
        #expect(all[1].index == 1)
        #expect(all[2].index == 2)
    }

    // MARK: - Properties

    @Test("count and isEmpty")
    func countAndIsEmpty() {
        var buffer = SegmentRingBuffer(capacity: 5)
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)

        buffer.append(makeSegment(index: 0))
        #expect(!buffer.isEmpty)
        #expect(buffer.count == 1)
    }

    @Test("oldest and newest")
    func oldestAndNewest() {
        var buffer = SegmentRingBuffer(capacity: 5)
        #expect(buffer.oldest == nil)
        #expect(buffer.newest == nil)

        buffer.append(makeSegment(index: 0))
        buffer.append(makeSegment(index: 1))
        buffer.append(makeSegment(index: 2))

        #expect(buffer.oldest?.index == 0)
        #expect(buffer.newest?.index == 2)
    }

    @Test("indexRange")
    func indexRange() {
        var buffer = SegmentRingBuffer(capacity: 5)
        #expect(buffer.indexRange == nil)

        buffer.append(makeSegment(index: 3))
        buffer.append(makeSegment(index: 4))
        buffer.append(makeSegment(index: 5))

        #expect(buffer.indexRange == 3...5)
    }

    // MARK: - Clear

    @Test("clear empties buffer")
    func clearBuffer() {
        var buffer = SegmentRingBuffer(capacity: 5)
        for i in 0..<3 {
            buffer.append(makeSegment(index: i))
        }
        buffer.clear()
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
        #expect(buffer.segment(at: 0) == nil)
    }

    // MARK: - Aggregates

    @Test("totalDataSize")
    func totalDataSize() {
        var buffer = SegmentRingBuffer(capacity: 5)
        buffer.append(makeSegment(index: 0, dataSize: 100))
        buffer.append(makeSegment(index: 1, dataSize: 200))
        #expect(buffer.totalDataSize == 300)
    }

    @Test("totalDuration")
    func totalDuration() {
        var buffer = SegmentRingBuffer(capacity: 5)
        buffer.append(makeSegment(index: 0, duration: 6.0))
        buffer.append(makeSegment(index: 1, duration: 6.5))
        #expect(buffer.totalDuration == 12.5)
    }

    // MARK: - Edge Cases

    @Test("Zero capacity stores no segments")
    func zeroCapacity() {
        var buffer = SegmentRingBuffer(capacity: 0)
        buffer.append(makeSegment(index: 0))
        #expect(buffer.isEmpty)
        #expect(buffer.count == 0)
    }

    @Test("Max capacity stores unlimited segments")
    func maxCapacity() {
        var buffer = SegmentRingBuffer(capacity: .max)
        for i in 0..<100 {
            buffer.append(makeSegment(index: i))
        }
        #expect(buffer.count == 100)
        #expect(buffer.segment(at: 0) != nil)
        #expect(buffer.segment(at: 99) != nil)
    }

    @Test("Single segment")
    func singleSegment() {
        var buffer = SegmentRingBuffer(capacity: 1)
        buffer.append(makeSegment(index: 0))
        #expect(buffer.count == 1)
        #expect(buffer.oldest?.index == 0)

        buffer.append(makeSegment(index: 1))
        #expect(buffer.count == 1)
        #expect(buffer.oldest?.index == 1)
        #expect(buffer.segment(at: 0) == nil)
    }
}
