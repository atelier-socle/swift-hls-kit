// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "ManifestParser — Error Paths",
    .timeLimit(.minutes(1))
)
struct ManifestParserErrorPathTests {

    private let parser = ManifestParser()

    @Test("Invalid TARGETDURATION value throws error")
    func invalidTargetDuration() {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:abc
            #EXTINF:6.0,
            seg1.ts
            """
        #expect(throws: ParserError.self) {
            try parser.parse(m3u8)
        }
    }

    @Test("Invalid MEDIA-SEQUENCE value throws error")
    func invalidMediaSequence() {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-MEDIA-SEQUENCE:not_a_number
            #EXTINF:6.0,
            seg1.ts
            """
        #expect(throws: ParserError.self) {
            try parser.parse(m3u8)
        }
    }

    @Test("Invalid DISCONTINUITY-SEQUENCE value throws error")
    func invalidDiscontinuitySequence() {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-DISCONTINUITY-SEQUENCE:xyz
            #EXTINF:6.0,
            seg1.ts
            """
        #expect(throws: ParserError.self) {
            try parser.parse(m3u8)
        }
    }

    @Test("Valid DISCONTINUITY-SEQUENCE parses correctly")
    func validDiscontinuitySequence() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-DISCONTINUITY-SEQUENCE:5
            #EXTINF:6.0,
            seg1.ts
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.discontinuitySequence == 5)
    }

    @Test("Media playlist with EXT-X-SKIP tag")
    func parseMediaWithSkip() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-MEDIA-SEQUENCE:100
            #EXT-X-SKIP:SKIPPED-SEGMENTS=5
            #EXTINF:6.0,
            seg105.ts
            """
        let manifest = try parser.parse(m3u8)
        guard case .media(let media) = manifest else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.skip?.skippedSegments == 5)
    }

    @Test("parseDefine returns nil for unrecognized form")
    func parseDefineReturnsNil() throws {
        let tagParser = TagParser()
        let def = try tagParser.parseDefine("UNKNOWN=\"foo\"")
        #expect(def == nil)
    }

    @Test("parseAttributeList delegates to AttributeParser")
    func parseAttributeList() {
        let tagParser = TagParser()
        let attrs = tagParser.parseAttributeList(
            "KEY1=val1,KEY2=\"val2\""
        )
        #expect(attrs["KEY1"] == "val1")
        #expect(attrs["KEY2"] == "val2")
    }
}
