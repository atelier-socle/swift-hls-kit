// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("FFmpegAudioEncoder", .timeLimit(.minutes(1)))
    struct FFmpegAudioEncoderTests {

        // MARK: - Availability

        @Test("isAvailable returns a boolean")
        func isAvailableCheck() {
            // Just verify it doesn't crash — result depends on system
            let available = FFmpegAudioEncoder.isAvailable
            _ = available  // No assertion on value
        }

        // MARK: - Argument Building

        @Test("buildArguments: podcast audio config")
        func buildArgumentsPodcast() {
            let args = FFmpegAudioEncoder.buildArguments(
                for: .podcastAudio
            )

            #expect(args.contains("-hide_banner"))
            #expect(args.contains("-f"))
            #expect(args.contains("s16le"))
            #expect(args.contains("-ar"))
            #expect(args.contains("44100"))
            #expect(args.contains("-ac"))
            #expect(args.contains("1"))
            #expect(args.contains("pipe:0"))
            #expect(args.contains("-c:a"))
            #expect(args.contains("aac"))
            #expect(args.contains("-b:a"))
            #expect(args.contains("64k"))
            #expect(args.contains("-f"))
            #expect(args.contains("adts"))
            #expect(args.contains("pipe:1"))
            #expect(args.contains("-profile:a"))
            #expect(args.contains("aac_low"))
        }

        @Test("buildArguments: music audio config")
        func buildArgumentsMusic() {
            let args = FFmpegAudioEncoder.buildArguments(
                for: .musicAudio
            )

            #expect(args.contains("48000"))
            #expect(args.contains("2"))
            #expect(args.contains("256k"))
            #expect(args.contains("aac_low"))
        }

        @Test("buildArguments: low bandwidth HE-AAC v2")
        func buildArgumentsLowBandwidth() {
            let args = FFmpegAudioEncoder.buildArguments(
                for: .lowBandwidthAudio
            )

            #expect(args.contains("32k"))
            #expect(args.contains("aac_he_v2"))
        }

        @Test("buildArguments: HE-AAC profile")
        func buildArgumentsHEAAC() {
            let config = LiveEncoderConfiguration(
                audioCodec: .aac,
                bitrate: 48_000,
                sampleRate: 44_100,
                channels: 2,
                aacProfile: .he
            )
            let args = FFmpegAudioEncoder.buildArguments(for: config)

            #expect(args.contains("aac_he"))
        }

        @Test("buildArguments: no profile for non-AAC")
        func buildArgumentsNoProfile() {
            let config = LiveEncoderConfiguration(
                audioCodec: .aac,
                bitrate: 128_000,
                sampleRate: 48_000,
                channels: 2
            )
            let args = FFmpegAudioEncoder.buildArguments(for: config)

            #expect(!args.contains("-profile:a"))
        }

        @Test("buildArguments: LD profile")
        func buildArgumentsLDProfile() {
            let config = LiveEncoderConfiguration(
                audioCodec: .aac,
                bitrate: 64_000,
                sampleRate: 48_000,
                channels: 1,
                aacProfile: .ld
            )
            let args = FFmpegAudioEncoder.buildArguments(for: config)

            #expect(args.contains("aac_ld"))
        }

        @Test("buildArguments: ELD profile")
        func buildArgumentsELDProfile() {
            let config = LiveEncoderConfiguration(
                audioCodec: .aac,
                bitrate: 64_000,
                sampleRate: 48_000,
                channels: 1,
                aacProfile: .eld
            )
            let args = FFmpegAudioEncoder.buildArguments(for: config)

            #expect(args.contains("aac_eld"))
        }

        // MARK: - Error Cases

        @Test("Unsupported codec throws unsupportedConfiguration")
        func unsupportedCodec() async {
            let encoder = FFmpegAudioEncoder()
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

        @Test("Passthrough throws unsupportedConfiguration")
        func passthroughUnsupported() async {
            let encoder = FFmpegAudioEncoder()

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.configure(.hiResPassthrough)
            }
        }

        @Test("Encode before configure throws notConfigured")
        func encodeBeforeConfigure() async {
            let encoder = FFmpegAudioEncoder()
            let generator = PCMTestDataGenerator()
            let buffer = generator.makeBuffer(sampleCount: 1024)

            await #expect(throws: LiveEncoderError.notConfigured) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Flush before configure throws notConfigured")
        func flushBeforeConfigure() async {
            let encoder = FFmpegAudioEncoder()

            await #expect(throws: LiveEncoderError.notConfigured) {
                try await encoder.flush()
            }
        }

        @Test("Encode after teardown throws tornDown")
        func encodeAfterTeardown() async throws {
            let encoder = FFmpegAudioEncoder()
            await encoder.teardown()

            let generator = PCMTestDataGenerator()
            let buffer = generator.makeBuffer(sampleCount: 1024)

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Configure after teardown throws tornDown")
        func configureAfterTeardown() async throws {
            let encoder = FFmpegAudioEncoder()
            await encoder.teardown()

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.configure(.podcastAudio)
            }
        }

        // MARK: - Lifecycle (requires ffmpeg)

        @Test("Full lifecycle with ffmpeg")
        func fullLifecycle() async throws {
            guard FFmpegAudioEncoder.isAvailable else {
                return  // Skip if ffmpeg not installed
            }

            let encoder = FFmpegAudioEncoder()
            try await encoder.configure(.podcastAudio)

            let generator = PCMTestDataGenerator(
                sampleRate: 44_100,
                channels: 1
            )

            // Encode enough data for several frames
            let buffer = generator.makeBuffer(duration: 1.0)
            let frames = try await encoder.encode(buffer)

            // ffmpeg may buffer — frames might come on flush
            let flushed = try await encoder.flush()

            let allFrames = frames + flushed
            // At least some frames should have been produced from 1s of audio
            #expect(allFrames.count >= 1)

            for frame in allFrames {
                #expect(frame.codec == .aac)
                #expect(frame.isKeyframe)
                #expect(!frame.data.isEmpty)
            }

            await encoder.teardown()
        }

        @Test("Teardown without configure is safe")
        func teardownWithoutConfigure() async {
            let encoder = FFmpegAudioEncoder()
            await encoder.teardown()
            // No crash = pass
        }

        @Test("Video buffer throws formatMismatch")
        func videoBufferMismatch() async throws {
            guard FFmpegAudioEncoder.isAvailable else {
                return
            }

            let encoder = FFmpegAudioEncoder()
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
    }

#endif
