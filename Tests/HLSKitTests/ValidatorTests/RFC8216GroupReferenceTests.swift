// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "RFC8216 Rules — Group Reference Validation",
    .timeLimit(.minutes(1))
)
struct RFC8216GroupReferenceTests {

    private let validator = HLSValidator()

    @Test("Variant referencing undefined SUBTITLES group produces error")
    func undefinedSubtitlesGroup() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    subtitles: "subs-nonexistent"
                )
            ],
            renditions: [
                Rendition(
                    type: .subtitles,
                    groupId: "subs-real",
                    name: "English",
                    uri: "subs-en.m3u8"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let errors = report.results.filter {
            $0.ruleId == "RFC8216-4.3.4.2-subtitle-ref"
        }
        #expect(!errors.isEmpty)
    }

    @Test(
        "Variant referencing undefined CLOSED-CAPTIONS group produces error"
    )
    func undefinedClosedCaptionsGroup() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    closedCaptions: .groupId("cc-nonexistent")
                )
            ],
            renditions: [
                Rendition(
                    type: .closedCaptions,
                    groupId: "cc-real",
                    name: "English CC",
                    instreamId: "CC1"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let errors = report.results.filter {
            $0.ruleId == "RFC8216-4.3.4.2-cc-ref"
        }
        #expect(!errors.isEmpty)
    }
}
