// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SampleLocator")
struct SampleLocatorTests {

    // MARK: - Helpers

    /// Create a locator with a simple video table.
    /// 90 samples, 30fps at 90000 timescale (delta=3000),
    /// keyframes at 1, 31, 61 (every 30 frames).
    private func makeVideoLocator() -> SampleLocator {
        let sizes = [UInt32](repeating: 50_000, count: 90)
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 90, sampleDelta: 3000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 10,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: sizes,
            uniformSampleSize: 0,
            chunkOffsets: [
                1000, 501_000, 1_001_000, 1_501_000, 2_001_000,
                2_501_000, 3_001_000, 3_501_000, 4_001_000
            ],
            syncSamples: [1, 31, 61]
        )
        return SampleLocator(
            sampleTable: table, timescale: 90000
        )
    }

    /// Create a locator with variable deltas.
    private func makeVariableDeltaLocator() -> SampleLocator {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 5, sampleDelta: 1000
                ),
                TimeToSampleEntry(
                    sampleCount: 5, sampleDelta: 2000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 10,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [
                100, 200, 300, 400, 500,
                600, 700, 800, 900, 1000
            ],
            uniformSampleSize: 0,
            chunkOffsets: [0],
            syncSamples: nil
        )
        return SampleLocator(
            sampleTable: table, timescale: 44100
        )
    }

    /// Create an audio locator (no stss).
    private func makeAudioLocator() -> SampleLocator {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 100, sampleDelta: 1024
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 100,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [],
            uniformSampleSize: 512,
            chunkOffsets: [0],
            syncSamples: nil
        )
        return SampleLocator(
            sampleTable: table, timescale: 44100
        )
    }

    // MARK: - Timing

    @Test("decodingTime — first sample")
    func dtsFirst() {
        let locator = makeVideoLocator()
        #expect(locator.decodingTime(forSample: 0) == 0)
    }

    @Test("decodingTime — middle sample")
    func dtsMiddle() {
        let locator = makeVideoLocator()
        // Sample 30: 30 * 3000 = 90000
        #expect(locator.decodingTime(forSample: 30) == 90000)
    }

    @Test("decodingTime — last sample")
    func dtsLast() {
        let locator = makeVideoLocator()
        // Sample 89: 89 * 3000 = 267000
        #expect(locator.decodingTime(forSample: 89) == 267000)
    }

    @Test("decodingTime — variable delta")
    func dtsVariableDelta() {
        let locator = makeVariableDeltaLocator()
        // Sample 0: 0
        #expect(locator.decodingTime(forSample: 0) == 0)
        // Sample 4: 4 * 1000 = 4000
        #expect(locator.decodingTime(forSample: 4) == 4000)
        // Sample 5: 5*1000 = 5000 (enters second entry)
        #expect(locator.decodingTime(forSample: 5) == 5000)
        // Sample 7: 5*1000 + 2*2000 = 9000
        #expect(locator.decodingTime(forSample: 7) == 9000)
    }

    @Test("decodingTimeSeconds — correct conversion")
    func dtsSeconds() {
        let locator = makeVideoLocator()
        // Sample 30: 90000 / 90000 = 1.0s
        let seconds = locator.decodingTimeSeconds(forSample: 30)
        #expect(abs(seconds - 1.0) < 0.001)
    }

    @Test("decodingTimeSeconds — zero timescale returns 0")
    func dtsSecondsZeroTimescale() {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 1, sampleDelta: 1000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [],
            sampleSizes: [100],
            uniformSampleSize: 0,
            chunkOffsets: [],
            syncSamples: nil
        )
        let locator = SampleLocator(
            sampleTable: table, timescale: 0
        )
        #expect(locator.decodingTimeSeconds(forSample: 0) == 0)
    }

    @Test("presentationTime — without ctts (PTS == DTS)")
    func ptsNoCtts() {
        let locator = makeVideoLocator()
        let dts = locator.decodingTime(forSample: 5)
        let pts = locator.presentationTime(forSample: 5)
        #expect(pts == dts)
    }

    @Test("presentationTime — with ctts offsets")
    func ptsWithCtts() {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 10, sampleDelta: 3000
                )
            ],
            compositionOffsets: [
                CompositionOffsetEntry(
                    sampleCount: 5, sampleOffset: 6000
                ),
                CompositionOffsetEntry(
                    sampleCount: 5, sampleOffset: 3000
                )
            ],
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 10,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [UInt32](repeating: 1000, count: 10),
            uniformSampleSize: 0,
            chunkOffsets: [0],
            syncSamples: nil
        )
        let locator = SampleLocator(
            sampleTable: table, timescale: 90000
        )
        // Sample 2: DTS = 2*3000 = 6000, offset = 6000
        // PTS = 6000 + 6000 = 12000
        #expect(locator.presentationTime(forSample: 2) == 12000)
        // Sample 7: DTS = 7*3000 = 21000, offset = 3000
        // PTS = 21000 + 3000 = 24000
        #expect(locator.presentationTime(forSample: 7) == 24000)
    }

    @Test("sampleDuration — uniform delta")
    func durationUniform() {
        let locator = makeVideoLocator()
        #expect(locator.sampleDuration(forSample: 0) == 3000)
        #expect(locator.sampleDuration(forSample: 50) == 3000)
    }

    @Test("sampleDuration — variable delta")
    func durationVariable() {
        let locator = makeVariableDeltaLocator()
        #expect(locator.sampleDuration(forSample: 3) == 1000)
        #expect(locator.sampleDuration(forSample: 7) == 2000)
    }

    // MARK: - Location

    @Test("sampleSize — variable sizes")
    func sizeVariable() {
        let locator = makeVariableDeltaLocator()
        #expect(locator.sampleSize(forSample: 0) == 100)
        #expect(locator.sampleSize(forSample: 9) == 1000)
    }

    @Test("sampleSize — uniform size")
    func sizeUniform() {
        let locator = makeAudioLocator()
        #expect(locator.sampleSize(forSample: 0) == 512)
        #expect(locator.sampleSize(forSample: 99) == 512)
    }

    @Test("sampleSize — out of range returns 0")
    func sizeOutOfRange() {
        let locator = makeVariableDeltaLocator()
        #expect(locator.sampleSize(forSample: 999) == 0)
    }

    @Test("sampleOffset — first sample in first chunk")
    func offsetFirst() {
        let locator = makeVideoLocator()
        // First chunk offset is 1000, first sample
        #expect(locator.sampleOffset(forSample: 0) == 1000)
    }

    @Test("sampleOffset — second sample in first chunk")
    func offsetSecondSample() {
        let locator = makeVideoLocator()
        // Chunk offset 1000 + sample[0] size 50000 = 51000
        #expect(locator.sampleOffset(forSample: 1) == 51000)
    }

    @Test("sampleOffset — sample in second chunk")
    func offsetSecondChunk() {
        let locator = makeVideoLocator()
        // 10 samples per chunk, so sample 10 is in chunk 1
        // Chunk 1 offset is 501000
        #expect(locator.sampleOffset(forSample: 10) == 501_000)
    }

    @Test("sampleOffset — with multi-entry stsc")
    func offsetMultiStsc() {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 8, sampleDelta: 1000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 3,
                    sampleDescriptionIndex: 1
                ),
                SampleToChunkEntry(
                    firstChunk: 3, samplesPerChunk: 2,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [100, 200, 300, 400, 500, 600, 700, 800],
            uniformSampleSize: 0,
            chunkOffsets: [0, 1000, 2000, 3000],
            syncSamples: nil
        )
        let locator = SampleLocator(
            sampleTable: table, timescale: 44100
        )
        // Chunk 0 (3 samples): samples 0,1,2
        #expect(locator.sampleOffset(forSample: 0) == 0)
        #expect(locator.sampleOffset(forSample: 1) == 100)
        #expect(locator.sampleOffset(forSample: 2) == 300)
        // Chunk 1 (3 samples): samples 3,4,5
        #expect(locator.sampleOffset(forSample: 3) == 1000)
        // Chunk 2 (2 samples): samples 6,7
        #expect(locator.sampleOffset(forSample: 6) == 2000)
        #expect(locator.sampleOffset(forSample: 7) == 2700)
    }

    @Test("sampleRanges — contiguous samples")
    func ranges() {
        let locator = makeVariableDeltaLocator()
        let ranges = locator.sampleRanges(start: 0, count: 3)
        #expect(ranges.count == 3)
        #expect(ranges[0].size == 100)
        #expect(ranges[1].size == 200)
        #expect(ranges[2].size == 300)
    }

}

// MARK: - Keyframes

extension SampleLocatorTests {

    @Test("isSyncSample — keyframe")
    func isSyncKeyframe() {
        let locator = makeVideoLocator()
        #expect(locator.isSyncSample(0))  // 1-based 1
        #expect(locator.isSyncSample(30))  // 1-based 31
        #expect(locator.isSyncSample(60))  // 1-based 61
    }

    @Test("isSyncSample — non-keyframe")
    func isSyncNonKeyframe() {
        let locator = makeVideoLocator()
        #expect(!locator.isSyncSample(1))
        #expect(!locator.isSyncSample(15))
        #expect(!locator.isSyncSample(89))
    }

    @Test("isSyncSample — no stss (all sync)")
    func isSyncNoStss() {
        let locator = makeAudioLocator()
        #expect(locator.isSyncSample(0))
        #expect(locator.isSyncSample(50))
        #expect(locator.isSyncSample(99))
    }

    @Test("syncSampleIndices — with stss")
    func syncIndicesWithStss() {
        let locator = makeVideoLocator()
        let indices = locator.syncSampleIndices()
        #expect(indices == [0, 30, 60])
    }

    @Test("syncSampleIndices — no stss (all)")
    func syncIndicesNoStss() {
        let locator = makeAudioLocator()
        let indices = locator.syncSampleIndices()
        #expect(indices.count == 100)
        #expect(indices.first == 0)
        #expect(indices.last == 99)
    }

    @Test("nearestSyncSample — exact keyframe")
    func nearestExact() {
        let locator = makeVideoLocator()
        #expect(locator.nearestSyncSample(atOrBefore: 30) == 30)
    }

    @Test("nearestSyncSample — between keyframes")
    func nearestBetween() {
        let locator = makeVideoLocator()
        #expect(locator.nearestSyncSample(atOrBefore: 45) == 30)
    }

    @Test("nearestSyncSample — before first keyframe")
    func nearestBeforeFirst() {
        let locator = makeVideoLocator()
        #expect(locator.nearestSyncSample(atOrBefore: 0) == 0)
    }

    @Test("nearestSyncSample — no stss")
    func nearestNoStss() {
        let locator = makeAudioLocator()
        #expect(locator.nearestSyncSample(atOrBefore: 50) == 50)
    }
}

// MARK: - Segmentation

extension SampleLocatorTests {

    @Test("calculateSegments — 30fps, keyframes every 30, target 2s")
    func segmentsVideoTarget2() {
        let locator = makeVideoLocator()
        let segments = locator.calculateSegments(
            targetDuration: 2.0
        )
        #expect(segments.count == 2)
        #expect(segments[0].firstSample == 0)
        #expect(segments[0].sampleCount == 60)
        #expect(abs(segments[0].duration - 2.0) < 0.01)
        #expect(segments[0].startsWithKeyframe)
        #expect(segments[1].firstSample == 60)
        #expect(segments[1].sampleCount == 30)
        #expect(segments[1].startsWithKeyframe)
    }

    @Test("calculateSegments — target 1s, keyframes every 1s")
    func segmentsVideoTarget1() {
        let locator = makeVideoLocator()
        let segments = locator.calculateSegments(
            targetDuration: 1.0
        )
        #expect(segments.count == 3)
        #expect(segments[0].sampleCount == 30)
        #expect(segments[1].sampleCount == 30)
        #expect(segments[2].sampleCount == 30)
    }

    @Test("calculateSegments — audio (no stss)")
    func segmentsAudio() {
        let locator = makeAudioLocator()
        let segments = locator.calculateSegments(
            targetDuration: 1.0
        )
        #expect(!segments.isEmpty)
        for segment in segments {
            #expect(segment.startsWithKeyframe)
        }
    }

    @Test("calculateSegments — single keyframe")
    func segmentsSingleKeyframe() {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 30, sampleDelta: 3000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 30,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [UInt32](repeating: 1000, count: 30),
            uniformSampleSize: 0,
            chunkOffsets: [0],
            syncSamples: [1]
        )
        let locator = SampleLocator(
            sampleTable: table, timescale: 90000
        )
        let segments = locator.calculateSegments(
            targetDuration: 6.0
        )
        #expect(segments.count == 1)
        #expect(segments[0].sampleCount == 30)
    }

    @Test("calculateSegments — empty track")
    func segmentsEmpty() {
        let table = SampleTable(
            timeToSample: [],
            compositionOffsets: nil,
            sampleToChunk: [],
            sampleSizes: [],
            uniformSampleSize: 0,
            chunkOffsets: [],
            syncSamples: nil
        )
        let locator = SampleLocator(
            sampleTable: table, timescale: 90000
        )
        let segments = locator.calculateSegments(
            targetDuration: 6.0
        )
        #expect(segments.isEmpty)
    }

    @Test("calculateSegments — segment startDTS and startPTS")
    func segmentTimestamps() {
        let locator = makeVideoLocator()
        let segments = locator.calculateSegments(
            targetDuration: 1.0
        )
        #expect(segments[0].startDTS == 0)
        #expect(segments[1].startDTS == 90000)
    }
}
