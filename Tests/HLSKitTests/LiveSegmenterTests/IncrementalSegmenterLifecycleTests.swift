// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "IncrementalSegmenter — Lifecycle & Edge Cases",
    .timeLimit(.minutes(1))
)
struct IncrementalSegmenterLifecycleTests {

    // MARK: - forceSegmentBoundary

    @Test("forceSegmentBoundary emits immediately")
    func forceSegmentBoundary() async throws {
        let segmenter = IncrementalSegmenter(
            configuration: .audioOnly
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let frames = EncodedFrameFactory.audioFrames(count: 10)
        for frame in frames {
            try await segmenter.ingest(frame)
        }

        try await segmenter.forceSegmentBoundary()

        let moreFrames = EncodedFrameFactory.audioFrames(
            count: 5, startTimestamp: 1.0
        )
        for frame in moreFrames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count == 2)
        #expect(emitted[0].frameCount == 10)
        #expect(emitted[1].frameCount == 5)
    }

    @Test("forceSegmentBoundary with no frames throws")
    func forceSegmentBoundaryNoFrames() async {
        let segmenter = IncrementalSegmenter()

        await #expect(
            throws: LiveSegmenterError.noFramesPending
        ) {
            try await segmenter.forceSegmentBoundary()
        }
    }

    @Test("forceSegmentBoundary after finish throws")
    func forceSegmentBoundaryAfterFinish() async throws {
        let segmenter = IncrementalSegmenter()
        _ = try await segmenter.finish()

        await #expect(
            throws: LiveSegmenterError.notActive
        ) {
            try await segmenter.forceSegmentBoundary()
        }
    }

    // MARK: - finish

    @Test("finish returns final segment")
    func finishReturnsFinal() async throws {
        let segmenter = IncrementalSegmenter(
            configuration: .audioOnly
        )
        let frames = EncodedFrameFactory.audioFrames(count: 5)
        for frame in frames {
            try await segmenter.ingest(frame)
        }

        let last = try await segmenter.finish()
        #expect(last != nil)
        #expect(last?.frameCount == 5)
    }

    @Test("finish with no pending frames returns nil")
    func finishEmpty() async throws {
        let segmenter = IncrementalSegmenter()
        let result = try await segmenter.finish()
        #expect(result == nil)
    }

    @Test("finish twice returns nil on second call")
    func finishTwice() async throws {
        let segmenter = IncrementalSegmenter(
            configuration: .audioOnly
        )
        let frames = EncodedFrameFactory.audioFrames(count: 5)
        for frame in frames {
            try await segmenter.ingest(frame)
        }

        let first = try await segmenter.finish()
        #expect(first != nil)

        let second = try await segmenter.finish()
        #expect(second == nil)
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

    // MARK: - Edge Cases

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

        await #expect(
            throws: LiveSegmenterError.self
        ) {
            try await segmenter.ingest(frame2)
        }
    }

    @Test("Single frame then finish")
    func singleFrameFinish() async throws {
        let segmenter = IncrementalSegmenter()

        let frame = EncodedFrameFactory.videoFrame(
            timestamp: 0.0, isKeyframe: true
        )
        try await segmenter.ingest(frame)

        let last = try await segmenter.finish()
        #expect(last != nil)
        #expect(last?.frameCount == 1)
        #expect(last?.isIndependent == true)
    }

    @Test("Zero-capacity ring buffer (no DVR)")
    func zeroCapacityRingBuffer() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            ringBufferSize: 0,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let buffered = await segmenter.bufferedSegmentCount
        #expect(buffered == 0)
    }

    @Test("Program date time not tracked when disabled")
    func noProgramDateTime() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false,
            trackProgramDateTime: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let frames = EncodedFrameFactory.audioFrames(count: 50)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        for segment in emitted {
            #expect(segment.programDateTime == nil)
        }
    }

    // MARK: - Ring Buffer Access

    @Test("recentSegments returns buffered segments")
    func recentSegments() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            ringBufferSize: 3,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 200)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let recent = await segmenter.recentSegments
        #expect(recent.count <= 3)
    }

    @Test("segment(at:) retrieves by index")
    func segmentAtIndex() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            ringBufferSize: 10,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let seg0 = await segmenter.segment(at: 0)
        #expect(seg0?.index == 0)
    }

    @Test("segmentCount tracks total emitted")
    func segmentCountTracking() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 200)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let total = await segmenter.segmentCount
        let buffered = await segmenter.bufferedSegmentCount
        #expect(total >= 4)
        #expect(buffered <= total)
    }
}
