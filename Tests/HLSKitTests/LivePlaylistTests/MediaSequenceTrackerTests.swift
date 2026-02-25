// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MediaSequenceTracker", .timeLimit(.minutes(1)))
struct MediaSequenceTrackerTests {

    @Test("Initial values are zero")
    func initialValues() {
        let tracker = MediaSequenceTracker()
        #expect(tracker.mediaSequence == 0)
        #expect(tracker.discontinuitySequence == 0)
        #expect(tracker.totalSegmentsAdded == 0)
        #expect(tracker.totalSegmentsEvicted == 0)
        #expect(tracker.pendingDiscontinuity == false)
    }

    @Test("segmentAdded increments totalSegmentsAdded")
    func segmentAdded() {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.segmentAdded(index: 1)
        #expect(tracker.totalSegmentsAdded == 2)
        #expect(tracker.mediaSequence == 0)
    }

    @Test("segmentEvicted increments mediaSequence")
    func segmentEvicted() {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.segmentAdded(index: 1)
        tracker.segmentEvicted(index: 0)
        #expect(tracker.mediaSequence == 1)
        #expect(tracker.totalSegmentsEvicted == 1)
    }

    @Test("Multiple evictions increment mediaSequence correctly")
    func multipleEvictions() {
        var tracker = MediaSequenceTracker()
        for i in 0..<5 {
            tracker.segmentAdded(index: i)
        }
        tracker.segmentEvicted(index: 0)
        tracker.segmentEvicted(index: 1)
        tracker.segmentEvicted(index: 2)
        #expect(tracker.mediaSequence == 3)
        #expect(tracker.totalSegmentsEvicted == 3)
    }

    @Test("discontinuityInserted sets pending")
    func discontinuityInserted() {
        var tracker = MediaSequenceTracker()
        tracker.discontinuityInserted()
        #expect(tracker.pendingDiscontinuity == true)
    }

    @Test("Discontinuity assigned to next segment")
    func discontinuityAssigned() {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.discontinuityInserted()
        tracker.segmentAdded(index: 1)
        #expect(tracker.pendingDiscontinuity == false)
        #expect(tracker.hasDiscontinuity(at: 1) == true)
        #expect(tracker.hasDiscontinuity(at: 0) == false)
    }

    @Test("Evicting segment with discontinuity bumps discSeq")
    func evictDiscontinuity() {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.discontinuityInserted()
        tracker.segmentAdded(index: 1)
        tracker.segmentEvicted(index: 0)
        #expect(tracker.discontinuitySequence == 0)
        tracker.segmentEvicted(index: 1)
        #expect(tracker.discontinuitySequence == 1)
    }

    @Test("Evicting segment without discontinuity: no change")
    func evictNoDiscontinuity() {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.segmentAdded(index: 1)
        tracker.segmentEvicted(index: 0)
        #expect(tracker.discontinuitySequence == 0)
    }

    @Test("hasDiscontinuity returns correct value")
    func hasDiscontinuity() {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.discontinuityInserted()
        tracker.segmentAdded(index: 1)
        tracker.segmentAdded(index: 2)
        #expect(tracker.hasDiscontinuity(at: 0) == false)
        #expect(tracker.hasDiscontinuity(at: 1) == true)
        #expect(tracker.hasDiscontinuity(at: 2) == false)
    }

    @Test("Complex scenario: add/evict/discontinuity interleaved")
    func complexScenario() {
        var tracker = MediaSequenceTracker()

        // Add 3 segments
        tracker.segmentAdded(index: 0)
        tracker.segmentAdded(index: 1)
        tracker.segmentAdded(index: 2)
        #expect(tracker.mediaSequence == 0)

        // Evict first 2
        tracker.segmentEvicted(index: 0)
        tracker.segmentEvicted(index: 1)
        #expect(tracker.mediaSequence == 2)

        // Discontinuity before next
        tracker.discontinuityInserted()
        tracker.segmentAdded(index: 3)
        #expect(tracker.hasDiscontinuity(at: 3) == true)

        // Evict segment 2 (no disc) → discSeq unchanged
        tracker.segmentEvicted(index: 2)
        #expect(tracker.mediaSequence == 3)
        #expect(tracker.discontinuitySequence == 0)

        // Evict segment 3 (has disc) → discSeq bumps
        tracker.segmentEvicted(index: 3)
        #expect(tracker.mediaSequence == 4)
        #expect(tracker.discontinuitySequence == 1)

        #expect(tracker.totalSegmentsAdded == 4)
        #expect(tracker.totalSegmentsEvicted == 4)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = MediaSequenceTracker()
        let b = MediaSequenceTracker()
        #expect(a == b)

        var c = MediaSequenceTracker()
        c.segmentAdded(index: 0)
        #expect(a != c)
    }
}
