// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LLHLSPlaylistRenderer", .timeLimit(.minutes(1)))
struct LLHLSPlaylistRendererTests {

    // MARK: - EXT-X-PART-INF

    @Test("renderPartInf formats correctly")
    func renderPartInf() {
        let result = LLHLSPlaylistRenderer.renderPartInf(
            partTargetDuration: 0.33334
        )
        #expect(result == "#EXT-X-PART-INF:PART-TARGET=0.33334")
    }

    @Test("renderPartInf with 5 decimal precision")
    func renderPartInfPrecision() {
        let result = LLHLSPlaylistRenderer.renderPartInf(
            partTargetDuration: 0.2
        )
        #expect(result == "#EXT-X-PART-INF:PART-TARGET=0.20000")
    }

    // MARK: - EXT-X-PART

    @Test("renderPart with independent flag")
    func renderPartIndependent() {
        let partial = LLPartialSegment(
            duration: 0.33334,
            uri: "seg42.1.mp4",
            isIndependent: true,
            segmentIndex: 42,
            partialIndex: 1
        )

        let result = LLHLSPlaylistRenderer.renderPart(partial)
        #expect(
            result.contains("DURATION=0.33334")
        )
        #expect(
            result.contains("URI=\"seg42.1.mp4\"")
        )
        #expect(result.contains("INDEPENDENT=YES"))
    }

    @Test("renderPart without independent flag")
    func renderPartNotIndependent() {
        let partial = LLPartialSegment(
            duration: 0.33334,
            uri: "seg42.2.mp4",
            isIndependent: false,
            segmentIndex: 42,
            partialIndex: 2
        )

        let result = LLHLSPlaylistRenderer.renderPart(partial)
        #expect(!result.contains("INDEPENDENT"))
    }

    @Test("renderPart with GAP")
    func renderPartGap() {
        let partial = LLPartialSegment(
            duration: 0.33334,
            uri: "seg0.0.mp4",
            isIndependent: true,
            isGap: true,
            segmentIndex: 0,
            partialIndex: 0
        )

        let result = LLHLSPlaylistRenderer.renderPart(partial)
        #expect(result.contains("GAP=YES"))
    }

    @Test("renderPart with byte range")
    func renderPartByteRange() {
        let partial = LLPartialSegment(
            duration: 0.33334,
            uri: "seg0.0.mp4",
            isIndependent: true,
            byteRange: ByteRange(length: 1024, offset: 512),
            segmentIndex: 0,
            partialIndex: 0
        )

        let result = LLHLSPlaylistRenderer.renderPart(partial)
        #expect(result.contains("BYTERANGE=\"1024@512\""))
    }

    @Test("renderPart byte range without offset")
    func renderPartByteRangeNoOffset() {
        let partial = LLPartialSegment(
            duration: 0.33334,
            uri: "seg0.0.mp4",
            isIndependent: true,
            byteRange: ByteRange(length: 2048),
            segmentIndex: 0,
            partialIndex: 0
        )

        let result = LLHLSPlaylistRenderer.renderPart(partial)
        #expect(result.contains("BYTERANGE=\"2048\""))
        #expect(!result.contains("@"))
    }

    // MARK: - EXT-X-PRELOAD-HINT

    @Test("renderPreloadHint for PART type")
    func renderPreloadHintPart() {
        let hint = PreloadHint(
            type: .part, uri: "seg42.4.mp4"
        )

        let result = LLHLSPlaylistRenderer.renderPreloadHint(hint)
        #expect(
            result
                == "#EXT-X-PRELOAD-HINT:TYPE=PART,URI=\"seg42.4.mp4\""
        )
    }

    @Test("renderPreloadHint for MAP type with byte range")
    func renderPreloadHintMap() {
        let hint = PreloadHint(
            type: .map,
            uri: "init.mp4",
            byteRangeStart: 0,
            byteRangeLength: 612
        )

        let result = LLHLSPlaylistRenderer.renderPreloadHint(hint)
        #expect(result.contains("TYPE=MAP"))
        #expect(result.contains("URI=\"init.mp4\""))
        #expect(result.contains("BYTERANGE-START=0"))
        #expect(result.contains("BYTERANGE-LENGTH=612"))
    }

    // MARK: - Segment With Partials

    @Test("Completed segment: partials before EXTINF")
    func completedSegmentPartials() {
        let partials = [
            LLPartialSegment(
                duration: 0.33334, uri: "seg0.0.mp4",
                isIndependent: true, segmentIndex: 0,
                partialIndex: 0
            ),
            LLPartialSegment(
                duration: 0.33334, uri: "seg0.1.mp4",
                isIndependent: false, segmentIndex: 0,
                partialIndex: 1
            )
        ]

        let segment = makeLiveSegment(
            index: 0, duration: 2.0, filename: "seg0.m4s"
        )

        let result = LLHLSPlaylistRenderer.renderSegmentWithPartials(
            segment: segment,
            partials: partials,
            isCurrentSegment: false
        )

        let lines = result.components(separatedBy: "\n")
        // EXT-X-PART lines come before EXTINF
        #expect(lines[0].hasPrefix("#EXT-X-PART:"))
        #expect(lines[1].hasPrefix("#EXT-X-PART:"))
        #expect(lines[2].hasPrefix("#EXTINF:"))
        #expect(lines[3] == "seg0.m4s")
    }

    @Test("Current incomplete segment: no EXTINF")
    func currentSegmentNoExtinf() {
        let partials = [
            LLPartialSegment(
                duration: 0.33334, uri: "seg1.0.mp4",
                isIndependent: true, segmentIndex: 1,
                partialIndex: 0
            )
        ]

        let result = LLHLSPlaylistRenderer.renderSegmentWithPartials(
            segment: nil,
            partials: partials,
            isCurrentSegment: true
        )

        #expect(result.contains("#EXT-X-PART:"))
        #expect(!result.contains("#EXTINF:"))
    }

    @Test("Duration precision: 5 decimal places")
    func durationPrecision() {
        let partial = LLPartialSegment(
            duration: 0.2,
            uri: "seg0.0.mp4",
            isIndependent: true,
            segmentIndex: 0,
            partialIndex: 0
        )

        let result = LLHLSPlaylistRenderer.renderPart(partial)
        #expect(result.contains("DURATION=0.20000"))
    }

    // MARK: - Helpers

    private func makeLiveSegment(
        index: Int,
        duration: TimeInterval,
        filename: String
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(),
            duration: duration,
            timestamp: .zero,
            isIndependent: true,
            filename: filename,
            frameCount: 0,
            codecs: []
        )
    }
}
