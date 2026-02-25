// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Segmenter Edge Cases", .timeLimit(.minutes(1)))
struct SegmenterEdgeCaseTests {

    // MARK: - Helpers

    private func collectSegments(
        segmenter: IncrementalSegmenter,
        frames: [EncodedFrame]
    ) async throws -> [LiveSegment] {
        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()
        return await collector.value
    }

    // MARK: - Single Frame & Empty

    @Test("Single frame then finish produces one segment")
    func singleFrameFinish() async throws {
        let segmenter = IncrementalSegmenter()
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        try await segmenter.ingest(frame)
        let last = try await segmenter.finish()
        #expect(last != nil)
        #expect(last?.frameCount == 1)
    }

    @Test("Zero frames then finish returns nil")
    func zeroFramesFinish() async throws {
        let segmenter = IncrementalSegmenter()
        let result = try await segmenter.finish()
        #expect(result == nil)
    }

    @Test("Finish called twice returns nil on second call")
    func finishTwice() async throws {
        let segmenter = IncrementalSegmenter()
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        try await segmenter.ingest(frame)
        let first = try await segmenter.finish()
        #expect(first != nil)
        let second = try await segmenter.finish()
        #expect(second == nil)
    }

    // MARK: - Error Paths

    @Test("forceSegmentBoundary with no frames throws")
    func forceBoundaryNoFrames() async {
        let segmenter = IncrementalSegmenter()
        await #expect(
            throws: LiveSegmenterError.noFramesPending
        ) {
            try await segmenter.forceSegmentBoundary()
        }
    }

    @Test("Ingest after finish throws notActive")
    func ingestAfterFinish() async throws {
        let segmenter = IncrementalSegmenter()
        _ = try await segmenter.finish()
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        await #expect(throws: LiveSegmenterError.notActive) {
            try await segmenter.ingest(frame)
        }
    }

    @Test("Non-monotonic timestamp throws error")
    func nonMonotonicTimestamp() async throws {
        let segmenter = IncrementalSegmenter()
        let frame1 = EncodedFrameFactory.audioFrame(
            timestamp: 1.0
        )
        let frame2 = EncodedFrameFactory.audioFrame(
            timestamp: 0.5
        )
        try await segmenter.ingest(frame1)
        await #expect(throws: LiveSegmenterError.self) {
            try await segmenter.ingest(frame2)
        }
    }

    // MARK: - Duration & Keyframe Edge Cases

    @Test("Long keyframe interval → force-cut at maxDuration")
    func forceCutAtMaxDuration() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            maxDuration: 4.0,
            keyframeAligned: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        // 150 video frames at 30fps = 5s, no keyframes except 0
        let frames = EncodedFrameFactory.videoFrames(
            count: 150, fps: 30.0, keyframeInterval: 999
        )
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        #expect(emitted.count >= 2)
        // Force-cut segment is not independent
        if emitted.count > 1 {
            #expect(!emitted[1].isIndependent)
        }
    }

    @Test("Very short target duration produces many segments")
    func veryShortTargetDuration() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.1,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )
        #expect(emitted.count >= 10)
    }

    // MARK: - Ring Buffer

    @Test("Ring buffer capacity 0 → no segments stored")
    func ringBufferZeroCapacity() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            ringBufferSize: 0,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )
        #expect(emitted.count >= 2)
        let buffered = await segmenter.bufferedSegmentCount
        #expect(buffered == 0)
    }

    @Test("Ring buffer capacity 1 → only latest stored")
    func ringBufferCapacity1() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            ringBufferSize: 1,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frames = EncodedFrameFactory.audioFrames(count: 200)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )
        #expect(emitted.count >= 4)
        let buffered = await segmenter.bufferedSegmentCount
        #expect(buffered == 1)
        let recent = await segmenter.recentSegments
        #expect(recent.first?.index == emitted.last?.index)
    }

    // MARK: - Large Input

    @Test("500 audio frames → all segments emitted")
    func massiveFrameCount() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frames = EncodedFrameFactory.audioFrames(
            count: 500
        )
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        let totalFrames = emitted.reduce(0) {
            $0 + $1.frameCount
        }
        #expect(totalFrames == 500)
    }

    // MARK: - Configuration

    @Test("Custom start index")
    func customStartIndex() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false,
            startIndex: 42
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frames = EncodedFrameFactory.audioFrames(count: 50)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )
        #expect(emitted.first?.index == 42)
    }

    @Test("Custom naming pattern")
    func customNamingPattern() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false,
            namingPattern: "chunk_%d.m4s"
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frames = EncodedFrameFactory.audioFrames(count: 50)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )
        let first = try #require(emitted.first)
        #expect(first.filename == "chunk_0.m4s")
    }

    @Test("programDateTime tracking disabled → nil")
    func noProgramDateTime() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false,
            trackProgramDateTime: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frames = EncodedFrameFactory.audioFrames(count: 50)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )
        for segment in emitted {
            #expect(segment.programDateTime == nil)
        }
    }

    @Test("Mixed codec frames → codecs tracked correctly")
    func mixedCodecFrames() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 10.0,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let audio = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        let video = EncodedFrameFactory.videoFrame(
            timestamp: 0.01, isKeyframe: true
        )
        try await segmenter.ingest(audio)
        try await segmenter.ingest(video)
        let last = try await segmenter.finish()
        let codecs = try #require(last?.codecs)
        #expect(codecs.contains(.aac))
        #expect(codecs.contains(.h264))
    }
}
