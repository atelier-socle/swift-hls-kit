// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("PreloadHint (LL-HLS)", .timeLimit(.minutes(1)))
struct PreloadHintLLTests {

    @Test("Create PART hint")
    func createPartHint() {
        let hint = PreloadHint(
            type: .part, uri: "seg42.4.mp4"
        )

        #expect(hint.type == .part)
        #expect(hint.uri == "seg42.4.mp4")
        #expect(hint.byteRangeStart == nil)
        #expect(hint.byteRangeLength == nil)
    }

    @Test("Create MAP hint")
    func createMapHint() {
        let hint = PreloadHint(
            type: .map, uri: "init.mp4"
        )

        #expect(hint.type == .map)
        #expect(hint.uri == "init.mp4")
    }

    @Test("PART hint with byte range")
    func partHintWithByteRange() {
        let hint = PreloadHint(
            type: .part,
            uri: "seg0.0.mp4",
            byteRangeStart: 1024,
            byteRangeLength: 512
        )

        #expect(hint.byteRangeStart == 1024)
        #expect(hint.byteRangeLength == 512)
    }

    @Test("HintType raw values")
    func hintTypeRawValues() {
        #expect(PreloadHintType.part.rawValue == "PART")
        #expect(PreloadHintType.map.rawValue == "MAP")
    }

    @Test("Sendable: usable across tasks")
    func sendable() async {
        let hint = PreloadHint(
            type: .part, uri: "seg0.0.mp4"
        )

        let result = await Task.detached {
            hint.uri
        }.value

        #expect(result == "seg0.0.mp4")
    }
}
