// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "AppleHLSRules — VIDEO-RANGE & SUPPLEMENTAL-CODECS",
    .timeLimit(.minutes(1))
)
struct AppleHLSVideoRangeValidationTests {

    private let validator = HLSValidator()

    @Test("Mixed VIDEO-RANGE across variants produces warning")
    func mixedVideoRangeWarning() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "sdr.m3u8",
                    videoRange: .sdr
                ),
                Variant(
                    bandwidth: 2_000_000,
                    uri: "pq.m3u8",
                    videoRange: .pq
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .appleHLS)
        let rangeWarnings = report.results.filter {
            $0.ruleId == "APPLE-2.7-video-range"
        }
        #expect(!rangeWarnings.isEmpty)
        #expect(rangeWarnings[0].severity == .warning)
    }

    @Test("Same VIDEO-RANGE across variants produces no warning")
    func sameVideoRangeNoWarning() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    videoRange: .sdr
                ),
                Variant(
                    bandwidth: 2_000_000,
                    uri: "high.m3u8",
                    videoRange: .sdr
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .appleHLS)
        let rangeWarnings = report.results.filter {
            $0.ruleId == "APPLE-2.7-video-range"
        }
        #expect(rangeWarnings.isEmpty)
    }

    @Test("SUPPLEMENTAL-CODECS without CODECS produces warning")
    func supplementalCodecsWithoutCodecsWarning() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    supplementalCodecs: "dvh1.05.06"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .appleHLS)
        let warnings = report.results.filter {
            $0.ruleId == "APPLE-2.8-supplemental-codecs"
        }
        #expect(!warnings.isEmpty)
        #expect(warnings[0].severity == .warning)
    }

    @Test("SUPPLEMENTAL-CODECS with CODECS produces no warning")
    func supplementalCodecsWithCodecsNoWarning() {
        let playlist = MasterPlaylist(
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "low.m3u8",
                    codecs: "hvc1.2.4.L150.B0",
                    supplementalCodecs: "dvh1.05.06"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .appleHLS)
        let warnings = report.results.filter {
            $0.ruleId == "APPLE-2.8-supplemental-codecs"
        }
        #expect(warnings.isEmpty)
    }
}
