// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("VideoSegmenter — Audio Sync", .timeLimit(.minutes(1)))
struct VideoSegmenterAudioSyncTests {

    // MARK: - Helpers

    private func makeSPS() -> Data {
        Data([0x67, 0x42, 0xC0, 0x1E, 0xD9, 0x00, 0xA0])
    }

    private func makePPS() -> Data {
        Data([0x68, 0xCE, 0x38, 0x80])
    }

    private func makeSegmenter(
        targetDuration: TimeInterval = 1.0
    ) -> VideoSegmenter {
        let config = LiveSegmenterConfiguration(
            targetDuration: targetDuration,
            keyframeAligned: true
        )
        return VideoSegmenter(
            videoConfig: CMAFWriter.VideoConfig(
                codec: .h264,
                width: 1280, height: 720,
                sps: makeSPS(), pps: makePPS()
            ),
            audioConfig: CMAFWriter.AudioConfig(
                sampleRate: 48000, channels: 2, profile: .lc
            ),
            configuration: config
        )
    }

    private func ingestInterleaved(
        segmenter: VideoSegmenter,
        video: [EncodedFrame],
        audio: [EncodedFrame]
    ) async throws {
        var vi = 0
        var ai = 0
        while vi < video.count || ai < audio.count {
            let feedVideo: Bool
            if vi >= video.count {
                feedVideo = false
            } else if ai >= audio.count {
                feedVideo = true
            } else {
                feedVideo =
                    video[vi].timestamp
                    <= audio[ai].timestamp
            }
            if feedVideo {
                try await segmenter.ingestVideo(video[vi])
                vi += 1
            } else {
                try await segmenter.ingestAudio(audio[ai])
                ai += 1
            }
        }
    }

    // MARK: - Tests

    @Test("Video+audio: outputs have both segments")
    func videoAudioOutputs() async throws {
        let segmenter = makeSegmenter()
        let collector = Task<[VideoSegmenter.SegmentOutput], Never> {
            var outputs: [VideoSegmenter.SegmentOutput] = []
            for await output in segmenter.segmentOutputs {
                outputs.append(output)
            }
            return outputs
        }
        let vFrames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        let aFrames = EncodedFrameFactory.audioFrames(
            count: 150
        )
        try await ingestInterleaved(
            segmenter: segmenter,
            video: vFrames, audio: aFrames
        )
        _ = try await segmenter.finish()
        let outputs = await collector.value
        #expect(outputs.count >= 2)
    }

    @Test("Audio frames distributed across segments")
    func audioDistribution() async throws {
        let segmenter = makeSegmenter()
        let collector = Task<[VideoSegmenter.SegmentOutput], Never> {
            var outputs: [VideoSegmenter.SegmentOutput] = []
            for await output in segmenter.segmentOutputs {
                outputs.append(output)
            }
            return outputs
        }
        let vFrames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        let aFrames = EncodedFrameFactory.audioFrames(
            count: 150
        )
        try await ingestInterleaved(
            segmenter: segmenter,
            video: vFrames, audio: aFrames
        )
        _ = try await segmenter.finish()
        let outputs = await collector.value
        let withAudio = outputs.filter {
            $0.audioSegment != nil
        }
        #expect(withAudio.count == outputs.count)
        let frameCounts = withAudio.map {
            $0.audioSegment?.frameCount ?? 0
        }
        let maxCount = frameCounts.max() ?? 0
        let total = frameCounts.reduce(0, +)
        // No single segment should have > 60% of frames
        #expect(
            Double(maxCount) / Double(total) < 0.6,
            "Audio frames poorly distributed: \(frameCounts)"
        )
    }
}
