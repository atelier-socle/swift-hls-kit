// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LLHLSManager Delta", .timeLimit(.minutes(1)))
struct LLHLSManagerDeltaTests {

    // MARK: - Helpers

    private func buildManager(
        segmentCount: Int,
        config: LLHLSConfiguration = .lowLatency
    ) async throws -> LLHLSManager {
        let manager = LLHLSManager(configuration: config)
        for seg in 0..<segmentCount {
            try await manager.addPartial(
                duration: 0.33, isIndependent: true
            )
            try await manager.addPartial(
                duration: 0.33, isIndependent: false
            )
            _ = await manager.completeSegment(
                duration: 2.0, uri: "seg\(seg).m4s"
            )
        }
        return manager
    }

    // MARK: - Server Control in Playlist

    @Test("renderPlaylist includes EXT-X-SERVER-CONTROL")
    func playlistHasServerControl() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(m3u8.contains("CAN-BLOCK-RELOAD=YES"))
    }

    // MARK: - Delta Updates

    @Test("renderDeltaPlaylist returns nil when delta not configured")
    func deltaNotConfigured() async throws {
        let config = LLHLSConfiguration(
            serverControl: .standard(
                targetDuration: 2.0, partTargetDuration: 0.33334
            )
        )
        let manager = try await buildManager(
            segmentCount: 5, config: config
        )
        let delta = await manager.renderDeltaPlaylist()
        #expect(delta == nil)
    }

    @Test("renderDeltaPlaylist returns nil when no segments skippable")
    func deltaNoSkippable() async throws {
        let manager = try await buildManager(segmentCount: 2)
        let delta = await manager.renderDeltaPlaylist()
        #expect(delta == nil)
    }

    @Test("renderDeltaPlaylist returns delta with skippable segments")
    func deltaWithSkippable() async throws {
        let manager = try await buildManager(segmentCount: 10)
        let delta = await manager.renderDeltaPlaylist()
        #expect(delta != nil)
        if let delta {
            #expect(delta.contains("#EXT-X-SKIP:"))
        }
    }

    @Test("Delta playlist contains correct SKIPPED-SEGMENTS count")
    func deltaSkipCount() async throws {
        let manager = try await buildManager(segmentCount: 10)
        let delta = await manager.renderDeltaPlaylist()
        #expect(delta != nil)
        if let delta {
            #expect(delta.contains("SKIPPED-SEGMENTS="))
        }
    }

    @Test("Delta playlist contains recent segments with partials")
    func deltaRecentSegments() async throws {
        let manager = try await buildManager(segmentCount: 10)
        let delta = await manager.renderDeltaPlaylist()
        #expect(delta != nil)
        if let delta {
            #expect(delta.contains("seg9.m4s"))
        }
    }

    @Test("Delta playlist contains preload hint")
    func deltaPreloadHint() async throws {
        let manager = try await buildManager(segmentCount: 10)
        // Add a partial to have a preload hint
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let delta = await manager.renderDeltaPlaylist()
        #expect(delta != nil)
        if let delta {
            #expect(delta.contains("#EXT-X-PRELOAD-HINT:"))
        }
    }

    @Test("renderDeltaPlaylist with v2 skip request")
    func deltaV2() async throws {
        let manager = try await buildManager(segmentCount: 10)
        let delta = await manager.renderDeltaPlaylist(
            skipRequest: .v2
        )
        #expect(delta != nil)
    }

    @Test("Server control holdback values in rendered playlist")
    func serverControlHoldbacks() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("HOLD-BACK="))
        #expect(m3u8.contains("PART-HOLD-BACK="))
    }

    @Test("Full lifecycle: add segments → render full → render delta")
    func fullLifecycle() async throws {
        let manager = try await buildManager(segmentCount: 10)

        let full = await manager.renderPlaylist()
        let delta = await manager.renderDeltaPlaylist()

        #expect(full.contains("#EXTM3U"))
        #expect(delta != nil)
        if let delta {
            #expect(delta.contains("#EXTM3U"))
            #expect(delta.contains("#EXT-X-SKIP:"))
        }
    }

    @Test("Delta reduces playlist size vs full playlist")
    func deltaSmallerThanFull() async throws {
        let manager = try await buildManager(segmentCount: 10)
        let full = await manager.renderPlaylist()
        let delta = await manager.renderDeltaPlaylist()

        #expect(delta != nil)
        if let delta {
            #expect(delta.count < full.count)
        }
    }

    @Test("Configuration presets include server control")
    func presetsHaveServerControl() {
        #expect(LLHLSConfiguration.lowLatency.serverControl != nil)
        #expect(
            LLHLSConfiguration.ultraLowLatency.serverControl != nil
        )
        #expect(LLHLSConfiguration.balanced.serverControl != nil)
    }

    @Test("Server control property accessible on manager")
    func serverControlAccessible() async {
        let manager = LLHLSManager(configuration: .lowLatency)
        let sc = await manager.serverControl
        #expect(sc.canBlockReload == true)
    }
}
