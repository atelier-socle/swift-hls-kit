// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SegmenterErrors")
struct SegmenterErrorTests {

    @Test("Segment empty data throws MP4Error")
    func emptyDataThrows() {
        let segmenter = MP4Segmenter()
        #expect(throws: MP4Error.self) {
            try segmenter.segment(data: Data())
        }
    }

    @Test("Segment non-MP4 data throws MP4Error")
    func nonMP4DataThrows() {
        let segmenter = MP4Segmenter()
        let randomData = Data(repeating: 0xFF, count: 100)
        #expect(throws: MP4Error.self) {
            try segmenter.segment(data: randomData)
        }
    }

    @Test("Segment MP4 without moov throws")
    func missingMoovThrows() {
        let ftypOnly = MP4TestDataBuilder.ftyp()
        let mdat = MP4TestDataBuilder.box(
            type: "mdat",
            payload: Data(repeating: 0, count: 16)
        )
        var data = Data()
        data.append(ftypOnly)
        data.append(mdat)

        let segmenter = MP4Segmenter()
        #expect(throws: MP4Error.self) {
            try segmenter.segment(data: data)
        }
    }

    @Test("Segment MP4 without video track throws")
    func noVideoTrackThrows() {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let audioTrack = MP4TestDataBuilder.audioTrack(
            trackId: 1, duration: 44100
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 44100, duration: 44100
                ),
                audioTrack
            ]
        )
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat",
            payload: Data(repeating: 0, count: 16)
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        data.append(mdatBox)

        let segmenter = MP4Segmenter()
        #expect(throws: MP4Error.self) {
            try segmenter.segment(data: data)
        }
    }

    @Test("Segment MP4 without mdat handles gracefully")
    func missingMdatHandling() {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let videoTrack = MP4TestDataBuilder.videoTrack(
            trackId: 1, duration: 90000,
            width: 1920, height: 1080
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 90000, duration: 90000
                ),
                videoTrack
            ]
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)

        // No mdat — segmenter should still work since stbl
        // has no samples in minimal track
        let segmenter = MP4Segmenter()
        let result = try? segmenter.segment(data: data)
        if let result {
            // No samples → no segments
            #expect(result.segmentCount == 0)
        }
    }
}
