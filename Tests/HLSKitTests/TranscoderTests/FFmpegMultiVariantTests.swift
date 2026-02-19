// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite(
        "FFmpeg Multi-Variant",
        .enabled(
            if: ProcessInfo.processInfo.environment["CI"] == nil,
            "Skipped in CI — requires hardware media processing"
        )
    )
    struct FFmpegMultiVariantTests {

        private let tempDir: URL

        init() throws {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "ffmpeg-mv-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        }

        private func cleanup() {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - Multi-Variant Transcoding

        #if canImport(AVFoundation)

            @Test(
                "transcodeVariants produces multiple outputs",
                .enabled(if: FFmpegProcessRunner.isAvailable),
                .timeLimit(.minutes(2))
            )
            func multipleOutputs() async throws {
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "mv-source.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "mv-out"
                )

                let low = QualityPreset(
                    name: "low",
                    resolution: nil,
                    videoBitrate: nil,
                    audioBitrate: 64_000,
                    videoProfile: nil
                )
                let high = QualityPreset(
                    name: "high",
                    resolution: nil,
                    videoBitrate: nil,
                    audioBitrate: 128_000,
                    videoProfile: nil
                )

                let transcoder = try FFmpegTranscoder()
                let result =
                    try await transcoder
                    .transcodeVariants(
                        input: sourceURL,
                        outputDirectory: outputDir,
                        variants: [low, high],
                        config: TranscodingConfig(
                            audioPassthrough: false
                        ),
                        progress: nil
                    )

                #expect(result.variants.count == 2)
                for variant in result.variants {
                    #expect(variant.outputSize > 0)
                    #expect(variant.sourceDuration > 0.5)
                }
            }

            @Test(
                "transcodeVariants generates master playlist",
                .enabled(if: FFmpegProcessRunner.isAvailable),
                .timeLimit(.minutes(2))
            )
            func masterPlaylist() async throws {
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "mv-pl-source.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "mv-pl-out"
                )

                let transcoder = try FFmpegTranscoder()
                let result =
                    try await transcoder
                    .transcodeVariants(
                        input: sourceURL,
                        outputDirectory: outputDir,
                        variants: [.audioOnly],
                        config: TranscodingConfig(
                            audioPassthrough: false
                        ),
                        progress: nil
                    )

                #expect(result.masterPlaylist != nil)
                #expect(
                    result.masterPlaylist?.contains("#EXTM3U")
                        == true
                )
            }

            @Test(
                "Multi-variant master playlist parseable by ManifestParser",
                .enabled(if: FFmpegProcessRunner.isAvailable),
                .timeLimit(.minutes(2))
            )
            func masterPlaylistParseable() async throws {
                defer { cleanup() }

                let sourceURL = tempDir.appendingPathComponent(
                    "mv-parse-source.m4a"
                )
                try await MediaFixtureGenerator.createAudioFixture(
                    at: sourceURL
                )

                let outputDir = tempDir.appendingPathComponent(
                    "mv-parse-out"
                )

                let transcoder = try FFmpegTranscoder()
                let result =
                    try await transcoder
                    .transcodeVariants(
                        input: sourceURL,
                        outputDirectory: outputDir,
                        variants: [.audioOnly],
                        config: TranscodingConfig(
                            audioPassthrough: false
                        ),
                        progress: nil
                    )

                let m3u8 = try #require(result.masterPlaylist)
                let parser = ManifestParser()
                let manifest = try parser.parse(m3u8)

                if case .master(let master) = manifest {
                    #expect(!master.variants.isEmpty)
                } else {
                    Issue.record("Expected master playlist")
                }
            }

        #endif
    }

#endif
