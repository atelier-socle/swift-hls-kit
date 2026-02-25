// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "LivePlaylist — Showcase",
    .timeLimit(.minutes(1))
)
struct LivePlaylistShowcaseTests {

    // MARK: - Podcast Live

    @Test("Podcast live: 10 audio segments → sliding window")
    func podcastLive() async throws {
        let config = SlidingWindowConfiguration(
            windowSize: 5, targetDuration: 6.0
        )
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(
            count: 10, duration: 6.0
        )
        for seg in segments {
            try await playlist.addSegment(seg)
        }

        let m3u8 = await playlist.renderPlaylist()

        // Verify live playlist characteristics
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXT-X-VERSION:7"))
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:6"))
        #expect(!m3u8.contains("#EXT-X-PLAYLIST-TYPE"))
        #expect(!m3u8.contains("#EXT-X-ENDLIST"))

        // Window should show last 5 segments
        #expect(!m3u8.contains("segment_4.m4s"))
        #expect(m3u8.contains("segment_5.m4s"))
        #expect(m3u8.contains("segment_9.m4s"))
        #expect(m3u8.contains("#EXT-X-MEDIA-SEQUENCE:5"))

        // Round-trip parse validates M3U8
        let parser = ManifestParser()
        let result = try parser.parse(m3u8)
        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(parsed.segments.count == 5)
    }

    // MARK: - Sports DVR

    @Test("Sports event: DVR with 60s window")
    func sportsDVR() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 60, targetDuration: 6.0
        )
        let playlist = DVRPlaylist(configuration: config)

        // 20 segments of 6s (total 120s), window 60s
        let segments = LiveSegmentFactory.makeSegments(
            count: 20, duration: 6.0
        )
        for seg in segments {
            try await playlist.addSegment(seg)
        }

        let count = await playlist.segmentCount

        // 20 segments of 6s: timestamps 0..114, cutoff=114-60=54
        // Segments 0-7 evicted (end times 6..48 < 54)
        // Segments 8-19 kept (12 segments, 72s total)
        #expect(count == 12)

        let m3u8 = await playlist.renderPlaylist()
        #expect(!m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_19.m4s"))

        // DVR rewind: offset -30s from live edge
        let rewind = await playlist.renderPlaylistFromOffset(-30)
        let parser = ManifestParser()
        let result = try parser.parse(rewind)
        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(parsed.segments.count > 0)
    }

    // MARK: - Event-to-VOD

    @Test("Event-to-VOD: add segments → endStream → VOD")
    func eventToVod() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(
            count: 5, duration: 6.0
        )
        for seg in segments {
            try await playlist.addSegment(seg)
        }

        // Before ending: EVENT type, no ENDLIST
        let liveM3U8 = await playlist.renderPlaylist()
        #expect(
            liveM3U8.contains("#EXT-X-PLAYLIST-TYPE:EVENT")
        )
        #expect(!liveM3U8.contains("#EXT-X-ENDLIST"))

        // After ending: has ENDLIST
        let vodM3U8 = await playlist.endStream()
        #expect(
            vodM3U8.contains("#EXT-X-PLAYLIST-TYPE:EVENT")
        )
        #expect(vodM3U8.contains("#EXT-X-ENDLIST"))

        // Round-trip parse
        let parser = ManifestParser()
        let result = try parser.parse(vodM3U8)
        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(parsed.hasEndList == true)
        #expect(parsed.playlistType == .event)
        #expect(parsed.segments.count == 5)
    }

    // MARK: - Ad Insertion

    @Test("Ad insertion: discontinuity markers correct")
    func adInsertion() async throws {
        let playlist = SlidingWindowPlaylist(
            configuration: .init(windowSize: 10)
        )

        // Content segments 0-2
        for i in 0..<3 {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment(index: i)
            )
        }

        // Discontinuity → ad break
        await playlist.insertDiscontinuity()
        for i in 3..<5 {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment(index: i)
            )
        }

        // Discontinuity → resume content
        await playlist.insertDiscontinuity()
        for i in 5..<8 {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment(index: i)
            )
        }

        let m3u8 = await playlist.renderPlaylist()

        // Should have 2 discontinuity tags
        let discCount =
            m3u8.components(
                separatedBy: "#EXT-X-DISCONTINUITY"
            ).count - 1
        #expect(discCount == 2)

        // Round-trip parse
        let parser = ManifestParser()
        let result = try parser.parse(m3u8)
        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(parsed.segments.count == 8)
        #expect(parsed.segments[3].discontinuity == true)
        #expect(parsed.segments[5].discontinuity == true)
    }

    // MARK: - fMP4 with Init Segment

    @Test("fMP4 live with EXT-X-MAP → valid M3U8")
    func fmp4WithMap() async throws {
        let config = SlidingWindowConfiguration(
            windowSize: 5,
            initSegmentURI: "audio_init.mp4"
        )
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }

        let m3u8 = await playlist.renderPlaylist()
        #expect(
            m3u8.contains(
                "#EXT-X-MAP:URI=\"audio_init.mp4\""
            )
        )

        // Round-trip parse
        let parser = ManifestParser()
        let result = try parser.parse(m3u8)
        guard case .media(let parsed) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(
            parsed.segments[0].map?.uri == "audio_init.mp4"
        )
    }
}
