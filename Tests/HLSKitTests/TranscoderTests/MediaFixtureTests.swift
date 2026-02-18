// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("MediaFixtureGenerator")
    struct MediaFixtureTests {

        init() throws {
            try MediaFixtureGenerator.setUp()
        }

        // MARK: - Audio Fixture

        @Test(
            "Create audio fixture produces valid M4A",
            .timeLimit(.minutes(1))
        )
        func createAudioFixture() async throws {
            let url = MediaFixtureGenerator.fixtureDirectory
                .appendingPathComponent("test-audio.m4a")
            try await MediaFixtureGenerator.createAudioFixture(
                at: url
            )
            let attrs = try FileManager.default
                .attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? UInt64 ?? 0
            #expect(size > 0)
            try? FileManager.default.removeItem(at: url)
        }

        @Test(
            "Audio fixture is analyzable",
            .timeLimit(.minutes(1))
        )
        func audioFixtureAnalyzable() async throws {
            let url = MediaFixtureGenerator.fixtureDirectory
                .appendingPathComponent("test-analyze.m4a")
            try await MediaFixtureGenerator.createAudioFixture(
                at: url
            )
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            let info = try await SourceAnalyzer.analyze(url)
            #expect(info.hasAudio)
            #expect(!info.hasVideo)
            #expect(info.duration > 0.5)
            #expect(info.audioChannels == 1)
        }

        // MARK: - Video Fixture

        @Test(
            "Create video fixture produces valid MP4",
            .timeLimit(.minutes(1))
        )
        func createVideoFixture() async throws {
            let url = MediaFixtureGenerator.fixtureDirectory
                .appendingPathComponent("test-video.mp4")
            try await MediaFixtureGenerator.createVideoFixture(
                at: url
            )
            let attrs = try FileManager.default
                .attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? UInt64 ?? 0
            #expect(size > 0)
            try? FileManager.default.removeItem(at: url)
        }

        @Test(
            "Video fixture is analyzable",
            .timeLimit(.minutes(1))
        )
        func videoFixtureAnalyzable() async throws {
            let url = MediaFixtureGenerator.fixtureDirectory
                .appendingPathComponent("test-vanalyze.mp4")
            try await MediaFixtureGenerator.createVideoFixture(
                at: url
            )
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            let info = try await SourceAnalyzer.analyze(url)
            #expect(info.hasVideo)
            #expect(info.hasAudio)
            #expect(info.duration > 0.5)
            #expect(info.videoResolution != nil)
        }

        // MARK: - Video-Only Fixture

        @Test(
            "Create video-only fixture",
            .timeLimit(.minutes(1))
        )
        func createVideoOnlyFixture() async throws {
            let url = MediaFixtureGenerator.fixtureDirectory
                .appendingPathComponent("test-vidonly.mp4")
            try await MediaFixtureGenerator.createVideoOnlyFixture(
                at: url
            )
            let attrs = try FileManager.default
                .attributesOfItem(atPath: url.path)
            let size = attrs[.size] as? UInt64 ?? 0
            #expect(size > 0)
            try? FileManager.default.removeItem(at: url)
        }

        @Test(
            "Video-only fixture has no audio",
            .timeLimit(.minutes(1))
        )
        func videoOnlyNoAudio() async throws {
            let url = MediaFixtureGenerator.fixtureDirectory
                .appendingPathComponent("test-voanalyze.mp4")
            try await MediaFixtureGenerator.createVideoOnlyFixture(
                at: url
            )
            defer {
                try? FileManager.default.removeItem(at: url)
            }

            let info = try await SourceAnalyzer.analyze(url)
            #expect(info.hasVideo)
            #expect(!info.hasAudio)
        }
    }

#endif
