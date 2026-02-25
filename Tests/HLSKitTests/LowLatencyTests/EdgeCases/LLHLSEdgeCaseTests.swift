// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LL-HLS Edge Cases", .timeLimit(.minutes(1)))
struct LLHLSEdgeCaseTests {

    @Test("Empty playlist: no partials added yet")
    func emptyPlaylist() async {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let m3u8 = await manager.renderPlaylist()

        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXT-X-PART-INF:"))
        // No PART tags, but should have preload hint
        #expect(!m3u8.contains("#EXT-X-PART:"))
        #expect(m3u8.contains("#EXT-X-PRELOAD-HINT:"))
    }

    @Test("Single partial, no completed segments")
    func singlePartial() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33334, isIndependent: true
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-PART:"))
        #expect(!m3u8.contains("#EXTINF:"))
        #expect(m3u8.contains("#EXT-X-PRELOAD-HINT:"))
    }

    @Test("Max partials per segment reached")
    func maxPartialsReached() async throws {
        let config = LLHLSConfiguration(
            maxPartialsPerSegment: 3
        )
        let manager = LLHLSManager(configuration: config)

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        try await manager.addPartial(
            duration: 0.34, isIndependent: false
        )

        let count = await manager.currentPartialCount
        #expect(count == 3)

        // Preload hint should point to next segment's first partial
        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("seg1.0.mp4"))
    }

    @Test("Very short partial duration (0.001s)")
    func veryShortDuration() async throws {
        let manager = LLHLSManager(
            configuration: .ultraLowLatency
        )
        let partial = try await manager.addPartial(
            duration: 0.001, isIndependent: true
        )

        #expect(partial.duration == 0.001)
        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("DURATION=0.00100"))
    }

    @Test("GAP partial renders correctly")
    func gapPartial() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true, isGap: true
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("GAP=YES"))
    }

    // MARK: - Metadata & Program Date Time

    @Test("updateMetadata adds INDEPENDENT-SEGMENTS")
    func updateMetadata() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        await manager.updateMetadata(
            LivePlaylistMetadata(independentSegments: true)
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }

    @Test("programDateTime renders in playlist")
    func programDateTime() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s",
            programDateTime: date
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    @Test("Discontinuity sequence in header after eviction")
    func discontinuitySequence() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )

        // Segment 0
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        // Segment 1 with discontinuity
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg1.m4s",
            hasDiscontinuity: true
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-DISCONTINUITY"))
    }

    @Test("Byte range partial in manager")
    func byteRangePartial() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let partial = try await manager.addPartial(
            duration: 0.33,
            isIndependent: true,
            byteRange: ByteRange(length: 2048, offset: 0)
        )

        #expect(partial.byteRange?.length == 2048)
        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("BYTERANGE=\"2048@0\""))
    }

    @Test("totalPartialCount across segments")
    func totalPartialCountCoverage() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let total = await manager.totalPartialCount
        #expect(total == 3)
    }
}
