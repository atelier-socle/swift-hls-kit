// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("RFC8216Rules — LL-HLS")
struct RFC8216LLHLSTests {

    @Test("PART without PART-INF — error")
    func partWithoutPartInf() {
        let playlist = MediaPlaylist(
            targetDuration: 4,
            segments: [
                Segment(duration: 4.0, uri: "seg.ts")
            ],
            partialSegments: [
                PartialSegment(uri: "p.mp4", duration: 1.0)
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216bis-part-inf"
            })
    }

    @Test("PART duration exceeds PART-TARGET — error")
    func partDurationExceedsTarget() {
        let playlist = MediaPlaylist(
            targetDuration: 4,
            segments: [
                Segment(duration: 4.0, uri: "seg.ts")
            ],
            partTargetDuration: 1.0,
            serverControl: ServerControl(
                canBlockReload: true, partHoldBack: 3.0
            ),
            partialSegments: [
                PartialSegment(uri: "p.mp4", duration: 1.5)
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216bis-part-duration"
            })
    }

    @Test("Missing SERVER-CONTROL — warning")
    func missingServerControl() {
        let playlist = MediaPlaylist(
            targetDuration: 4,
            segments: [
                Segment(duration: 4.0, uri: "seg.ts")
            ],
            partTargetDuration: 1.0,
            partialSegments: [
                PartialSegment(uri: "p.mp4", duration: 1.0)
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216bis-server-control"
            })
    }

    @Test("PART-HOLD-BACK too low — warning")
    func holdBackTooLow() {
        let playlist = MediaPlaylist(
            targetDuration: 4,
            segments: [
                Segment(duration: 4.0, uri: "seg.ts")
            ],
            partTargetDuration: 1.0,
            serverControl: ServerControl(
                canBlockReload: true, partHoldBack: 2.0
            ),
            partialSegments: [
                PartialSegment(uri: "p.mp4", duration: 1.0)
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216bis-hold-back"
            })
    }

    @Test("LL-HLS version < 9 — error")
    func llhlsVersionTooLow() {
        let playlist = MediaPlaylist(
            version: .v7,
            targetDuration: 4,
            segments: [
                Segment(duration: 4.0, uri: "seg.ts")
            ],
            partTargetDuration: 1.0,
            serverControl: ServerControl(
                canBlockReload: true, partHoldBack: 3.0
            ),
            partialSegments: [
                PartialSegment(uri: "p.mp4", duration: 1.0)
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        #expect(
            results.contains {
                $0.ruleId == "RFC8216bis-version"
            })
    }

    @Test("Valid LL-HLS — no errors")
    func validLLHLS() {
        let playlist = MediaPlaylist(
            version: .v9,
            targetDuration: 4,
            segments: [
                Segment(duration: 4.0, uri: "seg.ts")
            ],
            partTargetDuration: 1.0,
            serverControl: ServerControl(
                canBlockReload: true, partHoldBack: 3.012
            ),
            partialSegments: [
                PartialSegment(uri: "p.mp4", duration: 1.0)
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        let llErrors = results.filter {
            $0.ruleId?.hasPrefix("RFC8216bis") == true
                && $0.severity == .error
        }
        #expect(llErrors.isEmpty)
    }

    @Test("Non-LL-HLS — no LL-HLS findings")
    func nonLLHLS() {
        let playlist = MediaPlaylist(
            targetDuration: 10,
            playlistType: .vod,
            hasEndList: true,
            segments: [
                Segment(duration: 9.0, uri: "seg.ts")
            ]
        )
        let results = RFC8216Rules.validate(playlist)
        let llResults = results.filter {
            $0.ruleId?.hasPrefix("RFC8216bis") == true
        }
        #expect(llResults.isEmpty)
    }
}
