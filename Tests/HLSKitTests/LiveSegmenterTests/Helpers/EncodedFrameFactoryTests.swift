// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EncodedFrameFactory", .timeLimit(.minutes(1)))
struct EncodedFrameFactoryTests {

    @Test("audioFrame creates valid audio frame")
    func audioFrameCreation() {
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 1.0
        )
        #expect(frame.codec == .aac)
        #expect(frame.isKeyframe)
        #expect(frame.timestamp.seconds == 1.0)
        #expect(frame.data.count == 512)
    }

    @Test("audioFrame with custom parameters")
    func audioFrameCustom() {
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 2.5,
            duration: 0.05,
            dataSize: 256,
            codec: .opus
        )
        #expect(frame.codec == .opus)
        #expect(frame.duration.seconds == 0.05)
        #expect(frame.data.count == 256)
    }

    @Test("videoFrame creates valid video frame")
    func videoFrameCreation() {
        let frame = EncodedFrameFactory.videoFrame(
            timestamp: 0.0, isKeyframe: true
        )
        #expect(frame.codec == .h264)
        #expect(frame.isKeyframe)
        #expect(frame.data.count == 4096)
    }

    @Test("videoFrame non-keyframe by default")
    func videoFrameNonKeyframe() {
        let frame = EncodedFrameFactory.videoFrame(
            timestamp: 0.033
        )
        #expect(!frame.isKeyframe)
    }

    @Test("audioFrames sequence has correct timestamps")
    func audioFramesSequence() {
        let frames = EncodedFrameFactory.audioFrames(count: 10)
        #expect(frames.count == 10)
        let expectedDuration = 1024.0 / 48000.0
        for i in 0..<10 {
            let expected = Double(i) * expectedDuration
            #expect(
                abs(frames[i].timestamp.seconds - expected) < 0.0001
            )
        }
    }

    @Test("audioFrames with custom start timestamp")
    func audioFramesCustomStart() {
        let frames = EncodedFrameFactory.audioFrames(
            count: 5, startTimestamp: 10.0
        )
        #expect(frames[0].timestamp.seconds >= 10.0)
    }

    @Test("videoFrames sequence has correct keyframe intervals")
    func videoFramesKeyframes() {
        let frames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        #expect(frames.count == 90)
        #expect(frames[0].isKeyframe)
        #expect(!frames[1].isKeyframe)
        #expect(!frames[29].isKeyframe)
        #expect(frames[30].isKeyframe)
        #expect(frames[60].isKeyframe)
    }

    @Test("videoFrames timestamps are monotonic")
    func videoFramesMonotonic() {
        let frames = EncodedFrameFactory.videoFrames(
            count: 50
        )
        for i in 1..<frames.count {
            #expect(
                frames[i].timestamp.seconds
                    > frames[i - 1].timestamp.seconds
            )
        }
    }

    @Test("interleavedFrames are sorted by timestamp")
    func interleavedSorted() {
        let frames = EncodedFrameFactory.interleavedFrames(
            duration: 2.0
        )
        #expect(!frames.isEmpty)
        for i in 1..<frames.count {
            #expect(
                frames[i].timestamp.seconds
                    >= frames[i - 1].timestamp.seconds
            )
        }
    }

    @Test("interleavedFrames contain both audio and video")
    func interleavedContainsBoth() {
        let frames = EncodedFrameFactory.interleavedFrames(
            duration: 1.0
        )
        let hasAudio = frames.contains { $0.codec.isAudio }
        let hasVideo = frames.contains { $0.codec.isVideo }
        #expect(hasAudio)
        #expect(hasVideo)
    }

    @Test("interleavedFrames video has correct keyframe interval")
    func interleavedKeyframes() {
        let frames = EncodedFrameFactory.interleavedFrames(
            duration: 5.0,
            keyframeIntervalSeconds: 2.0
        )
        let videoFrames = frames.filter { $0.codec.isVideo }
        let keyframes = videoFrames.filter { $0.isKeyframe }
        // At 30fps, 5s = 150 video frames, keyframe every 2s
        // = every 60 frames → ~3 keyframes
        #expect(keyframes.count >= 2)
    }
}
