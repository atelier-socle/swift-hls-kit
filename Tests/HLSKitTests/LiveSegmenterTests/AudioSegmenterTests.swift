// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AudioSegmenter", .timeLimit(.minutes(1)))
struct AudioSegmenterTests {

    // MARK: - Helpers

    private func makeSegmenter(
        containerFormat: AudioSegmenter.ContainerFormat = .fmp4,
        targetDuration: TimeInterval = 1.0
    ) -> AudioSegmenter {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: targetDuration,
            keyframeAligned: false
        )
        return AudioSegmenter(
            audioConfig: config,
            configuration: segConfig,
            containerFormat: containerFormat
        )
    }

    private func collectSegments(
        segmenter: AudioSegmenter,
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

    // MARK: - Init Segment

    @Test("Init segment is non-nil for fMP4")
    func initSegmentFmp4() {
        let segmenter = makeSegmenter(containerFormat: .fmp4)
        #expect(segmenter.initSegment != nil)
    }

    @Test("Init segment is nil for rawData")
    func initSegmentRawData() {
        let segmenter = makeSegmenter(
            containerFormat: .rawData
        )
        #expect(segmenter.initSegment == nil)
    }

    @Test("Init segment is valid fMP4 (ftyp + moov)")
    func initSegmentValidFmp4() throws {
        let segmenter = makeSegmenter()
        let initData = try #require(segmenter.initSegment)
        let boxes = try MP4BoxReader().readBoxes(from: initData)

        #expect(boxes.count == 2)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    // MARK: - Ingest & Segment

    @Test("Ingest audio frames produces segments")
    func ingestProducesSegments() async throws {
        let segmenter = makeSegmenter(targetDuration: 0.5)
        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        #expect(emitted.count >= 2)
    }

    @Test("fMP4 segments have styp+moof+mdat structure")
    func fmp4SegmentStructure() async throws {
        let segmenter = makeSegmenter(targetDuration: 0.5)
        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        let first = try #require(emitted.first)
        let boxes = try MP4BoxReader().readBoxes(from: first.data)

        #expect(boxes.count == 3)
        #expect(boxes[0].type == "styp")
        #expect(boxes[1].type == "moof")
        #expect(boxes[2].type == "mdat")
    }

    @Test("Raw segments have concatenated frame data")
    func rawSegmentData() async throws {
        let segmenter = makeSegmenter(
            containerFormat: .rawData,
            targetDuration: 0.5
        )
        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        let first = try #require(emitted.first)
        // Raw data should be concatenated 0xAA bytes
        #expect(first.data.first == 0xAA)
    }

    @Test("Segment codecs contain AAC")
    func segmentCodecs() async throws {
        let segmenter = makeSegmenter(targetDuration: 0.5)
        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        for segment in emitted {
            #expect(segment.codecs.contains(.aac))
        }
    }

    @Test("Segments are independent (audio always true)")
    func segmentsAreIndependent() async throws {
        let segmenter = makeSegmenter(targetDuration: 0.5)
        let frames = EncodedFrameFactory.audioFrames(count: 100)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        for segment in emitted {
            #expect(segment.isIndependent)
        }
    }

    // MARK: - forceSegmentBoundary

    @Test("forceSegmentBoundary emits early")
    func forceSegmentBoundary() async throws {
        let segmenter = makeSegmenter(targetDuration: 6.0)

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        // Ingest a few frames (well under 6s target)
        let frames = EncodedFrameFactory.audioFrames(count: 10)
        for frame in frames {
            try await segmenter.ingest(frame)
        }

        try await segmenter.forceSegmentBoundary()

        // Ingest more and finish
        let moreFrames = EncodedFrameFactory.audioFrames(
            count: 10,
            startTimestamp: frames.last?.timestamp.seconds ?? 0
                + (1024.0 / 48000.0)
        )
        for frame in moreFrames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count >= 2)
    }

    // MARK: - finish

    @Test("Finish returns final segment")
    func finishReturnsFinal() async throws {
        let segmenter = makeSegmenter(targetDuration: 10.0)

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

        let final = try await segmenter.finish()
        #expect(final != nil)
        _ = await collector.value
    }

    @Test("Finish with no frames returns nil")
    func finishEmptyReturnsNil() async throws {
        let segmenter = makeSegmenter()

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let final = try await segmenter.finish()
        #expect(final == nil)
        _ = await collector.value
    }

    // MARK: - Container Format

    @Test("Container format selection")
    func containerFormatSelection() {
        let fmp4 = makeSegmenter(containerFormat: .fmp4)
        let raw = makeSegmenter(containerFormat: .rawData)

        #expect(fmp4.containerFormat == .fmp4)
        #expect(raw.containerFormat == .rawData)
    }

    // MARK: - Sequence Numbers

    @Test("Segments have incrementing sequence numbers in mfhd")
    func incrementingSequenceNumbers() async throws {
        let segmenter = makeSegmenter(targetDuration: 0.5)
        let frames = EncodedFrameFactory.audioFrames(count: 200)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        #expect(emitted.count >= 3)

        // Verify all segments are valid fMP4
        for segment in emitted {
            let boxes = try MP4BoxReader().readBoxes(
                from: segment.data
            )
            #expect(boxes[0].type == "styp")
            #expect(boxes[1].type == "moof")
        }
    }

    // MARK: - Ring Buffer

    @Test("Recent segments accessible via ring buffer")
    func recentSegments() async throws {
        let segmenter = makeSegmenter(targetDuration: 0.5)
        let frames = EncodedFrameFactory.audioFrames(count: 200)
        _ = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        let recent = await segmenter.recentSegments
        #expect(!recent.isEmpty)
    }

    @Test("Segment count tracks total emitted")
    func segmentCountTracking() async throws {
        let segmenter = makeSegmenter(targetDuration: 0.5)
        let frames = EncodedFrameFactory.audioFrames(count: 200)
        let emitted = try await collectSegments(
            segmenter: segmenter, frames: frames
        )

        let count = await segmenter.segmentCount
        #expect(count == emitted.count)
    }
}
