// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LL-HLS Showcase", .timeLimit(.minutes(1)))
struct LLHLSShowcaseTests {

    // MARK: - Scenarios

    @Test("Ultra-low-latency live stream (0.2s parts, 10 segments)")
    func ultraLowLatencyStream() async throws {
        let manager = LLHLSManager(
            configuration: .ultraLowLatency
        )

        for seg in 0..<10 {
            // 5 partials of 0.2s per segment (1s total)
            for part in 0..<5 {
                try await manager.addPartial(
                    duration: 0.2, isIndependent: part == 0
                )
            }
            _ = await manager.completeSegment(
                duration: 1.0, uri: "seg\(seg).m4s"
            )
        }

        let m3u8 = await manager.renderPlaylist()
        let segCount = await manager.segmentCount
        #expect(segCount == 10)
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXT-X-PART-INF:PART-TARGET=0.20000"))
        #expect(m3u8.contains("#EXT-X-PRELOAD-HINT:"))
        #expect(!m3u8.contains("#EXT-X-ENDLIST"))
    }

    @Test("Sports broadcast: IDR on every partial")
    func sportsBroadcast() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )

        for seg in 0..<5 {
            for _ in 0..<6 {
                try await manager.addPartial(
                    duration: 0.33334, isIndependent: true
                )
            }
            _ = await manager.completeSegment(
                duration: 2.0, uri: "seg\(seg).m4s"
            )
        }

        let m3u8 = await manager.renderPlaylist()
        // Count INDEPENDENT=YES occurrences in retained segments
        let independentCount =
            m3u8.components(
                separatedBy: "INDEPENDENT=YES"
            ).count - 1
        // At least some INDEPENDENT=YES should be present
        #expect(independentCount > 0)
    }

    @Test("Podcast live with relaxed latency (0.5s parts)")
    func podcastLive() async throws {
        let manager = LLHLSManager(
            configuration: .balanced
        )

        for seg in 0..<3 {
            for part in 0..<8 {
                try await manager.addPartial(
                    duration: 0.5, isIndependent: part == 0
                )
            }
            _ = await manager.completeSegment(
                duration: 4.0, uri: "seg\(seg).m4s"
            )
        }

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-PART-INF:PART-TARGET=0.50000"))
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:4"))
        let segCount = await manager.segmentCount
        #expect(segCount == 3)
    }

    @Test("Transition: LL-HLS to ended stream")
    func llhlsToEnded() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )

        // Add some live content
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        // End stream
        await manager.endStream()

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
        #expect(!m3u8.contains("#EXT-X-PRELOAD-HINT:"))
    }

    @Test("Multi-segment lifecycle with eviction")
    func multiSegmentEviction() async throws {
        let config = LLHLSConfiguration(
            partTargetDuration: 0.33334,
            maxPartialsPerSegment: 3,
            segmentTargetDuration: 1.0,
            retainedPartialSegments: 2
        )
        let manager = LLHLSManager(configuration: config)

        // Build 5 segments with 3 partials each
        for seg in 0..<5 {
            for part in 0..<3 {
                try await manager.addPartial(
                    duration: 0.33334, isIndependent: part == 0
                )
            }
            _ = await manager.completeSegment(
                duration: 1.0, uri: "seg\(seg).m4s"
            )
        }

        let total = await manager.totalPartialCount
        // Only 2 retained segments' partials (2 × 3 = 6)
        #expect(total == 6)

        let m3u8 = await manager.renderPlaylist()
        // All 5 segments should be in the playlist (as EXTINF)
        #expect(m3u8.contains("seg0.m4s"))
        #expect(m3u8.contains("seg4.m4s"))

        // But only retained segments have EXT-X-PART tags
        // Segments 3 and 4 are retained
        let segCount = await manager.segmentCount
        #expect(segCount == 5)
    }
}
