// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EventPlaylist", .timeLimit(.minutes(1)))
struct EventPlaylistTests {

    // MARK: - No Eviction

    @Test("Add segments → all retained, no eviction")
    func noEviction() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let count = await playlist.segmentCount
        #expect(count == 10)
        let m3u8 = await playlist.renderPlaylist()
        for i in 0..<10 {
            #expect(m3u8.contains("segment_\(i).m4s"))
        }
    }

    // MARK: - Playlist Type

    @Test("PLAYLIST-TYPE:EVENT present")
    func playlistType() async throws {
        let playlist = EventPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
    }

    // MARK: - Media Sequence

    @Test("MEDIA-SEQUENCE always 0 (no eviction)")
    func mediaSequence() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let seq = await playlist.mediaSequence
        #expect(seq == 0)
    }

    // MARK: - End Stream

    @Test("endStream → ENDLIST present (becomes VOD-like)")
    func endStream() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.endStream()
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
        #expect(m3u8.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
    }

    @Test("Add after endStream → throws streamEnded")
    func addAfterEnd() async throws {
        let playlist = EventPlaylist()
        _ = await playlist.endStream()
        await #expect(throws: LivePlaylistError.streamEnded) {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment()
            )
        }
    }

    // MARK: - Discontinuity

    @Test("insertDiscontinuity → DISCONTINUITY rendered")
    func discontinuity() async throws {
        let playlist = EventPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 0)
        )
        await playlist.insertDiscontinuity()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 1)
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-DISCONTINUITY"))
    }

    // MARK: - Extra Accessors

    @Test("totalDuration computed correctly")
    func totalDuration() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(
            count: 5, duration: 6.0
        )
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let total = await playlist.totalDuration
        #expect(abs(total - 30.0) < 0.001)
    }

    @Test("allSegments returns all in order")
    func allSegments() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let all = await playlist.allSegments
        #expect(all.count == 3)
        #expect(all[0].index == 0)
        #expect(all[1].index == 1)
        #expect(all[2].index == 2)
    }

    // MARK: - No Eviction Verified via State

    @Test("No eviction: segmentCount and mediaSequence stable")
    func noEvictionState() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let count = await playlist.segmentCount
        let seq = await playlist.mediaSequence
        #expect(count == 5)
        #expect(seq == 0)
    }

    // MARK: - Large Segment Count

    @Test("50 segments → valid playlist")
    func largeCount() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 50)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_49.m4s"))
        let count = await playlist.segmentCount
        #expect(count == 50)
    }

    // MARK: - Partial Segments

    @Test("addPartialSegment after end → throws")
    func partialAfterEnd() async throws {
        let playlist = EventPlaylist()
        _ = await playlist.endStream()
        let partial = LivePartialSegment(
            index: 0, data: Data(), duration: 0.5,
            isIndependent: true
        )
        await #expect(throws: LivePlaylistError.streamEnded) {
            try await playlist.addPartialSegment(
                partial, forSegment: 0
            )
        }
    }

    @Test("addPartialSegment with invalid parent → throws")
    func partialInvalidParent() async {
        let playlist = EventPlaylist()
        let partial = LivePartialSegment(
            index: 0, data: Data(), duration: 0.5,
            isIndependent: true
        )
        await #expect(
            throws: LivePlaylistError.parentSegmentNotFound(99)
        ) {
            try await playlist.addPartialSegment(
                partial, forSegment: 99
            )
        }
    }

    // MARK: - Metadata

    @Test("updateMetadata applies to rendered output")
    func metadata() async throws {
        let playlist = EventPlaylist()
        await playlist.updateMetadata(
            LivePlaylistMetadata(independentSegments: true)
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }

    // MARK: - Discontinuity Sequence

    @Test("discontinuitySequence accessible")
    func discSeq() async {
        let playlist = EventPlaylist()
        let seq = await playlist.discontinuitySequence
        #expect(seq == 0)
    }
}
