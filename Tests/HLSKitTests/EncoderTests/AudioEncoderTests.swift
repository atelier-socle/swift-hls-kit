// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AudioToolbox)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("AudioEncoder", .timeLimit(.minutes(1)))
    struct AudioEncoderTests {

        // MARK: - Lifecycle

        @Test("Configure → encode → flush → teardown lifecycle")
        func fullLifecycle() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 44_100,
                channels: 1
            )

            // Encode enough data for several AAC frames (1024 samples each)
            let buffer = generator.makeBuffer(sampleCount: 4096)
            let frames = try await encoder.encode(buffer)

            // Should produce frames (1024 samples per frame, 4096 / 1024 = 4)
            #expect(frames.count >= 1)

            for frame in frames {
                #expect(frame.codec == .aac)
                #expect(frame.isKeyframe)
                #expect(!frame.data.isEmpty)
                #expect(frame.bitrateHint == 64_000)
            }

            let flushed = try await encoder.flush()
            // Flush may return 0 or 1 frame
            for frame in flushed {
                #expect(frame.codec == .aac)
            }

            await encoder.teardown()
        }

        // MARK: - PCM Int16 Encoding

        @Test("Encode Int16 PCM data produces AAC frames")
        func encodeInt16PCM() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 44_100,
                channels: 1
            )

            // Send enough data for multiple frames
            let buffer = generator.makeBuffer(sampleCount: 8192)
            let frames = try await encoder.encode(buffer)

            #expect(frames.count >= 2)

            for frame in frames {
                #expect(frame.codec == .aac)
                #expect(!frame.data.isEmpty)
            }

            await encoder.teardown()
        }

        // MARK: - Timestamp Monotonicity

        @Test("Timestamps are monotonically increasing")
        func timestampMonotonicity() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 44_100,
                channels: 1
            )

            var allFrames: [EncodedFrame] = []

            // Encode several buffers
            for _ in 0..<5 {
                let buffer = generator.makeBuffer(sampleCount: 2048)
                let frames = try await encoder.encode(buffer)
                allFrames.append(contentsOf: frames)
            }

            let flushed = try await encoder.flush()
            allFrames.append(contentsOf: flushed)

            // Verify monotonicity
            guard allFrames.count >= 2 else {
                await encoder.teardown()
                return
            }

            for index in 1..<allFrames.count {
                #expect(
                    allFrames[index].timestamp.seconds
                        > allFrames[index - 1].timestamp.seconds,
                    "Frame \(index) timestamp should be > frame \(index - 1)"
                )
            }

            await encoder.teardown()
        }

        // MARK: - Error Cases

        @Test("Encode before configure throws notConfigured")
        func encodeBeforeConfigure() async {
            let encoder = AudioEncoder()
            let generator = PCMTestDataGenerator()
            let buffer = generator.makeBuffer(sampleCount: 1024)

            await #expect(throws: LiveEncoderError.notConfigured) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Flush before configure throws notConfigured")
        func flushBeforeConfigure() async {
            let encoder = AudioEncoder()

            await #expect(throws: LiveEncoderError.notConfigured) {
                try await encoder.flush()
            }
        }

        @Test("Encode after teardown throws tornDown")
        func encodeAfterTeardown() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)
            await encoder.teardown()

            let generator = PCMTestDataGenerator(
                sampleRate: 44_100,
                channels: 1
            )
            let buffer = generator.makeBuffer(sampleCount: 1024)

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Configure after teardown throws tornDown")
        func configureAfterTeardown() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)
            await encoder.teardown()

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.configure(.podcastAudio)
            }
        }

        @Test("Unsupported codec throws unsupportedConfiguration")
        func unsupportedCodec() async {
            let encoder = AudioEncoder()
            let config = LiveEncoderConfiguration(
                audioCodec: .opus,
                bitrate: 128_000,
                sampleRate: 48_000,
                channels: 2
            )

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.configure(config)
            }
        }

        @Test("Passthrough mode throws unsupportedConfiguration")
        func passthroughUnsupported() async {
            let encoder = AudioEncoder()

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.configure(.hiResPassthrough)
            }
        }

        // MARK: - Format Mismatch

        @Test("Video buffer throws formatMismatch")
        func videoBufferMismatch() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            let videoBuffer = RawMediaBuffer(
                data: Data(repeating: 0, count: 100),
                timestamp: .zero,
                duration: MediaTimestamp(seconds: 0.033),
                isKeyframe: true,
                mediaType: .video,
                formatInfo: .video(codec: .h264, width: 1920, height: 1080)
            )

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.encode(videoBuffer)
            }

            await encoder.teardown()
        }

        @Test("Wrong sample rate throws formatMismatch")
        func wrongSampleRate() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            // Configure expects 44100, provide 48000
            let buffer = RawMediaBuffer(
                data: Data(repeating: 0, count: 4096),
                timestamp: .zero,
                duration: MediaTimestamp(seconds: 0.5),
                isKeyframe: true,
                mediaType: .audio,
                formatInfo: .audio(
                    sampleRate: 48_000,
                    channels: 1,
                    bitsPerSample: 16
                )
            )

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.encode(buffer)
            }

            await encoder.teardown()
        }

        // MARK: - Various Configurations

        @Test("Stereo encoding at 48kHz")
        func stereoEncoding() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.musicAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 48_000,
                channels: 2
            )
            let buffer = generator.makeBuffer(sampleCount: 4096)
            let frames = try await encoder.encode(buffer)

            #expect(frames.count >= 1)
            for frame in frames {
                #expect(frame.codec == .aac)
            }

            await encoder.teardown()
        }

        @Test("Reconfigure replaces previous configuration")
        func reconfigure() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            // Reconfigure to stereo
            try await encoder.configure(.musicAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 48_000,
                channels: 2
            )
            let buffer = generator.makeBuffer(sampleCount: 4096)
            let frames = try await encoder.encode(buffer)

            // Should work with new config
            #expect(frames.count >= 1)

            await encoder.teardown()
        }

        // MARK: - Frame Duration

        @Test("Frame duration is approximately 1024/sampleRate")
        func frameDuration() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 44_100,
                channels: 1
            )
            let buffer = generator.makeBuffer(sampleCount: 4096)
            let frames = try await encoder.encode(buffer)

            let expectedDuration = 1024.0 / 44_100.0

            for frame in frames {
                #expect(
                    abs(frame.duration.seconds - expectedDuration) < 0.0001,
                    "Frame duration \(frame.duration.seconds) should be ~\(expectedDuration)"
                )
            }

            await encoder.teardown()
        }

        // MARK: - Accumulation

        @Test("Small buffers accumulate before producing frames")
        func smallBufferAccumulation() async throws {
            let encoder = AudioEncoder()
            try await encoder.configure(.podcastAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 44_100,
                channels: 1
            )

            // Send 512 samples (less than 1024 needed for AAC frame)
            let smallBuffer = generator.makeBuffer(sampleCount: 512)
            let frames1 = try await encoder.encode(smallBuffer)
            #expect(frames1.isEmpty)

            // Send another 512 samples to complete one frame
            let frames2 = try await encoder.encode(smallBuffer)
            #expect(frames2.count == 1)

            await encoder.teardown()
        }
    }

#endif
