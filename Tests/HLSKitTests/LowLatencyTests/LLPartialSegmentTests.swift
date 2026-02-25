// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LLPartialSegment", .timeLimit(.minutes(1)))
struct LLPartialSegmentTests {

    // MARK: - Creation

    @Test("Create with all properties")
    func createWithAllProperties() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let partial = LLPartialSegment(
            duration: 0.33334,
            uri: "seg0.0.mp4",
            isIndependent: true,
            isGap: false,
            byteRange: ByteRange(length: 1024, offset: 0),
            segmentIndex: 0,
            partialIndex: 0,
            timestamp: date
        )

        #expect(partial.duration == 0.33334)
        #expect(partial.uri == "seg0.0.mp4")
        #expect(partial.isIndependent == true)
        #expect(partial.isGap == false)
        #expect(partial.byteRange?.length == 1024)
        #expect(partial.byteRange?.offset == 0)
        #expect(partial.segmentIndex == 0)
        #expect(partial.partialIndex == 0)
        #expect(partial.timestamp == date)
    }

    @Test("Defaults: isGap false, byteRange nil")
    func defaults() {
        let partial = LLPartialSegment(
            duration: 0.5,
            uri: "seg1.0.mp4",
            isIndependent: true,
            segmentIndex: 1,
            partialIndex: 0
        )

        #expect(partial.isGap == false)
        #expect(partial.byteRange == nil)
    }

    // MARK: - Identifiable

    @Test("id is segmentIndex.partialIndex")
    func identifiable() {
        let partial = LLPartialSegment(
            duration: 0.2,
            uri: "seg3.2.mp4",
            isIndependent: false,
            segmentIndex: 3,
            partialIndex: 2
        )

        #expect(partial.id == "3.2")
    }

    @Test("Unique IDs for different partials")
    func uniqueIds() {
        let p1 = LLPartialSegment(
            duration: 0.2, uri: "a", isIndependent: true,
            segmentIndex: 0, partialIndex: 0
        )
        let p2 = LLPartialSegment(
            duration: 0.2, uri: "b", isIndependent: false,
            segmentIndex: 0, partialIndex: 1
        )
        let p3 = LLPartialSegment(
            duration: 0.2, uri: "c", isIndependent: true,
            segmentIndex: 1, partialIndex: 0
        )

        #expect(p1.id != p2.id)
        #expect(p2.id != p3.id)
        #expect(p1.id != p3.id)
    }

    // MARK: - Equatable

    @Test("Equatable compares all fields")
    func equatable() {
        let date = Date(timeIntervalSince1970: 0)
        let p1 = LLPartialSegment(
            duration: 0.33, uri: "seg0.0.mp4",
            isIndependent: true, segmentIndex: 0,
            partialIndex: 0, timestamp: date
        )
        let p2 = LLPartialSegment(
            duration: 0.33, uri: "seg0.0.mp4",
            isIndependent: true, segmentIndex: 0,
            partialIndex: 0, timestamp: date
        )

        #expect(p1 == p2)
    }

    @Test("Different URIs are not equal")
    func notEqual() {
        let date = Date(timeIntervalSince1970: 0)
        let p1 = LLPartialSegment(
            duration: 0.33, uri: "seg0.0.mp4",
            isIndependent: true, segmentIndex: 0,
            partialIndex: 0, timestamp: date
        )
        let p2 = LLPartialSegment(
            duration: 0.33, uri: "different.mp4",
            isIndependent: true, segmentIndex: 0,
            partialIndex: 0, timestamp: date
        )

        #expect(p1 != p2)
    }

    // MARK: - Sendable

    @Test("Sendable: usable in concurrent context")
    func sendable() async {
        let partial = LLPartialSegment(
            duration: 0.2, uri: "seg0.0.mp4",
            isIndependent: true, segmentIndex: 0,
            partialIndex: 0
        )

        let result = await Task.detached {
            partial.uri
        }.value

        #expect(result == "seg0.0.mp4")
    }

    // MARK: - ByteRange

    @Test("ByteRange with offset")
    func byteRangeWithOffset() {
        let range = ByteRange(length: 2048, offset: 512)
        #expect(range.length == 2048)
        #expect(range.offset == 512)
    }

    @Test("ByteRange without offset")
    func byteRangeWithoutOffset() {
        let range = ByteRange(length: 1024)
        #expect(range.length == 1024)
        #expect(range.offset == nil)
    }
}
