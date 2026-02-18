// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("AppleTranscoder — Integration")
    struct AppleTranscoderIntegrationTests {

        /// Temporary directory for each test.
        private let tempDir: URL

        init() {
            tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "hls-test-\(UUID().uuidString)"
                )
        }

        private func cleanup() {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // MARK: - SourceAnalyzer Integration (synthetic audio)

        @Test("Analyze synthetic audio file")
        func analyzeAudioFile() async throws {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            defer { cleanup() }

            let audioURL = tempDir.appendingPathComponent(
                "test.wav"
            )
            try SyntheticAudioHelper.createAudioFile(
                at: audioURL, duration: 1.0
            )

            let info = try await SourceAnalyzer.analyze(audioURL)

            #expect(info.hasAudio)
            #expect(!info.hasVideo)
            #expect(info.duration > 0.9)
            #expect(info.duration < 1.5)
            #expect(info.audioChannels == 1)
            #expect(info.videoResolution == nil)
            #expect(info.videoFrameRate == nil)
        }

        @Test("Analyze audio file reports sample rate")
        func analyzeAudioSampleRate() async throws {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            defer { cleanup() }

            let audioURL = tempDir.appendingPathComponent(
                "test-sr.wav"
            )
            try SyntheticAudioHelper.createAudioFile(
                at: audioURL,
                duration: 0.5,
                sampleRate: 44100
            )

            let info = try await SourceAnalyzer.analyze(audioURL)

            #expect(info.audioSampleRate == 44100)
        }

        @Test("Analyze audio file reports bitrate")
        func analyzeAudioBitrate() async throws {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            defer { cleanup() }

            let audioURL = tempDir.appendingPathComponent(
                "test-br.wav"
            )
            try SyntheticAudioHelper.createAudioFile(
                at: audioURL, duration: 1.0
            )

            let info = try await SourceAnalyzer.analyze(audioURL)

            #expect(info.audioBitrate != nil)
        }

        // MARK: - Error Paths

        @Test("Transcode to file path (not directory) fails")
        func transcodeOutputNotDirectory() async throws {
            try FileManager.default.createDirectory(
                at: tempDir,
                withIntermediateDirectories: true
            )
            defer { cleanup() }

            let audioURL = tempDir.appendingPathComponent(
                "err-src.wav"
            )
            try SyntheticAudioHelper.createAudioFile(
                at: audioURL, duration: 0.5
            )

            let fileAsDir = tempDir.appendingPathComponent(
                "not-a-dir.txt"
            )
            FileManager.default.createFile(
                atPath: fileAsDir.path,
                contents: Data("x".utf8)
            )

            let transcoder = AppleTranscoder()
            await #expect(throws: TranscodingError.self) {
                _ = try await transcoder.transcode(
                    input: audioURL,
                    outputDirectory: fileAsDir,
                    config: TranscodingConfig(),
                    progress: nil
                )
            }
        }

        // MARK: - Requires media fixtures
        // Full transcoding pipeline tests require real media files
        // or an AVFoundation transcoding session that completes.
        // These are disabled until proper media fixtures are available.
        //
        // Tests that would go here:
        // - Transcode audio-only file produces result
        // - Transcode audio-only with progress callback
        // - Transcode audio with passthrough mode
        // - HLSEngine transcode with synthetic audio
        // - HLSEngine transcodeVariants with synthetic audio
        // - prepareOutputDirectory creates nested directories
    }

#endif
