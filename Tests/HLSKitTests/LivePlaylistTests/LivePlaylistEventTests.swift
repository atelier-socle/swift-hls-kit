// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePlaylistEvent", .timeLimit(.minutes(1)))
struct LivePlaylistEventTests {

    @Test("segmentAdded carries index and duration")
    func segmentAdded() {
        let event = LivePlaylistEvent.segmentAdded(
            index: 3, duration: 6.006
        )
        if case .segmentAdded(let idx, let dur) = event {
            #expect(idx == 3)
            #expect(dur == 6.006)
        } else {
            Issue.record("Expected segmentAdded")
        }
    }

    @Test("segmentRemoved carries index")
    func segmentRemoved() {
        let event = LivePlaylistEvent.segmentRemoved(index: 2)
        if case .segmentRemoved(let idx) = event {
            #expect(idx == 2)
        } else {
            Issue.record("Expected segmentRemoved")
        }
    }

    @Test("playlistUpdated carries mediaSequence")
    func playlistUpdated() {
        let event = LivePlaylistEvent.playlistUpdated(
            mediaSequence: 5
        )
        if case .playlistUpdated(let seq) = event {
            #expect(seq == 5)
        } else {
            Issue.record("Expected playlistUpdated")
        }
    }

    @Test("streamEnded case")
    func streamEnded() {
        let event = LivePlaylistEvent.streamEnded
        #expect(event == .streamEnded)
    }

    @Test("Equatable: same events are equal")
    func equatable() {
        let a = LivePlaylistEvent.segmentAdded(
            index: 1, duration: 6.0
        )
        let b = LivePlaylistEvent.segmentAdded(
            index: 1, duration: 6.0
        )
        #expect(a == b)
    }

    @Test("Equatable: different events are not equal")
    func notEquatable() {
        let a = LivePlaylistEvent.segmentAdded(
            index: 1, duration: 6.0
        )
        let b = LivePlaylistEvent.segmentRemoved(index: 1)
        #expect(a != b)
    }
}
