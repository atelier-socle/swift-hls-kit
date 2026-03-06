// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SubtitleCodec — Codec Identifiers")
struct SubtitleCodecTests {

    @Test("WebVTT raw value")
    func webvttRawValue() {
        #expect(SubtitleCodec.webvtt.rawValue == "wvtt")
    }

    @Test("IMSC1 raw value")
    func imsc1RawValue() {
        #expect(
            SubtitleCodec.imsc1.rawValue == "stpp.ttml.im1t"
        )
    }

    @Test("CaseIterable contains all cases")
    func caseIterable() {
        let all = SubtitleCodec.allCases
        #expect(all.count == 2)
        #expect(all.contains(.webvtt))
        #expect(all.contains(.imsc1))
    }

    @Test("Equatable")
    func equatable() {
        #expect(SubtitleCodec.webvtt == SubtitleCodec.webvtt)
        #expect(SubtitleCodec.webvtt != SubtitleCodec.imsc1)
    }

    @Test("Sendable conformance")
    func sendable() {
        let codec = SubtitleCodec.imsc1
        let fn: @Sendable () -> String = { codec.rawValue }
        #expect(fn() == "stpp.ttml.im1t")
    }
}
