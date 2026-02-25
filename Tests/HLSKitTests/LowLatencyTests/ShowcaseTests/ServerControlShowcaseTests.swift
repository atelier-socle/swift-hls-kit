// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Server Control Showcase", .timeLimit(.minutes(1)))
struct ServerControlShowcaseTests {

    // MARK: - Helpers

    private func buildManager(
        config: LLHLSConfiguration,
        segmentCount: Int
    ) async throws -> LLHLSManager {
        let manager = LLHLSManager(configuration: config)
        for seg in 0..<segmentCount {
            for part in 0..<3 {
                try await manager.addPartial(
                    duration: 0.33, isIndependent: part == 0
                )
            }
            _ = await manager.completeSegment(
                duration: 2.0, uri: "seg\(seg).m4s"
            )
        }
        return manager
    }

    // MARK: - Showcase Scenarios

    @Test("Ultra-low-latency sports stream: server control + delta")
    func ultraLowLatencySports() async throws {
        let manager = try await buildManager(
            config: .ultraLowLatency,
            segmentCount: 15
        )

        let full = await manager.renderPlaylist()
        #expect(full.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(full.contains("CAN-BLOCK-RELOAD=YES"))
        #expect(full.contains("CAN-SKIP-UNTIL="))

        let delta = await manager.renderDeltaPlaylist()
        #expect(delta != nil)
        if let delta {
            #expect(delta.contains("#EXT-X-SKIP:"))
            #expect(delta.count < full.count)
        }
    }

    @Test("Standard live podcast: basic server control, no delta")
    func standardPodcast() async throws {
        let config = LLHLSConfiguration(
            partTargetDuration: 0.5,
            segmentTargetDuration: 4.0,
            serverControl: .standard(
                targetDuration: 4.0, partTargetDuration: 0.5
            )
        )
        let manager = try await buildManager(
            config: config, segmentCount: 5
        )

        let full = await manager.renderPlaylist()
        #expect(full.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(full.contains("CAN-BLOCK-RELOAD=YES"))
        #expect(!full.contains("CAN-SKIP-UNTIL"))

        let delta = await manager.renderDeltaPlaylist()
        #expect(delta == nil)
    }

    @Test("Large-audience stream: aggressive delta for bandwidth")
    func largeAudienceDelta() async throws {
        let config = LLHLSConfiguration(
            partTargetDuration: 0.33334,
            segmentTargetDuration: 2.0,
            serverControl: .withDeltaUpdates(
                targetDuration: 2.0, partTargetDuration: 0.33334
            )
        )
        let manager = try await buildManager(
            config: config, segmentCount: 20
        )

        let full = await manager.renderPlaylist()
        let delta = await manager.renderDeltaPlaylist()

        #expect(delta != nil)
        if let delta {
            let savings = full.count - delta.count
            #expect(savings > 0)
        }
    }

    @Test("Server control evolution: start without delta, enable later")
    func serverControlEvolution() async throws {
        // Phase 1: no delta
        let config1 = LLHLSConfiguration(
            serverControl: .standard(
                targetDuration: 2.0, partTargetDuration: 0.33334
            )
        )
        let manager1 = try await buildManager(
            config: config1, segmentCount: 5
        )
        let delta1 = await manager1.renderDeltaPlaylist()
        #expect(delta1 == nil)

        // Phase 2: with delta
        let config2 = LLHLSConfiguration(
            serverControl: .withDeltaUpdates(
                targetDuration: 2.0, partTargetDuration: 0.33334
            )
        )
        let manager2 = try await buildManager(
            config: config2, segmentCount: 10
        )
        let delta2 = await manager2.renderDeltaPlaylist()
        #expect(delta2 != nil)
    }
}
