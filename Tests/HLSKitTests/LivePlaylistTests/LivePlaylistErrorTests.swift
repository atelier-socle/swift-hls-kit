// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePlaylistError", .timeLimit(.minutes(1)))
struct LivePlaylistErrorTests {

    @Test("streamEnded case")
    func streamEnded() {
        let err = LivePlaylistError.streamEnded
        #expect(err == .streamEnded)
    }

    @Test("invalidSegmentIndex carries message")
    func invalidSegmentIndex() {
        let err = LivePlaylistError.invalidSegmentIndex("bad")
        if case .invalidSegmentIndex(let msg) = err {
            #expect(msg == "bad")
        } else {
            Issue.record("Expected invalidSegmentIndex")
        }
    }

    @Test("parentSegmentNotFound carries index")
    func parentNotFound() {
        let err = LivePlaylistError.parentSegmentNotFound(42)
        if case .parentSegmentNotFound(let idx) = err {
            #expect(idx == 42)
        } else {
            Issue.record("Expected parentSegmentNotFound")
        }
    }

    @Test("invalidConfiguration carries message")
    func invalidConfig() {
        let err = LivePlaylistError.invalidConfiguration("oops")
        if case .invalidConfiguration(let msg) = err {
            #expect(msg == "oops")
        } else {
            Issue.record("Expected invalidConfiguration")
        }
    }

    @Test("Equatable: same cases are equal")
    func equatable() {
        #expect(
            LivePlaylistError.streamEnded
                == LivePlaylistError.streamEnded
        )
        #expect(
            LivePlaylistError.parentSegmentNotFound(1)
                == LivePlaylistError.parentSegmentNotFound(1)
        )
    }

    @Test("Equatable: different cases are not equal")
    func notEquatable() {
        #expect(
            LivePlaylistError.streamEnded
                != LivePlaylistError.parentSegmentNotFound(0)
        )
    }
}
