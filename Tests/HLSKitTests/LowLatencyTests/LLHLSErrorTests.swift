// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LLHLSError", .timeLimit(.minutes(1)))
struct LLHLSErrorTests {

    @Test("streamAlreadyEnded description")
    func streamAlreadyEnded() {
        let error = LLHLSError.streamAlreadyEnded
        #expect(error.description.contains("ended"))
    }

    @Test("firstPartialMustBeIndependent description")
    func firstPartialMustBeIndependent() {
        let error = LLHLSError.firstPartialMustBeIndependent
        #expect(error.description.contains("independent"))
    }

    @Test("partialDurationExceedsTarget description")
    func partialDurationExceedsTarget() {
        let error = LLHLSError.partialDurationExceedsTarget(
            actual: 0.6, target: 0.33
        )
        #expect(error.description.contains("0.6"))
        #expect(error.description.contains("0.33"))
    }

    @Test("invalidConfiguration description")
    func invalidConfiguration() {
        let error = LLHLSError.invalidConfiguration(
            "negative duration"
        )
        #expect(error.description.contains("negative duration"))
    }

    @Test("segmentNotInProgress description")
    func segmentNotInProgress() {
        let error = LLHLSError.segmentNotInProgress
        #expect(error.description.contains("progress"))
    }

    @Test("Equatable: same cases are equal")
    func equatable() {
        #expect(
            LLHLSError.streamAlreadyEnded
                == LLHLSError.streamAlreadyEnded
        )
        #expect(
            LLHLSError.invalidConfiguration("a")
                == LLHLSError.invalidConfiguration("a")
        )
    }

    @Test("Equatable: different cases are not equal")
    func notEqual() {
        #expect(
            LLHLSError.streamAlreadyEnded
                != LLHLSError.segmentNotInProgress
        )
        #expect(
            LLHLSError.invalidConfiguration("a")
                != LLHLSError.invalidConfiguration("b")
        )
    }
}
