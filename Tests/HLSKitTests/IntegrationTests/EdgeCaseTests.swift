// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Edge Cases")
struct EdgeCaseTests {

    // MARK: - Minimal inputs

    @Test("MP4 with single sample → single segment")
    func singleSample() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 1,
            keyframeInterval: 1,
            sampleSize: 100
        )
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.segmentCount == 1)
        let seg = try #require(result.mediaSegments.first)
        #expect(seg.duration > 0)
    }

    @Test("MP4 with two samples, one keyframe → 1 segment")
    func twoSamplesOneKeyframe() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 2,
            keyframeInterval: 2,
            sampleSize: 100
        )
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.segmentCount == 1)
    }

    // MARK: - Large values

    @Test("Large sample count (1000 samples)")
    func largeSampleCount() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 1000,
            keyframeInterval: 30,
            sampleSize: 20
        )
        var config = SegmentationConfig()
        config.targetSegmentDuration = 2.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 1)
        let total = result.mediaSegments.map(\.duration)
            .reduce(0, +)
        // 1000 * 3000 / 90000 = 33.33s
        let expected = 1000.0 * 3000.0 / 90000.0
        #expect(abs(total - expected) < 0.5)
    }

    @Test("Very short target duration (0.5 seconds)")
    func veryShortTargetDuration() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 0.5
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        // Each GOP is 1s, so 0.5s target still cuts at
        // keyframe boundaries = same as 1.0s = 3 segments
        #expect(result.segmentCount == 3)
    }

    @Test("Very long target duration (60 seconds)")
    func veryLongTargetDuration() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 60.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        // 3 second file with 60s target → one segment
        #expect(result.segmentCount == 1)
    }

    // MARK: - Unusual structures

    @Test("MP4 with uniform sample size (audio)")
    func uniformSampleSize() throws {
        let data = MP4TestDataBuilder.avMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.segmentCount > 0)
    }

    @Test("MP4 with variable stts (mixed frame durations)")
    func variableStts() throws {
        let data = buildVariableSttsMP4()
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.segmentCount >= 1)
        let total = result.mediaSegments.map(\.duration)
            .reduce(0, +)
        #expect(total > 0)
    }

    @Test("MP4 with ctts (composition offsets)")
    func compositionOffsets() throws {
        let data = buildMP4WithCtts()
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.segmentCount >= 1)
    }

    // MARK: - Error paths

    @Test("Segment empty data → throws MP4Error")
    func emptyDataThrows() {
        #expect(throws: MP4Error.self) {
            try MP4Segmenter().segment(data: Data())
        }
    }

    @Test("Segment non-MP4 data → throws MP4Error")
    func nonMP4Throws() {
        let random = Data(repeating: 0xAB, count: 200)
        #expect(throws: MP4Error.self) {
            try MP4Segmenter().segment(data: random)
        }
    }

    @Test("Segment MP4 without moov → throws")
    func missingMoovThrows() {
        let data = MP4TestDataBuilder.ftyp()
        #expect(throws: MP4Error.self) {
            try MP4Segmenter().segment(data: data)
        }
    }

    @Test("Segment MP4 without video or audio → throws")
    func noTracksThrows() {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                )
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

        #expect(throws: MP4Error.self) {
            try MP4Segmenter().segment(data: data)
        }
    }
}

// MARK: - Helpers

extension EdgeCaseTests {

    private func buildVariableSttsMP4() -> Data {
        let sampleSize: UInt32 = 50
        // 60 samples: first 30 at delta 3000, next 30 at 6000
        let totalSamples = 60
        let duration: UInt32 = 30 * 3000 + 30 * 6000
        let sizes = [UInt32](
            repeating: sampleSize, count: totalSamples
        )
        let syncSamples: [UInt32] = [1, 31]
        let mdatPayload =
            MP4TestDataBuilder.buildSamplePayload(
                sampleCount: totalSamples,
                sampleSize: Int(sampleSize),
                byteOffset: 0
            )
        return assembleMP4(
            duration: duration,
            mdatPayload: mdatPayload
        ) { offset in
            MP4TestDataBuilder.stbl(
                codec: "avc1",
                sttsEntries: [
                    (30, 3000),
                    (30, 6000)
                ],
                stszSizes: sizes,
                stcoOffsets: [offset],
                stscEntries: [
                    MP4TestDataBuilder.StscEntry(
                        firstChunk: 1,
                        samplesPerChunk: UInt32(totalSamples),
                        descIndex: 1
                    )
                ],
                stssSyncSamples: syncSamples
            )
        }
    }

    private func buildMP4WithCtts() -> Data {
        let videoSamples = 90
        let sampleDelta: UInt32 = 3000
        let sampleSize: UInt32 = 50
        let duration = UInt32(videoSamples) * sampleDelta
        let sizes = [UInt32](
            repeating: sampleSize, count: videoSamples
        )
        let syncSamples =
            MP4TestDataBuilder.buildSyncSamples(
                count: videoSamples, interval: 30
            )
        let cttsEntries:
            [(
                sampleCount: UInt32, sampleOffset: Int32
            )] = [
                (UInt32(videoSamples), 1500)
            ]
        let mdatPayload =
            MP4TestDataBuilder.buildSamplePayload(
                sampleCount: videoSamples,
                sampleSize: Int(sampleSize),
                byteOffset: 0
            )
        return assembleMP4(
            duration: duration,
            mdatPayload: mdatPayload
        ) { offset in
            MP4TestDataBuilder.stbl(
                codec: "avc1",
                sttsEntries: [
                    (UInt32(videoSamples), sampleDelta)
                ],
                stszSizes: sizes,
                stcoOffsets: [offset],
                stscEntries: [
                    MP4TestDataBuilder.StscEntry(
                        firstChunk: 1,
                        samplesPerChunk: UInt32(videoSamples),
                        descIndex: 1
                    )
                ],
                stssSyncSamples: syncSamples,
                cttsEntries: cttsEntries
            )
        }
    }

    private func assembleMP4(
        duration: UInt32,
        mdatPayload: Data,
        stblBuilder: (UInt32) -> Data
    ) -> Data {
        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = buildMoovFromStbl(
            stblBox: stblBuilder(0), duration: duration
        )
        let stcoOffset = UInt32(
            ftypData.count + moov0.count + 8
        )
        let moov = buildMoovFromStbl(
            stblBox: stblBuilder(stcoOffset),
            duration: duration
        )
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat", payload: mdatPayload
        )
        var data = Data()
        data.append(ftypData)
        data.append(moov)
        data.append(mdatBox)
        return data
    }

    private func buildMoovFromStbl(
        stblBox: Data,
        duration: UInt32,
        timescale: UInt32 = 90000
    ) -> Data {
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: timescale, duration: duration
                ),
                MP4TestDataBuilder.hdlr(
                    handlerType: "vide"
                ),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: duration,
                    width: 1920, height: 1080
                ),
                mdiaBox
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: timescale, duration: duration
                ),
                trakBox
            ]
        )
    }
}
