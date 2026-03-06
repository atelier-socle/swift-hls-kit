// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "TagParser — LL-HLS Edge Cases",
    .timeLimit(.minutes(1))
)
struct TagParserLowLatencyEdgeCaseTests {

    private let parser = TagParser()

    @Test("parsePart with BYTERANGE attribute")
    func parsePartWithByteRange() throws {
        let part = try parser.parsePart(
            "URI=\"part1.ts\",DURATION=0.5,BYTERANGE=\"1000@0\""
        )
        #expect(part.uri == "part1.ts")
        #expect(part.duration == 0.5)
        #expect(part.byteRange?.length == 1000)
        #expect(part.byteRange?.offset == 0)
    }

    @Test("parsePart with BYTERANGE without offset")
    func parsePartByteRangeNoOffset() throws {
        let part = try parser.parsePart(
            "URI=\"part2.ts\",DURATION=0.3,BYTERANGE=\"500\""
        )
        #expect(part.byteRange?.length == 500)
        #expect(part.byteRange?.offset == nil)
    }

    @Test("parsePreloadHint with invalid TYPE throws")
    func parsePreloadHintInvalidType() {
        #expect(throws: ParserError.self) {
            try parser.parsePreloadHint(
                "TYPE=INVALID,URI=\"hint.ts\""
            )
        }
    }

    @Test("parseSkip with RECENTLY-REMOVED-DATERANGES")
    func parseSkipWithRemovedDateRanges() throws {
        let skip = try parser.parseSkip(
            "SKIPPED-SEGMENTS=3,RECENTLY-REMOVED-DATERANGES=\"id1\tid2\tid3\""
        )
        #expect(skip.skippedSegments == 3)
        #expect(skip.recentlyRemovedDateRanges == ["id1", "id2", "id3"])
    }

    @Test("parseSkip with single removed date range")
    func parseSkipSingleDateRange() throws {
        let skip = try parser.parseSkip(
            "SKIPPED-SEGMENTS=1,RECENTLY-REMOVED-DATERANGES=\"range-1\""
        )
        #expect(skip.recentlyRemovedDateRanges == ["range-1"])
    }

    @Test("parseServerControl with CAN-BLOCK-RELOAD false")
    func parseServerControlBlockReloadFalse() {
        let ctrl = parser.parseServerControl(
            "CAN-SKIP-UNTIL=12.0,HOLD-BACK=18.0"
        )
        #expect(ctrl.canBlockReload == false)
        #expect(ctrl.canSkipUntil == 12.0)
        #expect(ctrl.holdBack == 18.0)
    }
}
