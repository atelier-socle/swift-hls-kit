// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePartialSegment", .timeLimit(.minutes(1)))
struct LivePartialSegmentTests {

    @Test("Create with all properties")
    func createWithAllProperties() {
        let data = Data(repeating: 0xAA, count: 256)
        let partial = LivePartialSegment(
            index: 3,
            data: data,
            duration: 0.5,
            isIndependent: true,
            isGap: false
        )

        #expect(partial.index == 3)
        #expect(partial.data == data)
        #expect(partial.duration == 0.5)
        #expect(partial.isIndependent == true)
        #expect(partial.isGap == false)
    }

    @Test("Default isGap is false")
    func defaultIsGapFalse() {
        let partial = LivePartialSegment(
            index: 0,
            data: Data(),
            duration: 0.2,
            isIndependent: true
        )

        #expect(partial.isGap == false)
    }

    @Test("Identifiable: id equals index")
    func identifiable() {
        let partial = LivePartialSegment(
            index: 7,
            data: Data(),
            duration: 0.3,
            isIndependent: false
        )

        #expect(partial.id == 7)
        #expect(partial.id == partial.index)
    }

    @Test("Equatable: same values are equal")
    func equatable() {
        let data = Data(repeating: 0xBB, count: 128)
        let partial1 = LivePartialSegment(
            index: 1,
            data: data,
            duration: 0.25,
            isIndependent: true,
            isGap: false
        )
        let partial2 = LivePartialSegment(
            index: 1,
            data: data,
            duration: 0.25,
            isIndependent: true,
            isGap: false
        )

        #expect(partial1 == partial2)
    }

    @Test("Equatable: different values are not equal")
    func notEqual() {
        let partial1 = LivePartialSegment(
            index: 1,
            data: Data(repeating: 0xAA, count: 64),
            duration: 0.25,
            isIndependent: true
        )
        let partial2 = LivePartialSegment(
            index: 2,
            data: Data(repeating: 0xAA, count: 64),
            duration: 0.25,
            isIndependent: true
        )

        #expect(partial1 != partial2)
    }

    @Test("Gap partial segment")
    func gapPartial() {
        let partial = LivePartialSegment(
            index: 0,
            data: Data(),
            duration: 0.2,
            isIndependent: false,
            isGap: true
        )

        #expect(partial.isGap == true)
        #expect(partial.data.isEmpty)
    }

    @Test("Sendable conformance")
    func sendable() async {
        let partial = LivePartialSegment(
            index: 0,
            data: Data(repeating: 0xCC, count: 32),
            duration: 0.1,
            isIndependent: true
        )
        let task = Task { partial }
        let result = await task.value
        #expect(result.index == 0)
    }
}
