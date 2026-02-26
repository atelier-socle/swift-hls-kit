// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - GapHandler

@Suite("GapHandler — Gap Management")
struct GapHandlerTests {

    @Test("Default init has no gaps")
    func defaultInit() {
        let handler = GapHandler()
        #expect(handler.gapCount == 0)
        #expect(handler.maxConsecutiveGaps == 3)
    }

    @Test("markGap adds gap at index")
    func markGap() {
        var handler = GapHandler()
        handler.markGap(at: 5)
        #expect(handler.isGap(at: 5))
        #expect(handler.gapCount == 1)
    }

    @Test("isGap returns false for unmarked index")
    func isGapFalse() {
        let handler = GapHandler()
        #expect(!handler.isGap(at: 0))
    }

    @Test("clearGap removes gap marking")
    func clearGap() {
        var handler = GapHandler()
        handler.markGap(at: 3)
        handler.clearGap(at: 3)
        #expect(!handler.isGap(at: 3))
        #expect(handler.gapCount == 0)
    }

    @Test("gapCount tracks total gaps")
    func gapCount() {
        var handler = GapHandler()
        handler.markGap(at: 0)
        handler.markGap(at: 1)
        handler.markGap(at: 5)
        #expect(handler.gapCount == 3)
    }

    @Test("hasConsecutiveGapAlert triggers on consecutive gaps")
    func consecutiveGapAlert() {
        var handler = GapHandler(maxConsecutiveGaps: 3)
        handler.markGap(at: 5)
        handler.markGap(at: 6)
        handler.markGap(at: 7)
        #expect(handler.hasConsecutiveGapAlert(currentIndex: 7))
    }

    @Test("hasConsecutiveGapAlert does not trigger with gap in middle missing")
    func noAlertWithMissingGap() {
        var handler = GapHandler(maxConsecutiveGaps: 3)
        handler.markGap(at: 5)
        handler.markGap(at: 7)
        #expect(!handler.hasConsecutiveGapAlert(currentIndex: 7))
    }

    @Test("hasConsecutiveGapAlert handles low index")
    func alertLowIndex() {
        var handler = GapHandler(maxConsecutiveGaps: 3)
        handler.markGap(at: 0)
        handler.markGap(at: 1)
        #expect(!handler.hasConsecutiveGapAlert(currentIndex: 1))
    }

    @Test("Custom maxConsecutiveGaps")
    func customMaxConsecutive() {
        var handler = GapHandler(maxConsecutiveGaps: 2)
        handler.markGap(at: 3)
        handler.markGap(at: 4)
        #expect(handler.hasConsecutiveGapAlert(currentIndex: 4))
    }

    @Test("reset clears all gaps")
    func reset() {
        var handler = GapHandler()
        handler.markGap(at: 0)
        handler.markGap(at: 1)
        handler.markGap(at: 2)
        handler.reset()
        #expect(handler.gapCount == 0)
        #expect(!handler.isGap(at: 0))
    }

    @Test("applyToSegments sets isGap on matching indices")
    func applyToSegments() {
        var handler = GapHandler()
        handler.markGap(at: 1)
        handler.markGap(at: 3)
        var segments = [
            Segment(duration: 6, uri: "s0.ts"),
            Segment(duration: 6, uri: "s1.ts"),
            Segment(duration: 6, uri: "s2.ts"),
            Segment(duration: 6, uri: "s3.ts")
        ]
        handler.applyToSegments(&segments)
        #expect(!segments[0].isGap)
        #expect(segments[1].isGap)
        #expect(!segments[2].isGap)
        #expect(segments[3].isGap)
    }

    @Test("applyToSegments ignores out-of-bounds indices")
    func applyOutOfBounds() {
        var handler = GapHandler()
        handler.markGap(at: 10)
        var segments = [Segment(duration: 6, uri: "s0.ts")]
        handler.applyToSegments(&segments)
        #expect(!segments[0].isGap)
    }
}

// MARK: - Equatable

@Suite("GapHandler — Equatable")
struct GapHandlerEquatableTests {

    @Test("Identical handlers are equal")
    func identical() {
        var a = GapHandler()
        a.markGap(at: 1)
        var b = GapHandler()
        b.markGap(at: 1)
        #expect(a == b)
    }

    @Test("Different handlers are not equal")
    func different() {
        var a = GapHandler()
        a.markGap(at: 1)
        var b = GapHandler()
        b.markGap(at: 2)
        #expect(a != b)
    }
}
