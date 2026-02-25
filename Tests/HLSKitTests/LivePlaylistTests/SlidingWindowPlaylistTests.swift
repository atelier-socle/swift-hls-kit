// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SlidingWindowPlaylist", .timeLimit(.minutes(1)))
struct SlidingWindowPlaylistTests {

    // MARK: - Basic Operations

    @Test("Add segment renders in M3U8")
    func addSegment() async throws {
        let playlist = SlidingWindowPlaylist()
        let segment = LiveSegmentFactory.makeSegment()
        try await playlist.addSegment(segment)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("#EXTINF:6.0,"))
    }

    @Test("Add multiple segments → all present")
    func addMultiple() async throws {
        let playlist = SlidingWindowPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_1.m4s"))
        #expect(m3u8.contains("segment_2.m4s"))
    }

    // MARK: - Window Eviction

    @Test("Add beyond window → oldest evicted")
    func windowEviction() async throws {
        let config = SlidingWindowConfiguration(windowSize: 3)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()
        #expect(!m3u8.contains("segment_0.m4s"))
        #expect(!m3u8.contains("segment_1.m4s"))
        #expect(m3u8.contains("segment_2.m4s"))
        #expect(m3u8.contains("segment_3.m4s"))
        #expect(m3u8.contains("segment_4.m4s"))
    }

    @Test("MEDIA-SEQUENCE increments with eviction")
    func mediaSequenceIncrement() async throws {
        let config = SlidingWindowConfiguration(windowSize: 2)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 4)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let seq = await playlist.mediaSequence
        #expect(seq == 2)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-MEDIA-SEQUENCE:2"))
    }

    // MARK: - Target Duration

    @Test("TARGETDURATION = ceil of max segment duration")
    func targetDuration() async throws {
        let playlist = SlidingWindowPlaylist()
        let seg1 = LiveSegmentFactory.makeSegment(
            index: 0, duration: 5.5
        )
        let seg2 = LiveSegmentFactory.makeSegment(
            index: 1, duration: 6.006
        )
        try await playlist.addSegment(seg1)
        try await playlist.addSegment(seg2)
        let td = await playlist.targetDuration
        #expect(td == 7)  // ceil(6.006)
    }

    @Test("Empty playlist uses config targetDuration")
    func emptyTargetDuration() async {
        let config = SlidingWindowConfiguration(
            targetDuration: 4.0
        )
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let td = await playlist.targetDuration
        #expect(td == 4)
    }

    // MARK: - Playlist Type

    @Test("No PLAYLIST-TYPE tag (live)")
    func noPlaylistType() async throws {
        let playlist = SlidingWindowPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(!m3u8.contains("#EXT-X-PLAYLIST-TYPE"))
    }

    @Test("VERSION tag present")
    func versionPresent() async {
        let playlist = SlidingWindowPlaylist()
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-VERSION:7"))
    }

    // MARK: - Discontinuity

    @Test("insertDiscontinuity → DISCONTINUITY before next segment")
    func discontinuity() async throws {
        let playlist = SlidingWindowPlaylist()
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

    @Test("Discontinuity eviction → DISCONTINUITY-SEQUENCE")
    func discontinuityEviction() async throws {
        let config = SlidingWindowConfiguration(windowSize: 2)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 0)
        )
        await playlist.insertDiscontinuity()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 1)
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 2)
        )
        // Segment 0 evicted (no disc), segment 1 evicted (has disc)
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 3)
        )

        let discSeq = await playlist.discontinuitySequence
        #expect(discSeq == 1)
        let m3u8 = await playlist.renderPlaylist()
        #expect(
            m3u8.contains("#EXT-X-DISCONTINUITY-SEQUENCE:1")
        )
    }

    // MARK: - Eviction Verified via State

    @Test("Eviction updates mediaSequence and segmentCount")
    func evictionState() async throws {
        let config = SlidingWindowConfiguration(windowSize: 2)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let seq = await playlist.mediaSequence
        let count = await playlist.segmentCount
        #expect(seq == 3)
        #expect(count == 2)
        let m3u8 = await playlist.renderPlaylist()
        #expect(!m3u8.contains("segment_0.m4s"))
        #expect(!m3u8.contains("segment_1.m4s"))
        #expect(!m3u8.contains("segment_2.m4s"))
        #expect(m3u8.contains("segment_3.m4s"))
        #expect(m3u8.contains("segment_4.m4s"))
    }

    // MARK: - Accessors

    @Test("mediaSequence, discontinuitySequence, segmentCount")
    func accessors() async throws {
        let config = SlidingWindowConfiguration(windowSize: 3)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let seq = await playlist.mediaSequence
        let count = await playlist.segmentCount
        #expect(seq == 2)
        #expect(count == 3)
    }

    // MARK: - Empty and Single

    @Test("Empty playlist → valid M3U8 header only")
    func emptyPlaylist() async {
        let playlist = SlidingWindowPlaylist()
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(!m3u8.contains("#EXTINF:"))
    }

    @Test("Single segment → valid playlist")
    func singleSegment() async throws {
        let playlist = SlidingWindowPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXTINF:"))
        #expect(m3u8.contains("segment_0.m4s"))
    }

    // MARK: - Current Segments

    @Test("currentSegments returns windowed segments")
    func currentSegments() async throws {
        let config = SlidingWindowConfiguration(windowSize: 2)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 4)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let current = await playlist.currentSegments
        #expect(current.count == 2)
        #expect(current[0].index == 2)
        #expect(current[1].index == 3)
    }
}
