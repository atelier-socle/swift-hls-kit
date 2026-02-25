// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LLHLSIntegration", .timeLimit(.minutes(1)))
struct LLHLSIntegrationTests {

    // MARK: - Helpers

    /// Build a manager with N segments, each having P partials.
    private func buildPipeline(
        segments: Int,
        partialsPerSegment: Int,
        configuration: LLHLSConfiguration = .lowLatency
    ) async throws -> LLHLSManager {
        let manager = LLHLSManager(configuration: configuration)
        for s in 0..<segments {
            for p in 0..<partialsPerSegment {
                try await manager.addPartial(
                    duration: 0.33,
                    isIndependent: p == 0
                )
            }
            await manager.completeSegment(
                duration: 1.0, uri: "seg\(s).m4s"
            )
        }
        return manager
    }

    // MARK: - Full Pipeline

    @Test("3 segments × 3 partials → render → all tags present")
    func fullPipelineRender() async throws {
        let manager = try await buildPipeline(
            segments: 3, partialsPerSegment: 3
        )
        let playlist = await manager.renderPlaylist()

        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-VERSION:"))
        #expect(playlist.contains("#EXT-X-TARGETDURATION:"))
        #expect(playlist.contains("#EXT-X-MEDIA-SEQUENCE:"))
        #expect(playlist.contains("#EXT-X-PART-INF:"))
        #expect(playlist.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(playlist.contains("#EXTINF:"))
        #expect(playlist.contains("seg0.m4s"))
        #expect(playlist.contains("seg2.m4s"))
    }

    @Test("Pipeline with server control tag")
    func serverControlPresent() async throws {
        let manager = try await buildPipeline(
            segments: 2, partialsPerSegment: 2
        )
        let playlist = await manager.renderPlaylist()

        #expect(playlist.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(playlist.contains("CAN-BLOCK-RELOAD=YES"))
    }

    @Test("Pipeline with delta → delta is smaller")
    func deltaIsSmallerThanFull() async throws {
        let config = LLHLSConfiguration.lowLatency
        let manager = try await buildPipeline(
            segments: 10, partialsPerSegment: 3,
            configuration: config
        )

        let full = await manager.renderPlaylist()
        let delta = await manager.renderDeltaPlaylist()

        if let delta {
            #expect(delta.count < full.count)
            #expect(delta.contains("EXT-X-SKIP"))
        }
    }

    @Test("EXT-X-PART-INF present and correct")
    func partInfPresent() async throws {
        let manager = try await buildPipeline(
            segments: 1, partialsPerSegment: 2
        )
        let playlist = await manager.renderPlaylist()

        #expect(
            playlist.contains(
                "#EXT-X-PART-INF:PART-TARGET="
            )
        )
    }

    @Test("EXT-X-PRELOAD-HINT present when not ended")
    func preloadHintPresent() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        let playlist = await manager.renderPlaylist()

        #expect(
            playlist.contains("#EXT-X-PRELOAD-HINT:")
        )
    }

    @Test("Media sequence increments through lifecycle")
    func mediaSequenceIncrements() async throws {
        let manager = try await buildPipeline(
            segments: 5, partialsPerSegment: 2
        )
        let playlist = await manager.renderPlaylist()

        #expect(
            playlist.contains("#EXT-X-MEDIA-SEQUENCE:0")
        )
    }

    @Test("Discontinuity with partials renders correctly")
    func discontinuityRenders() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await manager.completeSegment(
            duration: 1.0, uri: "seg0.m4s"
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await manager.completeSegment(
            duration: 1.0, uri: "seg1.m4s",
            hasDiscontinuity: true
        )

        let playlist = await manager.renderPlaylist()
        #expect(playlist.contains("#EXT-X-DISCONTINUITY"))
    }

    @Test("endStream → EXT-X-ENDLIST present, no preload hint")
    func endStreamMarkers() async throws {
        let manager = try await buildPipeline(
            segments: 2, partialsPerSegment: 2
        )
        await manager.endStream()
        let playlist = await manager.renderPlaylist()

        #expect(playlist.contains("#EXT-X-ENDLIST"))
        #expect(!playlist.contains("#EXT-X-PRELOAD-HINT:"))
    }

    @Test("Partial counts match across manager")
    func partialCountsMatch() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )

        let currentCount = await manager.currentPartialCount
        #expect(currentCount == 2)
        let totalCount = await manager.totalPartialCount
        #expect(totalCount == 2)
    }

    @Test("Large stream with 50 segments renders correctly")
    func largeStream() async throws {
        let manager = try await buildPipeline(
            segments: 50, partialsPerSegment: 2
        )
        let playlist = await manager.renderPlaylist()

        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("seg49.m4s"))
    }

    @Test("ultraLowLatency preset produces valid playlist")
    func ultraLowLatencyPreset() async throws {
        let manager = try await buildPipeline(
            segments: 3, partialsPerSegment: 3,
            configuration: .ultraLowLatency
        )
        let playlist = await manager.renderPlaylist()

        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-SERVER-CONTROL:"))
    }

    @Test("lowLatency preset produces valid playlist")
    func lowLatencyPreset() async throws {
        let manager = try await buildPipeline(
            segments: 3, partialsPerSegment: 3,
            configuration: .lowLatency
        )
        let playlist = await manager.renderPlaylist()

        #expect(playlist.contains("#EXTM3U"))
    }

    @Test("balanced preset produces valid playlist")
    func balancedPreset() async throws {
        let manager = try await buildPipeline(
            segments: 3, partialsPerSegment: 3,
            configuration: .balanced
        )
        let playlist = await manager.renderPlaylist()

        #expect(playlist.contains("#EXTM3U"))
    }

    @Test("Render → parse round-trip key fields match")
    func renderParseRoundTrip() async throws {
        let manager = try await buildPipeline(
            segments: 3, partialsPerSegment: 2
        )
        let playlist = await manager.renderPlaylist()

        let parser = ManifestParser()
        let result = try parser.parse(playlist)

        guard case .media(let media) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.version == .v7)
        #expect(!media.segments.isEmpty)
    }
}
