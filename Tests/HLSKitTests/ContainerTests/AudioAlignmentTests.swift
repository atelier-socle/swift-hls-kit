// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Audio Alignment")
struct AudioAlignmentTests {

    // MARK: - Helpers

    /// Create a video locator: 90 samples, 30fps, 90000 timescale.
    private func makeVideoLocator() -> SampleLocator {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 90, sampleDelta: 3000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 90,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [UInt32](repeating: 1000, count: 90),
            uniformSampleSize: 0,
            chunkOffsets: [0],
            syncSamples: [1, 31, 61]
        )
        return SampleLocator(
            sampleTable: table, timescale: 90000
        )
    }

    /// Create an audio locator: 430 samples, 44100 timescale,
    /// delta=1024.
    private func makeAudioLocator() -> SampleLocator {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 430, sampleDelta: 1024
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 430,
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

    // MARK: - Basic Alignment

    @Test("alignedAudioSegment — first video segment")
    func alignFirstSegment() {
        let videoLocator = makeVideoLocator()
        let audioLocator = makeAudioLocator()
        let videoSegments = videoLocator.calculateSegments(
            targetDuration: 1.0
        )
        guard let firstVideoSeg = videoSegments.first else {
            Issue.record("No video segments")
            return
        }
        let audioSeg = audioLocator.alignedAudioSegment(
            for: firstVideoSeg, videoTimescale: 90000
        )
        // First segment: 0–30 video samples = 0.0–1.0s
        #expect(audioSeg.firstSample >= 0)
        #expect(audioSeg.sampleCount > 0)
        #expect(audioSeg.startsWithKeyframe)
        // Duration should be approximately 1 second
        #expect(audioSeg.duration > 0.9)
        #expect(audioSeg.duration < 1.2)
    }

    @Test("alignedAudioSegment — second video segment")
    func alignSecondSegment() {
        let videoLocator = makeVideoLocator()
        let audioLocator = makeAudioLocator()
        let videoSegments = videoLocator.calculateSegments(
            targetDuration: 1.0
        )
        guard videoSegments.count >= 2 else {
            Issue.record("Expected at least 2 segments")
            return
        }
        let audioSeg = audioLocator.alignedAudioSegment(
            for: videoSegments[1], videoTimescale: 90000
        )
        // Second segment starts at 1.0s
        #expect(audioSeg.firstSample > 0)
        #expect(audioSeg.sampleCount > 0)
        // Audio DTS should be non-zero
        #expect(audioSeg.startDTS > 0)
    }

    @Test("alignedAudioSegment — covers full video duration")
    func alignCoversFullDuration() {
        let videoLocator = makeVideoLocator()
        let audioLocator = makeAudioLocator()
        let videoSegments = videoLocator.calculateSegments(
            targetDuration: 1.0
        )
        var totalAudioSamples = 0
        for videoSeg in videoSegments {
            let audioSeg = audioLocator.alignedAudioSegment(
                for: videoSeg, videoTimescale: 90000
            )
            totalAudioSamples += audioSeg.sampleCount
        }
        // Should cover most audio samples
        #expect(totalAudioSamples > 0)
    }

    // MARK: - Edge Cases

    @Test("alignedAudioSegment — zero video timescale")
    func zeroVideoTimescale() {
        let audioLocator = makeAudioLocator()
        let videoSeg = SegmentInfo(
            firstSample: 0, sampleCount: 30,
            duration: 1.0, startDTS: 0, startPTS: 0,
            startsWithKeyframe: true
        )
        let audioSeg = audioLocator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 0
        )
        #expect(audioSeg.sampleCount == 0)
        #expect(audioSeg.duration == 0)
    }

    @Test("alignedAudioSegment — zero audio timescale")
    func zeroAudioTimescale() {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 10, sampleDelta: 1024
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 10,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [],
            uniformSampleSize: 100,
            chunkOffsets: [0],
            syncSamples: nil
        )
        let locator = SampleLocator(
            sampleTable: table, timescale: 0
        )
        let videoSeg = SegmentInfo(
            firstSample: 0, sampleCount: 30,
            duration: 1.0, startDTS: 0, startPTS: 0,
            startsWithKeyframe: true
        )
        let audioSeg = locator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 90000
        )
        #expect(audioSeg.sampleCount == 0)
    }

    @Test("alignedAudioSegment — empty audio track")
    func emptyAudioTrack() {
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
            sampleTable: table, timescale: 44100
        )
        let videoSeg = SegmentInfo(
            firstSample: 0, sampleCount: 30,
            duration: 1.0, startDTS: 0, startPTS: 0,
            startsWithKeyframe: true
        )
        let audioSeg = locator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 90000
        )
        #expect(audioSeg.sampleCount == 0)
    }

    @Test("alignedAudioSegment — all audio sync samples")
    func allAudioSync() {
        let audioLocator = makeAudioLocator()
        let videoSeg = SegmentInfo(
            firstSample: 0, sampleCount: 30,
            duration: 1.0, startDTS: 0, startPTS: 0,
            startsWithKeyframe: true
        )
        let audioSeg = audioLocator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 90000
        )
        // Audio has no stss, so all samples are sync
        #expect(audioSeg.startsWithKeyframe)
    }

    // MARK: - Timescale Conversion

    @Test("alignedAudioSegment — different timescales")
    func differentTimescales() {
        let audioLocator = makeAudioLocator()
        // Video at 600 timescale (QuickTime style)
        let videoSeg = SegmentInfo(
            firstSample: 0, sampleCount: 30,
            duration: 1.0, startDTS: 0, startPTS: 0,
            startsWithKeyframe: true
        )
        let audioSeg = audioLocator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 600
        )
        #expect(audioSeg.sampleCount > 0)
        // Duration ~1 second
        #expect(audioSeg.duration > 0.9)
    }

    @Test("alignedAudioSegment — late video segment")
    func lateVideoSegment() {
        let audioLocator = makeAudioLocator()
        // Video segment starting at 2.0 seconds
        // At 90000 timescale: 2.0 * 90000 = 180000
        let videoSeg = SegmentInfo(
            firstSample: 60, sampleCount: 30,
            duration: 1.0, startDTS: 180000, startPTS: 180000,
            startsWithKeyframe: true
        )
        let audioSeg = audioLocator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 90000
        )
        #expect(audioSeg.firstSample > 0)
        #expect(audioSeg.startDTS > 0)
        // Audio at 2.0s: DTS ~= 2.0 * 44100 = 88200
        // Each audio sample is 1024 ticks, so sample ~86
        #expect(audioSeg.firstSample >= 80)
    }
}
