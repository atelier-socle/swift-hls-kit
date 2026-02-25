// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Factory for creating test ``EncodedFrame`` objects.
///
/// Generates synthetic encoded frames with configurable timestamps,
/// codecs, and keyframe flags for LiveSegmenter testing.
enum EncodedFrameFactory {

    // MARK: - Single Frame

    /// Create a single audio frame (AAC).
    static func audioFrame(
        timestamp: TimeInterval,
        duration: TimeInterval = 1024.0 / 48000.0,
        dataSize: Int = 512,
        codec: EncodedCodec = .aac
    ) -> EncodedFrame {
        EncodedFrame(
            data: Data(repeating: 0xAA, count: dataSize),
            timestamp: MediaTimestamp(seconds: timestamp),
            duration: MediaTimestamp(seconds: duration),
            isKeyframe: true,
            codec: codec
        )
    }

    /// Create a single video frame (H.264).
    static func videoFrame(
        timestamp: TimeInterval,
        duration: TimeInterval = 1.0 / 30.0,
        isKeyframe: Bool = false,
        dataSize: Int = 4096,
        codec: EncodedCodec = .h264
    ) -> EncodedFrame {
        EncodedFrame(
            data: Data(repeating: 0xBB, count: dataSize),
            timestamp: MediaTimestamp(seconds: timestamp),
            duration: MediaTimestamp(seconds: duration),
            isKeyframe: isKeyframe,
            codec: codec
        )
    }

    // MARK: - Sequences

    /// Create a sequence of audio frames at regular intervals.
    static func audioFrames(
        count: Int,
        sampleRate: Double = 48000.0,
        samplesPerFrame: Int = 1024,
        codec: EncodedCodec = .aac,
        startTimestamp: TimeInterval = 0
    ) -> [EncodedFrame] {
        let frameDuration = Double(samplesPerFrame) / sampleRate
        return (0..<count).map { i in
            audioFrame(
                timestamp: startTimestamp + Double(i) * frameDuration,
                duration: frameDuration,
                codec: codec
            )
        }
    }

    /// Create a sequence of video frames at regular intervals
    /// with keyframes.
    static func videoFrames(
        count: Int,
        fps: Double = 30.0,
        keyframeInterval: Int = 30,
        codec: EncodedCodec = .h264,
        startTimestamp: TimeInterval = 0
    ) -> [EncodedFrame] {
        let frameDuration = 1.0 / fps
        return (0..<count).map { i in
            videoFrame(
                timestamp: startTimestamp + Double(i) * frameDuration,
                duration: frameDuration,
                isKeyframe: i % keyframeInterval == 0,
                codec: codec
            )
        }
    }

    /// Create an interleaved audio+video frame sequence.
    ///
    /// Produces a realistic sequence where audio frames (~21ms)
    /// are interleaved with video frames (~33ms), sorted by
    /// timestamp.
    static func interleavedFrames(
        duration: TimeInterval,
        videoFPS: Double = 30.0,
        audioSampleRate: Double = 48000.0,
        keyframeIntervalSeconds: TimeInterval = 2.0
    ) -> [EncodedFrame] {
        let audioDuration = 1024.0 / audioSampleRate
        let videoDuration = 1.0 / videoFPS
        let keyframeInterval = Int(keyframeIntervalSeconds * videoFPS)

        var frames: [EncodedFrame] = []

        // Audio frames
        var audioTime = 0.0
        while audioTime < duration {
            frames.append(
                audioFrame(
                    timestamp: audioTime,
                    duration: audioDuration
                )
            )
            audioTime += audioDuration
        }

        // Video frames
        var videoTime = 0.0
        var videoIndex = 0
        while videoTime < duration {
            frames.append(
                videoFrame(
                    timestamp: videoTime,
                    duration: videoDuration,
                    isKeyframe: videoIndex % keyframeInterval == 0
                )
            )
            videoTime += videoDuration
            videoIndex += 1
        }

        return frames.sorted { $0.timestamp < $1.timestamp }
    }
}
