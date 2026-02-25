// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LLHLSManager", .timeLimit(.minutes(1)))
struct LLHLSManagerTests {

    // MARK: - Initialization

    @Test("Initialize with configuration")
    func initWithConfig() async {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let count = await manager.segmentCount
        #expect(count == 0)
        let ended = await manager.isEnded
        #expect(ended == false)
    }

    // MARK: - Add Partial

    @Test("Add partial updates state")
    func addPartial() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let partial = try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        #expect(partial.segmentIndex == 0)
        #expect(partial.partialIndex == 0)
        let count = await manager.currentPartialCount
        #expect(count == 1)
    }

    @Test("Add multiple partials increments count")
    func addMultiplePartials() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
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
    }

    // MARK: - Complete Segment

    @Test("Complete segment returns LiveSegment")
    func completeSegment() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )

        let seg = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        #expect(seg.index == 0)
        #expect(seg.duration == 2.0)
        #expect(seg.filename == "seg0.m4s")
        let segCount = await manager.segmentCount
        #expect(segCount == 1)
    }

    @Test("Complete multiple segments advances index")
    func completeMultiple() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )

        for i in 0..<3 {
            try await manager.addPartial(
                duration: 0.33, isIndependent: true
            )
            let seg = await manager.completeSegment(
                duration: 2.0, uri: "seg\(i).m4s"
            )
            #expect(seg.index == i)
        }

        let count = await manager.segmentCount
        #expect(count == 3)
    }

    // MARK: - Render Playlist

    @Test("Playlist contains EXT-X-PART-INF")
    func playlistPartInf() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-PART-INF:PART-TARGET="))
    }

    @Test("Playlist contains EXT-X-PART tags")
    func playlistPartTags() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )

        let m3u8 = await manager.renderPlaylist()
        let partCount =
            m3u8.components(
                separatedBy: "#EXT-X-PART:"
            ).count - 1
        #expect(partCount == 2)
    }

    @Test("Playlist contains EXT-X-PRELOAD-HINT")
    func playlistPreloadHint() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-PRELOAD-HINT:TYPE=PART"))
    }

    @Test("Playlist with completed + in-progress segments")
    func playlistCompletedAndInProgress() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )

        // Complete segment 0
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        // Start segment 1 (in progress)
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let m3u8 = await manager.renderPlaylist()

        // Should have segment 0 EXTINF + current partial
        #expect(m3u8.contains("seg0.m4s"))
        #expect(m3u8.contains("#EXTINF:"))
        #expect(m3u8.contains("#EXT-X-PART:"))
        #expect(m3u8.contains("#EXT-X-PRELOAD-HINT:"))
    }

    @Test("Playlist has correct header")
    func playlistHeader() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(m3u8.contains("#EXT-X-VERSION:7"))
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:"))
        #expect(m3u8.contains("#EXT-X-MEDIA-SEQUENCE:0"))
    }

    // MARK: - Discontinuity

    @Test("Discontinuity tag in playlist")
    func discontinuity() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

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

    // MARK: - End Stream

    @Test("endStream adds EXT-X-ENDLIST")
    func endStream() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )

        await manager.endStream()

        let m3u8 = await manager.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
        let ended = await manager.isEnded
        #expect(ended == true)
    }

    @Test("No preload hint after endStream")
    func noPreloadAfterEnd() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.m4s"
        )
        await manager.endStream()

        let m3u8 = await manager.renderPlaylist()
        #expect(!m3u8.contains("#EXT-X-PRELOAD-HINT:"))
    }

    @Test("Add partial after endStream throws")
    func addAfterEnd() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        await manager.endStream()

        await #expect(throws: LLHLSError.streamAlreadyEnded) {
            try await manager.addPartial(
                duration: 0.33, isIndependent: true
            )
        }
    }

    // MARK: - URI Generation

    @Test("Auto-generated URI from template")
    func autoGeneratedURI() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let partial = try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        #expect(partial.uri == "seg0.0.mp4")
    }

    @Test("Custom URI overrides template")
    func customURI() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let partial = try await manager.addPartial(
            duration: 0.33,
            uri: "custom-part.mp4",
            isIndependent: true
        )

        #expect(partial.uri == "custom-part.mp4")
    }

    // MARK: - Tag Ordering

    @Test("PART-INF before PARTs in playlist")
    func tagOrdering() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let m3u8 = await manager.renderPlaylist()
        let partInfRange = m3u8.range(of: "#EXT-X-PART-INF:")
        let partRange = m3u8.range(of: "#EXT-X-PART:")
        let hintRange = m3u8.range(of: "#EXT-X-PRELOAD-HINT:")

        if let pi = partInfRange, let p = partRange {
            #expect(pi.lowerBound < p.lowerBound)
        }
        if let p = partRange, let h = hintRange {
            #expect(p.lowerBound < h.lowerBound)
        }
    }
}
