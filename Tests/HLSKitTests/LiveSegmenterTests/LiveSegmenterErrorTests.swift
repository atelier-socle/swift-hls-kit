// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("LiveSegmenterError", .timeLimit(.minutes(1)))
struct LiveSegmenterErrorTests {

    @Test("notActive error")
    func notActive() {
        let error = LiveSegmenterError.notActive
        #expect(error == .notActive)
    }

    @Test("noFramesPending error")
    func noFramesPending() {
        let error = LiveSegmenterError.noFramesPending
        #expect(error == .noFramesPending)
    }

    @Test("nonMonotonicTimestamp error")
    func nonMonotonicTimestamp() {
        let error = LiveSegmenterError.nonMonotonicTimestamp(
            "Frame 1.0s < 2.0s"
        )
        #expect(
            error
                == .nonMonotonicTimestamp("Frame 1.0s < 2.0s")
        )
    }

    @Test("maxDurationExceeded error")
    func maxDurationExceeded() {
        let error = LiveSegmenterError.maxDurationExceeded(
            "12.5s exceeds 9.0s"
        )
        #expect(
            error
                == .maxDurationExceeded(
                    "12.5s exceeds 9.0s"
                )
        )
    }

    @Test("invalidConfiguration error")
    func invalidConfiguration() {
        let error = LiveSegmenterError.invalidConfiguration(
            "bad config"
        )
        #expect(
            error == .invalidConfiguration("bad config")
        )
    }

    @Test("Equatable: different errors are not equal")
    func equatableDifferent() {
        let a = LiveSegmenterError.notActive
        let b = LiveSegmenterError.noFramesPending
        #expect(a != b)
    }

    @Test("Error conformance")
    func errorConformance() {
        let error: Error = LiveSegmenterError.notActive
        #expect(error is LiveSegmenterError)
    }
}
