// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(VideoToolbox)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("VideoEncoder — Profiles", .timeLimit(.minutes(1)))
    struct VideoEncoderProfileTests {

        // MARK: - Profile Variants

        @Test("Baseline profile 360p encoding")
        func baselineProfile() async throws {
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
            let flushed = try await encoder.flush()
            let allFrames = frames + flushed

            for frame in allFrames {
                #expect(frame.codec == .h264)
            }

            await encoder.teardown()
        }

        @Test("Main profile 480p encoding")
        func mainProfile() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 1_400_000,
                keyframeInterval: 2.0,
                qualityPreset: .p480
            )
            try await encoder.configure(config)

            let buffer = VideoTestDataGenerator.makeBuffer(
                width: 854, height: 480
            )
            let frames = try await encoder.encode(buffer)
            let flushed = try await encoder.flush()
            let allFrames = frames + flushed

            for frame in allFrames {
                #expect(frame.codec == .h264)
            }

            await encoder.teardown()
        }

        @Test("HEVC high profile 1080p encoding")
        func hevcHighProfile() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h265,
                videoBitrate: 4_000_000,
                keyframeInterval: 2.0,
                qualityPreset: .p1080
            )
            try await encoder.configure(config)

            let buffer = VideoTestDataGenerator.makeBuffer(
                width: 1920, height: 1080
            )
            let frames = try await encoder.encode(buffer)
            let flushed = try await encoder.flush()
            let allFrames = frames + flushed

            for frame in allFrames {
                #expect(frame.codec == .h265)
            }

            await encoder.teardown()
        }

        // MARK: - Flush Safety

        @Test("Flush after teardown returns empty")
        func flushAfterTeardown() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                qualityPreset: .p360
            )
            try await encoder.configure(config)
            await encoder.teardown()

            let frames = try await encoder.flush()
            #expect(frames.isEmpty)
        }

        @Test("Multiple encodes accumulate frames")
        func multipleEncodes() async throws {
            let encoder = VideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                keyframeInterval: 2.0,
                qualityPreset: .p360
            )
            try await encoder.configure(config)

            let buffers = VideoTestDataGenerator.makeBuffers(
                count: 15,
                width: 640, height: 360, fps: 30.0
            )
            var allFrames: [EncodedFrame] = []
            for buffer in buffers {
                let frames = try await encoder.encode(buffer)
                allFrames.append(contentsOf: frames)
            }
            let flushed = try await encoder.flush()
            allFrames.append(contentsOf: flushed)

            #expect(allFrames.count >= 5)

            await encoder.teardown()
        }
    }

#endif
