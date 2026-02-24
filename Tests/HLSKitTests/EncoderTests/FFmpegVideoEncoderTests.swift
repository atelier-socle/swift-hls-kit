// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("FFmpegVideoEncoder", .timeLimit(.minutes(1)))
    struct FFmpegVideoEncoderTests {

        // MARK: - Availability

        @Test("isAvailable returns a boolean")
        func isAvailableCheck() {
            let available = FFmpegVideoEncoder.isAvailable
            _ = available
        }

        // MARK: - Argument Building

        @Test("buildArguments: H.264 720p default config")
        func buildArgsH264Default() {
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 2_800_000,
                keyframeInterval: 6.0,
                qualityPreset: .p720
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            #expect(args.contains("-hide_banner"))
            #expect(args.contains("-f"))
            #expect(args.contains("rawvideo"))
            #expect(args.contains("-pix_fmt"))
            #expect(args.contains("yuv420p"))
            #expect(args.contains("-s"))
            #expect(args.contains("1280x720"))
            #expect(args.contains("-i"))
            #expect(args.contains("pipe:0"))
            #expect(args.contains("-c:v"))
            #expect(args.contains("libx264"))
            #expect(args.contains("-profile:v"))
            #expect(args.contains("high"))
            #expect(args.contains("-b:v"))
            #expect(args.contains("2800k"))
            #expect(args.contains("-g"))
            #expect(args.contains("180"))
            #expect(args.contains("h264"))
            #expect(args.contains("pipe:1"))
        }

        @Test("buildArguments: HEVC 1080p")
        func buildArgsHEVC() {
            let config = LiveEncoderConfiguration(
                videoCodec: .h265,
                videoBitrate: 5_000_000,
                keyframeInterval: 6.0,
                qualityPreset: .p1080
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            #expect(args.contains("libx265"))
            #expect(args.contains("hvc1"))
            #expect(args.contains("1920x1080"))
            #expect(args.contains("5000k"))
            #expect(args.contains("hevc"))
        }

        @Test("buildArguments: 360p with baseline profile")
        func buildArgs360p() {
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                keyframeInterval: 2.0,
                qualityPreset: .p360
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            #expect(args.contains("640x360"))
            #expect(args.contains("baseline"))
            #expect(args.contains("800k"))
            #expect(args.contains("60"))  // 2.0 * 30 = 60
        }

        @Test("buildArguments: includes maxrate and bufsize")
        func buildArgsRateControl() {
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 2_800_000,
                qualityPreset: .p720
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            #expect(args.contains("-maxrate"))
            #expect(args.contains("-bufsize"))
            #expect(args.contains("-keyint_min"))
        }

        @Test("buildArguments: uses preset defaults when no bitrate")
        func buildArgsPresetDefaults() {
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                qualityPreset: .p720
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            // Should use p720 preset videoBitrate (2_800_000)
            #expect(args.contains("2800k"))
        }

        @Test("buildArguments: default preset when none specified")
        func buildArgsNoPreset() {
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 1_000_000
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            // Default to p720 resolution
            #expect(args.contains("1280x720"))
            #expect(args.contains("1000k"))
        }

        @Test("buildArguments: AV1 codec")
        func buildArgsAV1() {
            let config = LiveEncoderConfiguration(
                videoCodec: .av1,
                videoBitrate: 2_000_000,
                qualityPreset: .p720
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            #expect(args.contains("libaom-av1"))
            #expect(args.contains("ivf"))
            #expect(args.contains("2000k"))
        }

        @Test("buildArguments: VP9 codec")
        func buildArgsVP9() {
            let config = LiveEncoderConfiguration(
                videoCodec: .vp9,
                videoBitrate: 1_500_000,
                qualityPreset: .p720
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            #expect(args.contains("libvpx-vp9"))
            #expect(args.contains("ivf"))
            #expect(args.contains("1500k"))
        }

        @Test("buildArguments: main profile 480p")
        func buildArgsMainProfile() {
            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 1_400_000,
                qualityPreset: .p480
            )
            let args = FFmpegVideoEncoder.buildArguments(
                for: config
            )

            #expect(args.contains("main"))
            #expect(args.contains("854x480"))
        }

        // MARK: - Error Cases

        @Test("Configure without videoCodec throws unsupported")
        func noVideoCodec() async {
            let encoder = FFmpegVideoEncoder()
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

        @Test("VP9 throws unsupportedConfiguration")
        func vp9Unsupported() async {
            let encoder = FFmpegVideoEncoder()
            let config = LiveEncoderConfiguration(
                videoCodec: .vp9,
                videoBitrate: 2_800_000,
                qualityPreset: .p720
            )

            await #expect(throws: LiveEncoderError.self) {
                try await encoder.configure(config)
            }
        }

        @Test("Encode before configure throws notConfigured")
        func encodeBeforeConfigure() async {
            let encoder = FFmpegVideoEncoder()
            let buffer = VideoTestDataGenerator.makeBuffer()

            await #expect(
                throws: LiveEncoderError.notConfigured
            ) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Encode after teardown throws tornDown")
        func encodeAfterTeardown() async throws {
            let encoder = FFmpegVideoEncoder()
            await encoder.teardown()

            let buffer = VideoTestDataGenerator.makeBuffer()

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.encode(buffer)
            }
        }

        @Test("Configure after teardown throws tornDown")
        func configureAfterTeardown() async throws {
            let encoder = FFmpegVideoEncoder()
            await encoder.teardown()

            let config = LiveEncoderConfiguration(
                videoCodec: .h264,
                videoBitrate: 800_000,
                qualityPreset: .p360
            )

            await #expect(throws: LiveEncoderError.tornDown) {
                try await encoder.configure(config)
            }
        }

        // MARK: - Lifecycle (requires ffmpeg)

        @Test("Full lifecycle with ffmpeg")
        func fullLifecycle() async throws {
            guard FFmpegVideoEncoder.isAvailable else {
                return
            }

            let encoder = FFmpegVideoEncoder()
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

            #expect(allFrames.count >= 1)
            for frame in allFrames {
                #expect(frame.codec == .h264)
                #expect(!frame.data.isEmpty)
            }

            await encoder.teardown()
        }

        @Test("Audio buffer throws formatMismatch")
        func audioBufferMismatch() async throws {
            guard FFmpegVideoEncoder.isAvailable else {
                return
            }

            let encoder = FFmpegVideoEncoder()
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

        @Test("Teardown without configure is safe")
        func teardownWithoutConfigure() async {
            let encoder = FFmpegVideoEncoder()
            await encoder.teardown()
        }
    }

#endif
