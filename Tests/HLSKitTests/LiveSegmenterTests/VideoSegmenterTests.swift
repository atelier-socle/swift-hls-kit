// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("VideoSegmenter", .timeLimit(.minutes(1)))
struct VideoSegmenterTests {

    // MARK: - Helpers

    private func makeSPS() -> Data {
        Data([0x67, 0x42, 0xC0, 0x1E, 0xD9, 0x00, 0xA0])
    }

    private func makePPS() -> Data {
        Data([0x68, 0xCE, 0x38, 0x80])
    }

    private func makeVideoConfig() -> CMAFWriter.VideoConfig {
        CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1280, height: 720,
            sps: makeSPS(), pps: makePPS()
        )
    }

    private func makeAudioConfig() -> CMAFWriter.AudioConfig {
        CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
    }

    private func makeSegmenter(
        withAudio: Bool = true,
        targetDuration: TimeInterval = 1.0
    ) -> VideoSegmenter {
        let config = LiveSegmenterConfiguration(
            targetDuration: targetDuration,
            keyframeAligned: true
        )
        return VideoSegmenter(
            videoConfig: makeVideoConfig(),
            audioConfig: withAudio ? makeAudioConfig() : nil,
            configuration: config
        )
    }

    // MARK: - Init Segments

    @Test("Video init segment is valid fMP4")
    func videoInitSegmentValid() throws {
        let segmenter = makeSegmenter()
        let boxes = try MP4BoxReader().readBoxes(
            from: segmenter.videoInitSegment
        )
        #expect(boxes.count == 2)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    @Test("Audio init segment is valid fMP4")
    func audioInitSegmentValid() throws {
        let segmenter = makeSegmenter(withAudio: true)
        let initData = try #require(segmenter.audioInitSegment)
        let boxes = try MP4BoxReader().readBoxes(from: initData)
        #expect(boxes.count == 2)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    @Test("Audio init segment is nil for video-only")
    func audioInitSegmentNilVideoOnly() {
        let segmenter = makeSegmenter(withAudio: false)
        #expect(segmenter.audioInitSegment == nil)
    }

    // MARK: - Video Only

    @Test("Video-only: segment outputs are emitted")
    func videoOnlyOutputs() async throws {
        let segmenter = makeSegmenter(
            withAudio: false, targetDuration: 1.0
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let frames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        for frame in frames {
            try await segmenter.ingestVideo(frame)
        }
        _ = try await segmenter.finish()

        let outputs = await collector.value
        #expect(outputs.count >= 2)
        for output in outputs {
            #expect(output.audioSegment == nil)
        }
    }

    @Test("Video-only: segment outputs have valid fMP4")
    func videoOnlyFmp4() async throws {
        let segmenter = makeSegmenter(
            withAudio: false, targetDuration: 1.0
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let frames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        for frame in frames {
            try await segmenter.ingestVideo(frame)
        }
        _ = try await segmenter.finish()

        let outputs = await collector.value
        let first = try #require(outputs.first)
        let boxes = try MP4BoxReader().readBoxes(
            from: first.videoSegment.data
        )
        #expect(boxes[0].type == "styp")
        #expect(boxes[1].type == "moof")
        #expect(boxes[2].type == "mdat")
    }

    // MARK: - Video + Audio

    @Test("Video+audio: outputs have both segments")
    func videoAudioOutputs() async throws {
        let segmenter = makeSegmenter(
            withAudio: true, targetDuration: 1.0
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let videoFrames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        let audioFrames = EncodedFrameFactory.audioFrames(
            count: 150
        )

        // Interleave video and audio
        var audioIdx = 0
        for videoFrame in videoFrames {
            try await segmenter.ingestVideo(videoFrame)
            // Feed a few audio frames per video frame
            while audioIdx < audioFrames.count,
                audioFrames[audioIdx].timestamp
                    <= videoFrame.timestamp
            {
                try await segmenter.ingestAudio(
                    audioFrames[audioIdx]
                )
                audioIdx += 1
            }
        }
        // Feed remaining audio
        while audioIdx < audioFrames.count {
            try await segmenter.ingestAudio(
                audioFrames[audioIdx]
            )
            audioIdx += 1
        }

        _ = try await segmenter.finish()
        let outputs = await collector.value
        #expect(outputs.count >= 2)
    }

    // MARK: - Codec Validation

    @Test("ingestVideo rejects audio frame")
    func ingestVideoRejectsAudio() async throws {
        let segmenter = makeSegmenter()
        let audioFrame = EncodedFrameFactory.audioFrame(
            timestamp: 0
        )
        await #expect(throws: LiveSegmenterError.self) {
            try await segmenter.ingestVideo(audioFrame)
        }
    }

    @Test("ingestAudio rejects video frame")
    func ingestAudioRejectsVideo() async throws {
        let segmenter = makeSegmenter()
        let videoFrame = EncodedFrameFactory.videoFrame(
            timestamp: 0, isKeyframe: true
        )
        await #expect(throws: LiveSegmenterError.self) {
            try await segmenter.ingestAudio(videoFrame)
        }
    }

    @Test("ingestAudio throws when no audio config")
    func ingestAudioNoConfig() async throws {
        let segmenter = makeSegmenter(withAudio: false)
        let audioFrame = EncodedFrameFactory.audioFrame(
            timestamp: 0
        )
        await #expect(throws: LiveSegmenterError.self) {
            try await segmenter.ingestAudio(audioFrame)
        }
    }

    // MARK: - Finish

    @Test("Finish returns final output")
    func finishReturnsFinal() async throws {
        let segmenter = makeSegmenter(
            withAudio: false, targetDuration: 10.0
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let frames = EncodedFrameFactory.videoFrames(
            count: 10, fps: 30.0, keyframeInterval: 10
        )
        for frame in frames {
            try await segmenter.ingestVideo(frame)
        }

        let final = try await segmenter.finish()
        #expect(final != nil)
        _ = await collector.value
    }

    @Test("Finish with no frames returns nil")
    func finishEmptyReturnsNil() async throws {
        let segmenter = makeSegmenter(withAudio: false)

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let final = try await segmenter.finish()
        #expect(final == nil)
        _ = await collector.value
    }

    @Test("Double finish returns nil")
    func doubleFinish() async throws {
        let segmenter = makeSegmenter(withAudio: false)

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        _ = try await segmenter.finish()
        let second = try await segmenter.finish()
        #expect(second == nil)
        _ = await collector.value
    }

    // MARK: - SegmentOutput

    @Test("SegmentOutput index matches video segment index")
    func segmentOutputIndex() async throws {
        let segmenter = makeSegmenter(
            withAudio: false, targetDuration: 1.0
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let frames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        for frame in frames {
            try await segmenter.ingestVideo(frame)
        }
        _ = try await segmenter.finish()

        let outputs = await collector.value
        for output in outputs {
            #expect(output.index == output.videoSegment.index)
        }
    }

    @Test("Ingest after finish throws")
    func ingestAfterFinish() async throws {
        let segmenter = makeSegmenter(withAudio: false)

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        _ = try await segmenter.finish()
        let frame = EncodedFrameFactory.videoFrame(
            timestamp: 0, isKeyframe: true
        )
        await #expect(throws: LiveSegmenterError.self) {
            try await segmenter.ingestVideo(frame)
        }
        _ = await collector.value
    }
}
