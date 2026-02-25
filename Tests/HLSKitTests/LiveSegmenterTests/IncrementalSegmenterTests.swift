// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "IncrementalSegmenter — Segmentation",
    .timeLimit(.minutes(1))
)
struct IncrementalSegmenterTests {

    // MARK: - Helpers

    /// Ingest all frames, finish, and collect all emitted segments.
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

    // MARK: - Audio-Only Segmentation

    @Test("Audio-only: segment emitted at target duration")
    func audioOnlySegmentation() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 1.0,
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
        for segment in emitted {
            #expect(segment.isIndependent)
            #expect(segment.codecs.contains(.aac))
        }
    }

    @Test("Audio-only: multiple segments in sequence")
    func audioMultipleSegments() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
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
    }

    @Test("Audio-only: segment indices are sequential")
    func audioSegmentIndices() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 200)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        for i in 0..<emitted.count {
            #expect(emitted[i].index == i)
        }
    }

    @Test("Audio-only: filenames match naming pattern")
    func audioFilenames() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false,
            namingPattern: "audio_%d.aac"
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        for segment in emitted {
            let expected = String(
                format: "audio_%d.aac", segment.index
            )
            #expect(segment.filename == expected)
        }
    }

    @Test("Audio-only: program date times are tracked")
    func audioProgramDateTime() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false,
            trackProgramDateTime: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        for segment in emitted {
            #expect(segment.programDateTime != nil)
        }
    }

    @Test("Audio-only: custom start index")
    func audioCustomStartIndex() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false,
            startIndex: 10
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        #expect(emitted.first?.index == 10)
    }

    @Test("Audio-only: frame count matches")
    func audioFrameCount() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        let totalFrames = emitted.reduce(0) {
            $0 + $1.frameCount
        }
        #expect(totalFrames == 100)
    }

    // MARK: - Video Segmentation

    @Test("Video: segment cuts at keyframe after target")
    func videoKeyframeAligned() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 1.0,
            keyframeAligned: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.videoFrames(
            count: 120, fps: 30.0, keyframeInterval: 30
        )
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        #expect(emitted.count >= 2)
        for segment in emitted.dropLast() {
            #expect(segment.isIndependent)
            #expect(segment.codecs.contains(.h264))
        }
    }

    @Test("Video: force-cut at maxDuration without keyframe")
    func videoForceCutAtMax() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 1.0,
            maxDuration: 2.0,
            keyframeAligned: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 999
        )
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        #expect(emitted.count >= 2)
    }

    @Test("Video: segment starts with keyframe")
    func videoStartsWithKeyframe() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 1.0,
            keyframeAligned: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        if let first = emitted.first {
            #expect(first.isIndependent)
        }
    }

    // MARK: - Mixed Audio+Video

    @Test("Interleaved frames produce correct segments")
    func interleavedFrames() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            keyframeAligned: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )

        let frames = EncodedFrameFactory.interleavedFrames(
            duration: 6.0,
            keyframeIntervalSeconds: 2.0
        )
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        #expect(emitted.count >= 2)
        let allCodecs = emitted.reduce(
            into: Set<EncodedCodec>()
        ) {
            $0.formUnion($1.codecs)
        }
        #expect(allCodecs.contains(.aac))
        #expect(allCodecs.contains(.h264))
    }
}
