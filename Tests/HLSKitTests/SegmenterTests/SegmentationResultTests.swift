// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SegmentationResult")
struct SegmentationResultTests {

    // MARK: - Computed Properties

    @Test("totalDuration — sums segment durations")
    func totalDuration() {
        let result = makeResult(durations: [6.0, 6.0, 3.0])
        #expect(result.totalDuration == 15.0)
    }

    @Test("totalDuration — empty segments returns 0")
    func totalDurationEmpty() {
        let result = makeResult(durations: [])
        #expect(result.totalDuration == 0.0)
    }

    @Test("segmentCount — returns number of segments")
    func segmentCount() {
        let result = makeResult(durations: [6.0, 6.0, 3.0])
        #expect(result.segmentCount == 3)
    }

    @Test("segmentCount — empty returns 0")
    func segmentCountEmpty() {
        let result = makeResult(durations: [])
        #expect(result.segmentCount == 0)
    }

    @Test("fileInfo — preserved from input")
    func fileInfoPreserved() {
        let result = makeResult(durations: [6.0])
        #expect(result.fileInfo.timescale == 90000)
    }

    @Test("config — preserved from input")
    func configPreserved() {
        let config = SegmentationConfig(
            targetSegmentDuration: 10.0
        )
        let result = SegmentationResult(
            initSegment: Data(),
            mediaSegments: [],
            playlist: nil,
            fileInfo: makeFileInfo(),
            config: config
        )
        #expect(result.config.targetSegmentDuration == 10.0)
    }

    // MARK: - MediaSegmentOutput

    @Test("MediaSegmentOutput — Hashable conformance")
    func mediaSegmentOutputHashable() {
        let a = MediaSegmentOutput(
            index: 0, data: Data([0x01]),
            duration: 6.0, filename: "seg_0.m4s",
            byteRangeOffset: nil, byteRangeLength: nil
        )
        let b = MediaSegmentOutput(
            index: 0, data: Data([0x01]),
            duration: 6.0, filename: "seg_0.m4s",
            byteRangeOffset: nil, byteRangeLength: nil
        )
        #expect(a == b)
    }

    @Test("MediaSegmentOutput — byte range fields")
    func mediaSegmentOutputByteRange() {
        let seg = MediaSegmentOutput(
            index: 0, data: Data(),
            duration: 6.0, filename: "seg_0.m4s",
            byteRangeOffset: 100, byteRangeLength: 500
        )
        #expect(seg.byteRangeOffset == 100)
        #expect(seg.byteRangeLength == 500)
    }

    // MARK: - Helpers

    private func makeFileInfo() -> MP4FileInfo {
        MP4FileInfo(
            timescale: 90000,
            duration: 270000,
            brands: ["isom"],
            tracks: []
        )
    }

    private func makeResult(
        durations: [Double]
    ) -> SegmentationResult {
        let segments = durations.enumerated().map { index, dur in
            MediaSegmentOutput(
                index: index, data: Data(),
                duration: dur,
                filename: "segment_\(index).m4s",
                byteRangeOffset: nil,
                byteRangeLength: nil
            )
        }
        return SegmentationResult(
            initSegment: Data(),
            mediaSegments: segments,
            playlist: nil,
            fileInfo: makeFileInfo(),
            config: SegmentationConfig()
        )
    }
}
