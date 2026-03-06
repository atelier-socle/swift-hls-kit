// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "RFC8216 Media Rules — Version Requirements",
    .timeLimit(.minutes(1))
)
struct RFC8216MediaVersionTests {

    private let validator = HLSValidator()

    @Test("I-frames-only playlist requires version >= 4")
    func iFramesOnlyRequiresVersion4() {
        let playlist = MediaPlaylist(
            version: .v3,
            targetDuration: 6,
            iFramesOnly: true,
            segments: [
                Segment(duration: 6.0, uri: "seg1.ts")
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let versionErrors = report.results.filter {
            ($0.ruleId ?? "").contains("version")
        }
        #expect(!versionErrors.isEmpty)
    }

    @Test("Encryption with KEY-FORMAT requires version >= 5")
    func keyFormatRequiresVersion5() {
        let playlist = MediaPlaylist(
            version: .v4,
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0,
                    uri: "seg1.ts",
                    key: EncryptionKey(
                        method: .aes128,
                        uri: "key.bin",
                        keyFormat: "identity"
                    )
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let versionErrors = report.results.filter {
            ($0.ruleId ?? "").contains("version")
        }
        #expect(!versionErrors.isEmpty)
    }

    @Test("Encryption with KEY-FORMAT-VERSIONS requires version >= 5")
    func keyFormatVersionsRequiresVersion5() {
        let playlist = MediaPlaylist(
            version: .v4,
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0,
                    uri: "seg1.ts",
                    key: EncryptionKey(
                        method: .aes128,
                        uri: "key.bin",
                        keyFormatVersions: "1"
                    )
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let versionErrors = report.results.filter {
            ($0.ruleId ?? "").contains("version")
        }
        #expect(!versionErrors.isEmpty)
    }
}
