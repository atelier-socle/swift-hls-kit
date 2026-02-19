// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing
    import os

    @testable import HLSKit

    @Suite("FFmpeg End-to-End")
    struct FFmpegEndToEndTests {

        private let tempDir: URL

        init() throws {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "ffmpeg-e2e-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        }

        private func cleanup() {
            try? FileManager.default.removeItem(at: tempDir)
        }

        private func requireFFmpeg() throws {
            try #require(
                FFmpegProcessRunner.isAvailable,
                "FFmpeg not installed — skipping"
            )
        }

        // MARK: - Audio Transcoding

        #if canImport(AVFoundation)

            @Test(
                "Transcode audio M4A → AAC segments",
                .timeLimit(.minutes(1))
            )
            func transcodeAudioToAAC() async throws {
                try requireFFmpeg()
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "e2e-audio.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "e2e-audio-out"
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

            @Test(
                "Transcode with progress reporting",
                .timeLimit(.minutes(1))
            )
            func transcodeWithProgress() async throws {
                try requireFFmpeg()
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "e2e-progress.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "e2e-progress-out"
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

            @Test(
                "Transcode audio-only → no video track",
                .timeLimit(.minutes(1))
            )
            func transcodeAudioOnlyNoVideo() async throws {
                try requireFFmpeg()
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "e2e-ao.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "e2e-ao-out"
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

                #expect(result.preset.isAudioOnly)
                #expect(result.preset.resolution == nil)
                #expect(result.preset.videoBitrate == nil)
            }

            @Test(
                "Transcode with MPEG-TS container format",
                .timeLimit(.minutes(1))
            )
            func transcodeMPEGTS() async throws {
                try requireFFmpeg()
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "e2e-ts.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "e2e-ts-out"
                )

                let transcoder = try FFmpegTranscoder()
                let result = try await transcoder.transcode(
                    input: sourceURL,
                    outputDirectory: outputDir,
                    config: TranscodingConfig(
                        containerFormat: .mpegTS,
                        audioPassthrough: false
                    ),
                    progress: nil
                )

                #expect(result.outputSize > 0)
            }

            @Test(
                "Transcode with audio passthrough",
                .timeLimit(.minutes(1))
            )
            func transcodePassthrough() async throws {
                try requireFFmpeg()
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "e2e-pt.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "e2e-pt-out"
                )

                let transcoder = try FFmpegTranscoder()
                let result = try await transcoder.transcode(
                    input: sourceURL,
                    outputDirectory: outputDir,
                    config: TranscodingConfig(
                        audioPassthrough: true
                    ),
                    progress: nil
                )

                #expect(result.outputSize > 0)
            }

            @Test(
                "ffprobe source analysis returns valid info",
                .timeLimit(.minutes(1))
            )
            func ffprobeAnalysis() async throws {
                try requireFFmpeg()
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "e2e-probe.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let runner = try FFmpegProcessRunner()
                let analyzer = FFmpegSourceAnalyzer(
                    runner: runner
                )
                let info = try await analyzer.analyze(sourceURL)

                #expect(info.duration > 0.5)
                #expect(info.hasAudioTrack)
                #expect(!info.hasVideoTrack)
                #expect(info.audioCodec != nil)
            }

        #endif

        // MARK: - Error Cases

        @Test("Error: non-existent source file")
        func nonExistentSource() async throws {
            try requireFFmpeg()
            defer { cleanup() }

            let transcoder = try FFmpegTranscoder()
            await #expect(throws: TranscodingError.self) {
                try await transcoder.transcode(
                    input: URL(
                        fileURLWithPath:
                            "/nonexistent/file.mp4"
                    ),
                    outputDirectory:
                        tempDir.appendingPathComponent("out"),
                    config: TranscodingConfig(),
                    progress: nil
                )
            }
        }

        @Test("Error: auto-creates output directory")
        func autoCreatesOutputDir() async throws {
            try requireFFmpeg()
            defer { cleanup() }

            #if canImport(AVFoundation)
                let sourceURL = tempDir.appendingPathComponent(
                    "e2e-autodir.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let nestedDir =
                    tempDir
                    .appendingPathComponent("a")
                    .appendingPathComponent("b")
                    .appendingPathComponent("c")

                let transcoder = try FFmpegTranscoder()
                let result = try await transcoder.transcode(
                    input: sourceURL,
                    outputDirectory: nestedDir,
                    config: TranscodingConfig(
                        audioPassthrough: false
                    ),
                    progress: nil
                )

                #expect(result.outputSize > 0)

                var isDir: ObjCBool = false
                let exists = FileManager.default.fileExists(
                    atPath: nestedDir.path,
                    isDirectory: &isDir
                )
                #expect(exists)
                #expect(isDir.boolValue)
            #endif
        }
    }

#endif
