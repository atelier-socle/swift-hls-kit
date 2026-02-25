// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing
import os

@testable import HLSKit

@Suite(
    "Segmenter + CMAF Integration",
    .timeLimit(.minutes(1))
)
struct SegmenterCMAFIntegrationTests {

    // MARK: - segmentTransform

    @Test("IncrementalSegmenter with transform produces fMP4")
    func segmenterWithTransform() async throws {
        let cmafWriter = CMAFWriter()
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false
        )
        let counter = OSAllocatedUnfairLock(
            initialState: UInt32(0)
        )
        let transform:
            @Sendable (LiveSegment, [EncodedFrame])
                -> LiveSegment = { segment, frames in
                    let seq = counter.withLock { val -> UInt32 in
                        val += 1
                        return val
                    }
                    let data = cmafWriter.generateMediaSegment(
                        frames: frames,
                        sequenceNumber: seq,
                        timescale: 48000
                    )
                    return LiveSegment(
                        index: segment.index,
                        data: data,
                        duration: segment.duration,
                        timestamp: segment.timestamp,
                        isIndependent: segment.isIndependent,
                        programDateTime: segment.programDateTime,
                        filename: segment.filename,
                        frameCount: segment.frameCount,
                        codecs: segment.codecs
                    )
                }

        let segmenter = IncrementalSegmenter(
            configuration: config,
            segmentTransform: transform
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count >= 2)

        // Each segment should be valid fMP4
        for segment in emitted {
            let boxes = try MP4BoxReader().readBoxes(
                from: segment.data
            )
            #expect(boxes[0].type == "styp")
            #expect(boxes[1].type == "moof")
            #expect(boxes[2].type == "mdat")
        }
    }

    // MARK: - Ring Buffer with fMP4

    @Test("Ring buffer stores fMP4 segments correctly")
    func ringBufferFmp4() async throws {
        let audioConfig = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            ringBufferSize: 3,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: audioConfig,
            configuration: segConfig
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()
        let emitted = await collector.value

        // Many segments emitted
        #expect(emitted.count >= 3)

        // Ring buffer has at most 3
        let recent = await segmenter.recentSegments
        #expect(recent.count <= 3)

        // Each buffered segment is valid fMP4
        for segment in recent {
            let boxes = try MP4BoxReader().readBoxes(
                from: segment.data
            )
            #expect(boxes[0].type == "styp")
        }
    }

    // MARK: - Force Boundary

    @Test("forceSegmentBoundary produces valid fMP4")
    func forceBoundaryFmp4() async throws {
        let audioConfig = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 10.0,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: audioConfig,
            configuration: segConfig
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let frames = EncodedFrameFactory.audioFrames(count: 20)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        try await segmenter.forceSegmentBoundary()

        let more = EncodedFrameFactory.audioFrames(
            count: 10,
            startTimestamp: 20.0 * 1024.0 / 48000.0
        )
        for frame in more {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count == 2)

        // First segment (forced) is valid fMP4
        let boxes = try MP4BoxReader().readBoxes(
            from: emitted[0].data
        )
        #expect(boxes[0].type == "styp")
        #expect(boxes[1].type == "moof")
        #expect(boxes[2].type == "mdat")
    }
}
