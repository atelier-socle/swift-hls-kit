// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("ParserError")
struct ParserErrorTests {

    @Test("Every error case has a non-empty errorDescription")
    func allCasesHaveDescription() {
        let cases: [ParserError] = [
            .emptyManifest,
            .missingHeader,
            .ambiguousPlaylistType,
            .missingRequiredTag("EXT-X-TARGETDURATION"),
            .missingRequiredAttribute(tag: "EXT-X-STREAM-INF", attribute: "BANDWIDTH"),
            .invalidAttributeValue(tag: "EXT-X-KEY", attribute: "METHOD", value: "INVALID"),
            .invalidTagFormat(tag: "EXT-X-VERSION", line: 2),
            .invalidDuration(line: 5),
            .missingURI(afterTag: "EXT-X-STREAM-INF", line: 3),
            .invalidVersion("99"),
            .parsingFailed(reason: "test", line: 1),
            .parsingFailed(reason: "no line", line: nil)
        ]

        for error in cases {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.isEmpty == false)
        }
    }

    @Test("Error equality — Hashable conformance")
    func hashableConformance() {
        let a = ParserError.missingHeader
        let b = ParserError.missingHeader
        #expect(a == b)

        let c = ParserError.emptyManifest
        #expect(a != c)
    }

    @Test("Errors with same associated values are equal")
    func equalityWithAssociatedValues() {
        let a = ParserError.missingRequiredTag("EXT-X-TARGETDURATION")
        let b = ParserError.missingRequiredTag("EXT-X-TARGETDURATION")
        #expect(a == b)

        let c = ParserError.missingRequiredTag("EXT-X-VERSION")
        #expect(a != c)
    }

    @Test("emptyManifest description")
    func emptyManifestDescription() {
        let error = ParserError.emptyManifest
        #expect(error.errorDescription?.contains("empty") == true)
    }

    @Test("missingHeader description")
    func missingHeaderDescription() {
        let error = ParserError.missingHeader
        #expect(error.errorDescription?.contains("EXTM3U") == true)
    }

    @Test("ambiguousPlaylistType description")
    func ambiguousDescription() {
        let error = ParserError.ambiguousPlaylistType
        #expect(error.errorDescription?.contains("determine") == true)
    }

    @Test("invalidVersion description includes version string")
    func invalidVersionDescription() {
        let error = ParserError.invalidVersion("99")
        #expect(error.errorDescription?.contains("99") == true)
    }

    @Test("parsingFailed with line number includes line")
    func parsingFailedWithLine() {
        let error = ParserError.parsingFailed(reason: "unexpected", line: 42)
        #expect(error.errorDescription?.contains("42") == true)
        #expect(error.errorDescription?.contains("unexpected") == true)
    }

    @Test("parsingFailed without line number omits line")
    func parsingFailedWithoutLine() {
        let error = ParserError.parsingFailed(reason: "general failure", line: nil)
        #expect(error.errorDescription?.contains("general failure") == true)
    }
}
