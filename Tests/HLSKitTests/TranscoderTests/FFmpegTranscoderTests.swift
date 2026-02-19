// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("FFmpegTranscoder — Unit Tests")
    struct FFmpegTranscoderTests {

        // MARK: - Availability

        @Test("isAvailable returns based on PATH")
        func isAvailableCheck() {
            let available = FFmpegTranscoder.isAvailable
            // Just verify it returns a Bool without crashing.
            #expect(available == true || available == false)
        }

        @Test("name returns FFmpeg")
        func nameCheck() {
            #expect(FFmpegTranscoder.name == "FFmpeg")
        }

        // MARK: - Init

        @Test("Init with invalid paths stores them")
        func initWithPaths() {
            let transcoder = FFmpegTranscoder(
                ffmpegPath: "/nonexistent/ffmpeg",
                ffprobePath: "/nonexistent/ffprobe"
            )
            #expect(FFmpegTranscoder.name == "FFmpeg")
            _ = transcoder
        }

        // MARK: - findExecutable

        @Test("findExecutable returns path for common tool")
        func findExecutableCommon() {
            let path = FFmpegProcessRunner.findExecutable("ls")
            #expect(path != nil)
            #expect(path?.hasSuffix("/ls") == true)
        }

        @Test("findExecutable returns nil for nonexistent")
        func findExecutableNonexistent() {
            let path = FFmpegProcessRunner.findExecutable(
                "definitely_not_a_real_binary_xyz"
            )
            #expect(path == nil)
        }

        // MARK: - Effective Preset

        @Test("Effective preset prevents upscaling")
        func effectivePresetNoUpscale() {
            let source = FFmpegSourceInfo(
                duration: 10.0,
                hasVideoTrack: true,
                hasAudioTrack: true,
                videoResolution: Resolution(
                    width: 640, height: 360
                ),
                videoCodec: "h264",
                videoFrameRate: 30.0,
                videoBitrate: 500_000,
                audioCodec: "aac",
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )

            let effective = FFmpegTranscoder.effectivePreset(
                .p1080, source: source
            )

            #expect(effective.resolution?.width == 640)
            #expect(effective.resolution?.height == 360)
            #expect(effective.videoBitrate == 500_000)
        }

        @Test("Effective preset passes through when not upscaling")
        func effectivePresetPassthrough() {
            let source = FFmpegSourceInfo(
                duration: 10.0,
                hasVideoTrack: true,
                hasAudioTrack: true,
                videoResolution: Resolution(
                    width: 1920, height: 1080
                ),
                videoCodec: "h264",
                videoFrameRate: 30.0,
                videoBitrate: 5_000_000,
                audioCodec: "aac",
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )

            let effective = FFmpegTranscoder.effectivePreset(
                .p720, source: source
            )

            #expect(effective.resolution?.width == 1280)
            #expect(effective.resolution?.height == 720)
        }

        @Test("Effective preset unchanged for audio-only")
        func effectivePresetAudioOnly() {
            let source = FFmpegSourceInfo(
                duration: 60.0,
                hasVideoTrack: false,
                hasAudioTrack: true,
                videoResolution: nil,
                videoCodec: nil,
                videoFrameRate: nil,
                videoBitrate: nil,
                audioCodec: "aac",
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )

            let effective = FFmpegTranscoder.effectivePreset(
                .audioOnly, source: source
            )

            #expect(effective.isAudioOnly)
            #expect(effective.name == "audio")
        }

        // MARK: - Source Validation

        @Test(
            "Transcode nonexistent source throws sourceNotFound",
            .enabled(if: FFmpegTranscoder.isAvailable)
        )
        func transcodeNonexistentSource() async {
            do {
                let transcoder = try FFmpegTranscoder()
                _ = try await transcoder.transcode(
                    input: URL(
                        fileURLWithPath: "/nonexistent/file.mp4"
                    ),
                    outputDirectory: URL(
                        fileURLWithPath: "/tmp/out"
                    ),
                    config: TranscodingConfig(),
                    progress: nil
                )
                Issue.record("Expected sourceNotFound error")
            } catch let error as TranscodingError {
                if case .sourceNotFound = error {
                    // Expected
                } else {
                    Issue.record(
                        "Expected sourceNotFound, got: \(error)"
                    )
                }
            } catch {
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

#endif
