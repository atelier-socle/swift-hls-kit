// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "Specialized Segmenter Edge Cases",
    .timeLimit(.minutes(1))
)
struct SpecializedSegmenterEdgeCaseTests {

    // MARK: - AudioSegmenter Edge Cases

    @Test("AudioSegmenter: finish with no frames returns nil")
    func audioFinishEmpty() async throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segmenter = AudioSegmenter(audioConfig: config)

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let result = try await segmenter.finish()
        #expect(result == nil)
        let emitted = await collector.value
        #expect(emitted.isEmpty)
    }

    @Test("AudioSegmenter: init segment parseable")
    func audioInitParseable() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let segmenter = AudioSegmenter(audioConfig: config)
        let initData = try #require(segmenter.initSegment)
        let boxes = try MP4BoxReader().readBoxes(from: initData)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    @Test("AudioSegmenter: configuration accessible")
    func audioConfiguration() {
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 3.0,
            keyframeAligned: false
        )
        let config = CMAFWriter.AudioConfig(
            sampleRate: 44100, channels: 1
        )
        let segmenter = AudioSegmenter(
            audioConfig: config,
            configuration: segConfig
        )
        #expect(segmenter.audioConfig.sampleRate == 44100)
        #expect(segmenter.audioConfig.channels == 1)
        #expect(segmenter.configuration.targetDuration == 3.0)
    }

    // MARK: - VideoSegmenter Edge Cases

    @Test("VideoSegmenter: ingestVideo rejects audio codec")
    func videoIngestRejectsAudio() async throws {
        let videoConfig = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1280, height: 720,
            sps: Data([0x67, 0x42]),
            pps: Data([0x68, 0xCE])
        )
        let segmenter = VideoSegmenter(
            videoConfig: videoConfig
        )
        let audioFrame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        await #expect(throws: LiveSegmenterError.self) {
            try await segmenter.ingestVideo(audioFrame)
        }
    }

    @Test("VideoSegmenter: ingestAudio rejects video codec")
    func audioIngestRejectsVideo() async throws {
        let videoConfig = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1280, height: 720,
            sps: Data([0x67, 0x42]),
            pps: Data([0x68, 0xCE])
        )
        let audioConfig = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segmenter = VideoSegmenter(
            videoConfig: videoConfig,
            audioConfig: audioConfig
        )
        let videoFrame = EncodedFrameFactory.videoFrame(
            timestamp: 0.0, isKeyframe: true
        )
        await #expect(throws: LiveSegmenterError.self) {
            try await segmenter.ingestAudio(videoFrame)
        }
    }

    @Test("VideoSegmenter: video-only has nil audioSegment")
    func videoOnlyNilAudio() async throws {
        let videoConfig = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 640, height: 480,
            sps: Data([0x67, 0x42]),
            pps: Data([0x68, 0xCE])
        )
        let segmenter = VideoSegmenter(
            videoConfig: videoConfig
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
            count: 60, fps: 30.0, keyframeInterval: 30
        )
        for frame in frames {
            try await segmenter.ingestVideo(frame)
        }
        _ = try await segmenter.finish()

        let outputs = await collector.value
        #expect(outputs.count >= 1)
        for output in outputs {
            #expect(output.audioSegment == nil)
        }
        #expect(segmenter.audioInitSegment == nil)
    }

    @Test("VideoSegmenter: finish with no frames → nil")
    func videoFinishEmpty() async throws {
        let videoConfig = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1280, height: 720,
            sps: Data([0x67, 0x42]),
            pps: Data([0x68, 0xCE])
        )
        let segmenter = VideoSegmenter(
            videoConfig: videoConfig
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let result = try await segmenter.finish()
        #expect(result == nil)

        let outputs = await collector.value
        #expect(outputs.isEmpty)
    }
}
