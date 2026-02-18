// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("HLSEngine Transcoding — Integration")
    struct HLSEngineTranscodingIntegrationTests {

        private let tempDir: URL

        init() throws {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "hls-engine-\(UUID().uuidString)"
                )
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
        }

        private func cleanup() {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - HLSEngine.transcode

        @Test(
            "Engine transcode audio produces result",
            .timeLimit(.minutes(1))
        )
        func engineTranscodeAudio() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "engine-audio.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "engine-audio-out"
            )

            let engine = HLSEngine()
            let result = try await engine.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: TranscodingConfig(
                    audioPassthrough: false
                )
            )

            #expect(result.outputSize > 0)
            #expect(result.sourceDuration > 0.5)
            #expect(result.transcodingDuration > 0)
        }

        @Test(
            "Engine transcode video produces result",
            .timeLimit(.minutes(2))
        )
        func engineTranscodeVideo() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "engine-video.mp4"
            )
            try await MediaFixtureGenerator.createVideoFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "engine-video-out"
            )

            let engine = HLSEngine()
            let result = try await engine.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: TranscodingConfig(
                    audioPassthrough: false
                )
            )

            #expect(result.outputSize > 0)
            #expect(result.sourceDuration > 0.5)
        }

        // MARK: - HLSEngine.transcodeVariants

        @Test(
            "Engine transcodeVariants produces multi-variant result",
            .timeLimit(.minutes(2))
        )
        func engineTranscodeVariants() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "engine-mv.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "engine-mv-out"
            )

            let engine = HLSEngine()
            let result = try await engine.transcodeVariants(
                input: sourceURL,
                outputDirectory: outputDir,
                variants: [.audioOnly],
                config: TranscodingConfig(
                    audioPassthrough: false
                )
            )

            #expect(!result.variants.isEmpty)
            #expect(result.masterPlaylist != nil)
            #expect(
                result.masterPlaylist?.contains("#EXTM3U")
                    == true
            )
        }

        // MARK: - AppleTranscoder.transcodeVariants

        @Test(
            "Multi-variant transcode with two audio presets",
            .timeLimit(.minutes(2))
        )
        func multiVariantAudio() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "mv-audio.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "mv-audio-out"
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

            let transcoder = AppleTranscoder()
            let result = try await transcoder.transcodeVariants(
                input: sourceURL,
                outputDirectory: outputDir,
                variants: [low, high],
                config: TranscodingConfig(
                    audioPassthrough: false
                ),
                progress: nil
            )

            #expect(result.variants.count == 2)
            #expect(result.masterPlaylist != nil)
            #expect(
                result.masterPlaylist?.contains("#EXTM3U")
                    == true
            )

            for variant in result.variants {
                #expect(variant.outputSize > 0)
                #expect(variant.sourceDuration > 0.5)
            }
        }

        // MARK: - Output Directory Creation

        @Test(
            "Transcode creates nested output directories",
            .timeLimit(.minutes(1))
        )
        func transcodeCreatesNestedDirs() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "nested-src.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let nestedDir =
                tempDir
                .appendingPathComponent("a")
                .appendingPathComponent("b")
                .appendingPathComponent("c")

            let transcoder = AppleTranscoder()
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
        }
    }

#endif
