// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "LivePlaylist — Integration",
    .timeLimit(.minutes(1))
)
struct LivePlaylistIntegrationTests {

    // MARK: - Sliding Window → M3U8 → Parse

    @Test("Sliding window → valid M3U8 → round-trip parse")
    func slidingWindowRoundTrip() async throws {
        let config = SlidingWindowConfiguration(windowSize: 3)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(
            count: 5, duration: 6.006
        )
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()

        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(parsed.segments.count == 3)
        #expect(parsed.mediaSequence == 2)
        #expect(parsed.targetDuration == 7)  // ceil(6.006)
        #expect(parsed.playlistType == nil)
        #expect(parsed.hasEndList == false)
        #expect(
            parsed.segments[0].uri == "segment_2.m4s"
        )
    }

    // MARK: - Event Playlist → M3U8 → Parse

    @Test("Event → M3U8 → round-trip parse")
    func eventRoundTrip() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(
            count: 4, duration: 6.0
        )
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()

        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(parsed.segments.count == 4)
        #expect(parsed.mediaSequence == 0)
        #expect(parsed.playlistType == .event)
    }

    // MARK: - Event → endStream → VOD

    @Test("Event → endStream → ENDLIST → round-trip")
    func eventToVod() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.endStream()

        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(parsed.hasEndList == true)
        #expect(parsed.playlistType == .event)
        #expect(parsed.segments.count == 3)
    }

    // MARK: - DVR → M3U8 → Parse

    @Test("DVR stream → time eviction → round-trip")
    func dvrRoundTrip() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 15
        )
        let playlist = DVRPlaylist(configuration: config)
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()

        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        // Segment 0 evicted (ends at 6 < cutoff 9)
        #expect(parsed.segments.count == 4)
        #expect(parsed.mediaSequence == 1)
        #expect(parsed.hasEndList == false)
    }

    // MARK: - Discontinuity Flow

    @Test("Discontinuity → M3U8 has correct tags")
    func discontinuityFlow() async throws {
        let playlist = SlidingWindowPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 0)
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 1)
        )
        await playlist.insertDiscontinuity()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 2)
        )

        let m3u8 = await playlist.renderPlaylist()
        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(parsed.segments.count == 3)
        #expect(parsed.segments[2].discontinuity == true)
    }

    // MARK: - fMP4 Init Segment

    @Test("fMP4 playlist with EXT-X-MAP → round-trip")
    func fmp4InitSegment() async throws {
        let config = SlidingWindowConfiguration(
            initSegmentURI: "init.mp4"
        )
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 2)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()

        #expect(
            m3u8.contains("#EXT-X-MAP:URI=\"init.mp4\"")
        )

        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(parsed.segments[0].map?.uri == "init.mp4")
    }

    // MARK: - Sliding Window Eviction Verification

    @Test("Sliding window eviction: state matches M3U8")
    func slidingWindowEvictionVerified() async throws {
        let config = SlidingWindowConfiguration(windowSize: 2)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 6)
        for seg in segments {
            try await playlist.addSegment(seg)
        }

        let seq = await playlist.mediaSequence
        let count = await playlist.segmentCount
        #expect(seq == 4)
        #expect(count == 2)

        let m3u8 = await playlist.renderPlaylist()
        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(parsed.mediaSequence == 4)
        #expect(parsed.segments.count == 2)
        #expect(
            parsed.segments[0].uri == "segment_4.m4s"
        )
        #expect(
            parsed.segments[1].uri == "segment_5.m4s"
        )
    }

    // MARK: - DVR Offset Rendering

    @Test("DVR offset rendering → subset round-trip")
    func dvrOffsetRoundTrip() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 120
        )
        let playlist = DVRPlaylist(configuration: config)
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            try await playlist.addSegment(seg)
        }

        // Offset -18: from timestamp 36 onward
        let m3u8 = await playlist.renderPlaylistFromOffset(-18)
        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(parsed.segments.count == 4)
        #expect(
            parsed.segments[0].uri == "segment_6.m4s"
        )
    }
}
