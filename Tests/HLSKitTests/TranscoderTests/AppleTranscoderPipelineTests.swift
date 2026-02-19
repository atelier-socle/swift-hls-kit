// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import Foundation
    import Testing
    #if canImport(os)
        import os
    #endif

    @testable import HLSKit

    @Suite("AppleTranscoder — Pipeline")
    struct AppleTranscoderPipelineTests {

        private let tempDir: URL

        init() throws {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "hls-pipeline-\(UUID().uuidString)"
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

        @Test(
            "Transcode M4A audio file",
            .timeLimit(.minutes(1))
        )
        func transcodeAudio() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "source.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "audio-out"
            )

            let transcoder = AppleTranscoder()
            let config = TranscodingConfig(
                audioPassthrough: false
            )
            let result = try await transcoder.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: config,
                progress: nil
            )

            #expect(result.sourceDuration > 0.5)
            #expect(result.transcodingDuration > 0)
            #expect(result.outputSize > 0)
            #expect(result.preset.isAudioOnly)
        }

        // MARK: - Video Transcoding

        @Test(
            "Transcode MP4 video+audio file",
            .timeLimit(.minutes(2))
        )
        func transcodeVideo() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "source.mp4"
            )
            try await MediaFixtureGenerator.createVideoFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "video-out"
            )

            let transcoder = AppleTranscoder()
            let config = TranscodingConfig(
                audioPassthrough: false
            )
            let result = try await transcoder.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: config,
                progress: nil
            )

            #expect(result.sourceDuration > 0.5)
            #expect(result.transcodingDuration > 0)
            #expect(result.outputSize > 0)
        }

        // MARK: - Progress Reporting

        @Test(
            "Transcode reports progress via callback",
            .timeLimit(.minutes(2))
        )
        func transcodeReportsProgress() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "progress-source.mp4"
            )
            try await MediaFixtureGenerator.createVideoFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "progress-out"
            )

            let collected = OSAllocatedUnfairLock(
                initialState: [Double]()
            )

            let transcoder = AppleTranscoder()
            let config = TranscodingConfig(
                audioPassthrough: false
            )
            let result = try await transcoder.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: config,
                progress: { value in
                    collected.withLock { $0.append(value) }
                }
            )

            #expect(result.outputSize > 0)

            let values = collected.withLock { $0 }
            #expect(!values.isEmpty)
            for value in values {
                #expect(value >= 0.0)
                #expect(value <= 1.0)
            }
        }

        // MARK: - Video-Only Source

        @Test(
            "Transcode video-only source (no audio track)",
            .timeLimit(.minutes(1))
        )
        func transcodeVideoOnly() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "vidonly-source.mp4"
            )
            try await MediaFixtureGenerator.createVideoOnlyFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "vidonly-out"
            )

            let transcoder = AppleTranscoder()
            let result = try await transcoder.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: TranscodingConfig(),
                progress: nil
            )

            #expect(result.outputSize > 0)
            #expect(result.sourceDuration > 0.5)
        }

        // MARK: - Segmentation

        @Test(
            "Transcode video produces segmented output",
            .timeLimit(.minutes(2))
        )
        func transcodeProducesSegments() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "seg-source.mp4"
            )
            try await MediaFixtureGenerator.createVideoFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "seg-out"
            )

            let transcoder = AppleTranscoder()
            let config = TranscodingConfig(
                generatePlaylist: true,
                audioPassthrough: false
            )
            let result = try await transcoder.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: config,
                progress: nil
            )

            #expect(result.segmentation != nil)
        }

        // MARK: - MPEG-TS Container

        @Test(
            "Transcode with MPEG-TS container format",
            .timeLimit(.minutes(1))
        )
        func transcodeMPEGTS() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "ts-source.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "ts-out"
            )

            let transcoder = AppleTranscoder()
            let config = TranscodingConfig(
                containerFormat: .mpegTS,
                audioPassthrough: false
            )
            let result = try await transcoder.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: config,
                progress: nil
            )

            #expect(result.outputSize > 0)
            #expect(result.segmentation != nil)
        }

        // MARK: - Audio-Only HLS Segments

        @Test(
            "Audio-only M4A produces audio-only HLS segments",
            .timeLimit(.minutes(1))
        )
        func transcodeAudioOnlySegments() async throws {
            defer { cleanup() }

            let sourceURL = tempDir.appendingPathComponent(
                "ao-source.m4a"
            )
            try await MediaFixtureGenerator.createAudioFixture(
                at: sourceURL
            )

            let outputDir = tempDir.appendingPathComponent(
                "ao-out"
            )

            let transcoder = AppleTranscoder()
            let config = TranscodingConfig(
                containerFormat: .mpegTS,
                generatePlaylist: true,
                audioPassthrough: false
            )
            let result = try await transcoder.transcode(
                input: sourceURL,
                outputDirectory: outputDir,
                config: config,
                progress: nil
            )

            // Preset is audio-only
            #expect(result.preset.isAudioOnly)
            #expect(result.preset.resolution == nil)
            #expect(result.preset.videoBitrate == nil)

            // Source had no video
            let sourceInfo =
                try await SourceAnalyzer.analyze(sourceURL)
            #expect(sourceInfo.hasAudio)
            #expect(!sourceInfo.hasVideo)
            #expect(sourceInfo.videoResolution == nil)

            // Segmentation produced audio-only segments
            let seg = result.segmentation
            #expect(seg != nil)
            #expect(seg?.fileInfo.videoTrack == nil)
            #expect(seg?.fileInfo.audioTrack != nil)
            #expect((seg?.segmentCount ?? 0) > 0)

            // Playlist was generated
            #expect(seg?.playlist != nil)
            #expect(
                seg?.playlist?.contains("#EXTM3U") == true
            )
        }
    }

#endif
