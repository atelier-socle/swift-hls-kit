// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(VideoToolbox)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("VideoEncoder", .timeLimit(.minutes(1)))
    struct VideoEncoderTests {

        // MARK: - Lifecycle

        @Test("Configure → encode → flush → teardown lifecycle")
        func fullLifecycle() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                keyframeInterval: 2.0,
                qualityPreset: .p360
            )
            try await encoder.configure(config)

            let buffers = VideoTestDataGenerator.makeBuffers(
                count: 5,
                width: 640, height: 360, fps: 30.0
            )
            var allFrames: [EncodedFrame] = []

            for buffer in buffers {
                let frames = try await encoder.encode(buffer)
                allFrames.append(contentsOf: frames)
            }

            let flushed = try await encoder.flush()
            allFrames.append(contentsOf: flushed)

            #expect(allFrames.count >= 1)
            for frame in allFrames {
                #expect(frame.codec == .h264)
                #expect(!frame.data.isEmpty)
                #expect(frame.bitrateHint == 800_000)
            }

            await encoder.teardown()
        }

        // MARK: - Keyframes

        @Test("First frame is a keyframe")
        func firstFrameIsKeyframe() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                keyframeInterval: 2.0,
                qualityPreset: .p360
            )
            try await encoder.configure(config)

            let buffer = VideoTestDataGenerator.makeBuffer(
                width: 640, height: 360
            )
            let frames = try await encoder.encode(buffer)

            if let first = frames.first {
                #expect(first.isKeyframe)
            }

            await encoder.teardown()
        }

        // MARK: - Timestamp Monotonicity

        @Test("Timestamps are monotonically increasing")
        func timestampMonotonicity() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                keyframeInterval: 2.0,
                qualityPreset: .p360
            )
            try await encoder.configure(config)

            let buffers = VideoTestDataGenerator.makeBuffers(
                count: 10,
                width: 640, height: 360, fps: 30.0
            )
            var allFrames: [EncodedFrame] = []

            for buffer in buffers {
                let frames = try await encoder.encode(buffer)
                allFrames.append(contentsOf: frames)
            }

            let flushed = try await encoder.flush()
            allFrames.append(contentsOf: flushed)

            guard allFrames.count >= 2 else {
                await encoder.teardown()
                return
            }

            for index in 1..<allFrames.count {
                #expect(
                    allFrames[index].timestamp.seconds
                        >= allFrames[index - 1].timestamp.seconds,
                    "Frame \(index) should have timestamp >= frame \(index - 1)"
                )
            }

            await encoder.teardown()
        }

        // MARK: - Error Cases

        @Test("Encode before configure throws notConfigured")
        func encodeBeforeConfigure() async {
            let encoder = VideoEncoder()
            let buffer = VideoTestDataGenerator.makeBuffer()

            await #expect(throws: LiveEncoderError.notConfigured) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Encode after teardown throws tornDown")
        func encodeAfterTeardown() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                qualityPreset: .p360
            )
            try await encoder.configure(config)
            await encoder.teardown()

            let buffer = VideoTestDataGenerator.makeBuffer()

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Configure after teardown throws tornDown")
        func configureAfterTeardown() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                qualityPreset: .p360
            )
            try await encoder.configure(config)
            await encoder.teardown()

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.configure(config)
            }
        }

        @Test("Configure without videoCodec throws unsupported")
        func noVideoCodec() async {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                audioCodec: .aac,
                bitrate: 128_000,
                sampleRate: 48_000,
                channels: 2
            )

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.configure(config)
            }
        }

        @Test("AV1 throws unsupportedConfiguration")
        func av1Unsupported() async {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .av1,
                videoBitrate: 2_800_000,
                qualityPreset: .p720
            )

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.configure(config)
            }
        }

        // MARK: - Format Mismatch

        @Test("Audio buffer throws formatMismatch")
        func audioBufferMismatch() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                qualityPreset: .p360
            )
            try await encoder.configure(config)

            let audioBuffer = RawMediaBuffer(
                data: Data(repeating: 0, count: 100),
                timestamp: .zero,
                duration: MediaTimestamp(seconds: 0.023),
                isKeyframe: true,
                mediaType: .audio,
                formatInfo: .audio(
                    sampleRate: 44_100, channels: 1,
                    bitsPerSample: 16
                )
            )

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.encode(audioBuffer)
            }

            await encoder.teardown()
        }

        // MARK: - HEVC

        @Test("HEVC encoding produces h265 codec frames")
        func hevcEncoding() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h265,
                videoBitrate: 2_000_000,
                keyframeInterval: 2.0,
                qualityPreset: .p720
            )
            try await encoder.configure(config)

            let buffer = VideoTestDataGenerator.makeBuffer(
                width: 1280, height: 720
            )
            let frames = try await encoder.encode(buffer)
            let flushed = try await encoder.flush()
            let allFrames = frames + flushed

            for frame in allFrames {
                #expect(frame.codec == .h265)
            }

            await encoder.teardown()
        }

        // MARK: - Reconfigure

        @Test("Reconfigure replaces previous session")
        func reconfigure() async throws {
            let encoder = VideoEncoder()
            let config1 = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                qualityPreset: .p360
            )
            try await encoder.configure(config1)

            let config2 = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 2_800_000,
                qualityPreset: .p720
            )
            try await encoder.configure(config2)

            let buffer = VideoTestDataGenerator.makeBuffer(
                width: 1280, height: 720
            )
            let frames = try await encoder.encode(buffer)
            let flushed = try await encoder.flush()
            let allFrames = frames + flushed

            for frame in allFrames {
                #expect(frame.bitrateHint == 2_800_000)
            }

            await encoder.teardown()
        }

        // MARK: - Flush Safety

        @Test("Flush before configure returns empty")
        func flushBeforeConfigure() async throws {
            let encoder = VideoEncoder()
            let frames = try await encoder.flush()
            #expect(frames.isEmpty)
        }

        @Test("Teardown without configure is safe")
        func teardownWithoutConfigure() async {
            let encoder = VideoEncoder()
            await encoder.teardown()
        }
    }

#endif
