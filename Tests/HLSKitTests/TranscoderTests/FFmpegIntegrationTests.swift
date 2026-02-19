// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing
    import os

    @testable import HLSKit

    @Suite("FFmpegTranscoder — Integration")
    struct FFmpegIntegrationTests {

        private let tempDir: URL

        init() throws {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "ffmpeg-integration-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        }

        private func cleanup() {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - Audio Transcoding

        #if canImport(AVFoundation)

            @Test(
                "FFmpeg transcode audio file produces result",
                .enabled(if: FFmpegTranscoder.isAvailable),
                .timeLimit(.minutes(1))
            )
            func transcodeAudio() async throws {
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "ffmpeg-audio.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "ffmpeg-audio-out"
                )

                let transcoder = try FFmpegTranscoder()
                let result = try await transcoder.transcode(
                    input: sourceURL,
                    outputDirectory: outputDir,
                    config: TranscodingConfig(
                        audioPassthrough: false
                    ),
                    progress: nil
                )

                #expect(result.outputSize > 0)
                #expect(result.sourceDuration > 0.5)
                #expect(result.transcodingDuration > 0)
                #expect(result.preset.isAudioOnly)
            }

            // MARK: - Progress Reporting

            @Test(
                "FFmpeg transcode reports progress values",
                .enabled(if: FFmpegTranscoder.isAvailable),
                .timeLimit(.minutes(1))
            )
            func transcodeWithProgress() async throws {
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "ffmpeg-progress.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "ffmpeg-progress-out"
                )

                let collected = OSAllocatedUnfairLock(
                    initialState: [Double]()
                )

                let transcoder = try FFmpegTranscoder()
                let result = try await transcoder.transcode(
                    input: sourceURL,
                    outputDirectory: outputDir,
                    config: TranscodingConfig(
                        audioPassthrough: false
                    ),
                    progress: { value in
                        collected.withLock { $0.append(value) }
                    }
                )

                #expect(result.outputSize > 0)

                let values = collected.withLock { $0 }
                for value in values {
                    #expect(value >= 0.0)
                    #expect(value <= 1.0)
                }
            }

        #endif

        // MARK: - Error Cases

        @Test(
            "Transcode nonexistent file throws sourceNotFound",
            .enabled(if: FFmpegTranscoder.isAvailable)
        )
        func transcodeNonexistent() async throws {
            defer { cleanup() }

            let transcoder = try FFmpegTranscoder()
            await #expect(throws: TranscodingError.self) {
                try await transcoder.transcode(
                    input: URL(
                        fileURLWithPath: "/nonexistent/file.mp4"
                    ),
                    outputDirectory:
                        tempDir.appendingPathComponent("out"),
                    config: TranscodingConfig(),
                    progress: nil
                )
            }
        }
    }

#endif
