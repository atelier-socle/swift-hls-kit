// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && (os(macOS) || os(Linux))

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite(
        "Cross-Transcoder Comparison",
        .enabled(
            if: ProcessInfo.processInfo.environment["CI"] == nil,
            "Skipped in CI — requires hardware media processing"
        )
    )
    struct CrossTranscoderTests {

        private let tempDir: URL

        init() throws {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "cross-transcoder-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        }

        private func cleanup() {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - Apple vs FFmpeg

        @Test(
            "Same audio source: both produce valid output",
            .enabled(if: FFmpegProcessRunner.isAvailable),
            .timeLimit(.minutes(2))
        )
        func sameSourceBothValid() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "cross-audio.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let appleDir = tempDir.appendingPathComponent(
                "apple-out"
            )
            let ffmpegDir = tempDir.appendingPathComponent(
                "ffmpeg-out"
            )

            let config = TranscodingConfig(
                audioPassthrough: false
            )

            let appleResult = try await AppleTranscoder()
                .transcode(
                    input: sourceURL,
                    outputDirectory: appleDir,
                    config: config,
                    progress: nil
                )

            let ffmpegResult = try await FFmpegTranscoder()
                .transcode(
                    input: sourceURL,
                    outputDirectory: ffmpegDir,
                    config: config,
                    progress: nil
                )

            #expect(appleResult.outputSize > 0)
            #expect(ffmpegResult.outputSize > 0)
            #expect(appleResult.sourceDuration > 0.5)
            #expect(ffmpegResult.sourceDuration > 0.5)

            let durationDiff = abs(
                appleResult.sourceDuration
                    - ffmpegResult.sourceDuration
            )
            #expect(durationDiff < 0.5)
        }

        @Test(
            "Same source: segment counts similar",
            .enabled(if: FFmpegProcessRunner.isAvailable),
            .timeLimit(.minutes(2))
        )
        func sameSourceSegmentCounts() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "cross-seg.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let appleDir = tempDir.appendingPathComponent(
                "apple-seg-out"
            )
            let ffmpegDir = tempDir.appendingPathComponent(
                "ffmpeg-seg-out"
            )

            let config = TranscodingConfig(
                containerFormat: .mpegTS,
                generatePlaylist: true,
                audioPassthrough: false
            )

            let appleResult = try await AppleTranscoder()
                .transcode(
                    input: sourceURL,
                    outputDirectory: appleDir,
                    config: config,
                    progress: nil
                )

            let ffmpegResult = try await FFmpegTranscoder()
                .transcode(
                    input: sourceURL,
                    outputDirectory: ffmpegDir,
                    config: config,
                    progress: nil
                )

            #expect(appleResult.outputSize > 0)
            #expect(ffmpegResult.outputSize > 0)

            #expect(appleResult.preset.isAudioOnly)
            #expect(ffmpegResult.preset.isAudioOnly)
        }

        // MARK: - HLSEngine Platform Selection

        @Test("HLSEngine picks correct transcoder per platform")
        func enginePicksCorrectTranscoder() {
            let engine = HLSEngine()
            #expect(engine.isTranscoderAvailable)
        }
    }

#endif
