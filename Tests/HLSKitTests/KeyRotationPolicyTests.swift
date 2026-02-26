// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("KeyRotationPolicy — Rotation Logic")
struct KeyRotationPolicyTests {

    @Test("everySegment rotates when segmentIndex > lastRotation")
    func everySegmentRotates() {
        let policy = KeyRotationPolicy.everySegment
        #expect(policy.shouldRotate(segmentIndex: 1, elapsed: 0, lastRotationSegment: 0))
    }

    @Test("everySegment does not rotate at same segment")
    func everySegmentSameIndex() {
        let policy = KeyRotationPolicy.everySegment
        #expect(!policy.shouldRotate(segmentIndex: 0, elapsed: 0, lastRotationSegment: 0))
    }

    @Test("everySegment rotates at each new segment")
    func everySegmentSequential() {
        let policy = KeyRotationPolicy.everySegment
        #expect(policy.shouldRotate(segmentIndex: 5, elapsed: 30, lastRotationSegment: 4))
        #expect(policy.shouldRotate(segmentIndex: 100, elapsed: 600, lastRotationSegment: 99))
    }

    @Test("interval rotates when elapsed exceeds threshold")
    func intervalRotates() {
        let policy = KeyRotationPolicy.interval(30)
        #expect(policy.shouldRotate(segmentIndex: 5, elapsed: 30))
        #expect(policy.shouldRotate(segmentIndex: 5, elapsed: 31))
    }

    @Test("interval does not rotate when elapsed is below threshold")
    func intervalDoesNotRotate() {
        let policy = KeyRotationPolicy.interval(30)
        #expect(!policy.shouldRotate(segmentIndex: 5, elapsed: 29))
    }

    @Test("interval with zero elapsed does not rotate")
    func intervalZeroElapsed() {
        let policy = KeyRotationPolicy.interval(30)
        #expect(!policy.shouldRotate(segmentIndex: 5, elapsed: 0))
    }

    @Test("everyNSegments rotates at the correct boundary")
    func everyNSegmentsRotates() {
        let policy = KeyRotationPolicy.everyNSegments(10)
        #expect(policy.shouldRotate(segmentIndex: 10, elapsed: 0, lastRotationSegment: 0))
    }

    @Test("everyNSegments does not rotate before boundary")
    func everyNSegmentsBeforeBoundary() {
        let policy = KeyRotationPolicy.everyNSegments(10)
        #expect(!policy.shouldRotate(segmentIndex: 9, elapsed: 0, lastRotationSegment: 0))
    }

    @Test("everyNSegments rotates relative to last rotation segment")
    func everyNSegmentsRelative() {
        let policy = KeyRotationPolicy.everyNSegments(5)
        #expect(!policy.shouldRotate(segmentIndex: 14, elapsed: 0, lastRotationSegment: 10))
        #expect(policy.shouldRotate(segmentIndex: 15, elapsed: 0, lastRotationSegment: 10))
    }

    @Test("manual never rotates automatically")
    func manualNeverRotates() {
        let policy = KeyRotationPolicy.manual
        #expect(!policy.shouldRotate(segmentIndex: 100, elapsed: 3600))
        #expect(!policy.shouldRotate(segmentIndex: 0, elapsed: 0))
    }

    @Test("none never rotates")
    func noneNeverRotates() {
        let policy = KeyRotationPolicy.none
        #expect(!policy.shouldRotate(segmentIndex: 100, elapsed: 3600))
        #expect(!policy.shouldRotate(segmentIndex: 0, elapsed: 0))
    }

    @Test("policyDescription for everySegment")
    func descriptionEverySegment() {
        #expect(KeyRotationPolicy.everySegment.policyDescription == "Rotate every segment")
    }

    @Test("policyDescription for interval")
    func descriptionInterval() {
        #expect(KeyRotationPolicy.interval(60).policyDescription == "Rotate every 60 seconds")
    }

    @Test("policyDescription for everyNSegments")
    func descriptionEveryN() {
        #expect(KeyRotationPolicy.everyNSegments(10).policyDescription == "Rotate every 10 segments")
    }

    @Test("policyDescription for manual")
    func descriptionManual() {
        #expect(KeyRotationPolicy.manual.policyDescription == "Manual rotation")
    }

    @Test("policyDescription for none")
    func descriptionNone() {
        #expect(KeyRotationPolicy.none.policyDescription == "No rotation")
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(KeyRotationPolicy.everySegment == .everySegment)
        #expect(KeyRotationPolicy.everyNSegments(10) == .everyNSegments(10))
        #expect(KeyRotationPolicy.everyNSegments(10) != .everyNSegments(5))
        #expect(KeyRotationPolicy.interval(30) == .interval(30))
        #expect(KeyRotationPolicy.manual == .manual)
        #expect(KeyRotationPolicy.none == .none)
        #expect(KeyRotationPolicy.none != .manual)
    }
}
