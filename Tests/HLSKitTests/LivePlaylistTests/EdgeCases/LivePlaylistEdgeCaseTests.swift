// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "LivePlaylist — Edge Cases",
    .timeLimit(.minutes(1))
)
struct LivePlaylistEdgeCaseTests {

    // MARK: - Empty Playlists

    @Test("Empty sliding window → valid M3U8 header only")
    func emptySlidingWindow() async {
        let playlist = SlidingWindowPlaylist()
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(!m3u8.contains("#EXTINF:"))
    }

    @Test("Empty DVR → valid M3U8 header only")
    func emptyDVR() async {
        let playlist = DVRPlaylist()
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(!m3u8.contains("#EXTINF:"))
    }

    @Test("Empty event → valid M3U8 header only")
    func emptyEvent() async {
        let playlist = EventPlaylist()
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(!m3u8.contains("#EXTINF:"))
    }

    // MARK: - Single Segment

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

    // MARK: - Add After End

    @Test("Add after endStream → throws (sliding window)")
    func addAfterEndSlidingWindow() async throws {
        let playlist = SlidingWindowPlaylist()
        _ = await playlist.endStream()
        await #expect(throws: LivePlaylistError.streamEnded) {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment()
            )
        }
    }

    @Test("Add after endStream → throws (event)")
    func addAfterEndEvent() async throws {
        let playlist = EventPlaylist()
        _ = await playlist.endStream()
        await #expect(throws: LivePlaylistError.streamEnded) {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment()
            )
        }
    }

    // MARK: - DVR Edge Cases

    @Test("DVR with 0-second window → aggressive eviction")
    func dvrZeroWindow() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 0
        )
        let playlist = DVRPlaylist(configuration: config)
        // 3 segments of 6s at timestamps 0, 6, 12
        // Cutoff = latest.seconds - 0 = 12
        // Seg 0: ends 6 < 12 → evict
        // Seg 1: ends 12 NOT < 12 → keep
        // Seg 2: ends 18 NOT < 12 → keep
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let count = await playlist.segmentCount
        #expect(count == 2)
        let seq = await playlist.mediaSequence
        #expect(seq == 1)  // 1 segment evicted
    }

    @Test("DVR with very large window → no eviction")
    func dvrLargeWindow() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 999_999
        )
        let playlist = DVRPlaylist(configuration: config)
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let count = await playlist.segmentCount
        #expect(count == 10)
    }

    @Test("DVR segments without programDateTime → dateRange empty")
    func dvrNoDateRange() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 120
        )
        let playlist = DVRPlaylist(configuration: config)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        // allSegments have no programDateTime
        let all = await playlist.allSegments
        let noDate = all.allSatisfy {
            $0.programDateTime == nil
        }
        #expect(noDate)
    }

    // MARK: - Window Size Edge Cases

    @Test("SlidingWindow windowSize=1 → only last segment")
    func windowSizeOne() async throws {
        let config = SlidingWindowConfiguration(windowSize: 1)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let count = await playlist.segmentCount
        let m3u8 = await playlist.renderPlaylist()
        #expect(count == 1)
        #expect(m3u8.contains("segment_4.m4s"))
        #expect(!m3u8.contains("segment_3.m4s"))
    }

    // MARK: - Large Playlist

    @Test("Event with 100 segments → valid large playlist")
    func largeEventPlaylist() async throws {
        let playlist = EventPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 100)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let count = await playlist.segmentCount
        #expect(count == 100)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_99.m4s"))
    }

    // MARK: - Multiple Discontinuities

    @Test("Multiple discontinuities → correct sequence")
    func multipleDiscontinuities() async throws {
        let config = SlidingWindowConfiguration(windowSize: 2)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        // seg0, disc, seg1, disc, seg2, seg3, seg4
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 0)
        )
        await playlist.insertDiscontinuity()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 1)
        )
        await playlist.insertDiscontinuity()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 2)
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 3)
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment(index: 4)
        )
        // Window: [3, 4], evicted: 0, 1, 2
        // Disc at 1 evicted, disc at 2 evicted
        let discSeq = await playlist.discontinuitySequence
        #expect(discSeq == 2)
    }

    // MARK: - MediaSequenceTracker Eviction

    @Test("Evict all segments → mediaSequence correct")
    func evictAllSegments() async throws {
        let config = SlidingWindowConfiguration(windowSize: 1)
        let playlist = SlidingWindowPlaylist(
            configuration: config
        )
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let seq = await playlist.mediaSequence
        #expect(seq == 9)  // 9 segments evicted
    }

    // MARK: - Renderer Edge Cases

    @Test("Segment with all optional fields set → all tags")
    func segmentAllFields() {
        let renderer = PlaylistRenderer()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let segment = LiveSegmentFactory.makeSegment(
            isGap: true,
            programDateTime: date
        )
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)

        let m3u8 = renderer.render(
            context: .init(
                segments: [segment],
                sequenceTracker: tracker,
                metadata: LivePlaylistMetadata(
                    independentSegments: true,
                    startOffset: -6.0
                ),
                targetDuration: 6,
                playlistType: .event,
                hasEndList: true,
                version: 7,
                initSegmentURI: "init.mp4"
            ))
        #expect(m3u8.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
        #expect(m3u8.contains("#EXT-X-START:"))
        #expect(m3u8.contains("#EXT-X-MAP:URI=\"init.mp4\""))
        #expect(m3u8.contains("#EXT-X-GAP"))
        #expect(m3u8.contains("#EXT-X-PROGRAM-DATE-TIME:"))
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
    }

    @Test("Segment with no optional fields → minimal tags")
    func segmentMinimal() {
        let renderer = PlaylistRenderer()
        let segment = LiveSegmentFactory.makeSegment()
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)

        let m3u8 = renderer.render(
            context: .init(
                segments: [segment],
                sequenceTracker: tracker,
                metadata: .init(),
                targetDuration: 6,
                playlistType: nil,
                hasEndList: false,
                version: 7
            ))
        #expect(!m3u8.contains("#EXT-X-GAP"))
        #expect(!m3u8.contains("#EXT-X-PROGRAM-DATE-TIME"))
        #expect(!m3u8.contains("#EXT-X-DISCONTINUITY"))
        #expect(!m3u8.contains("#EXT-X-MAP"))
        #expect(!m3u8.contains("#EXT-X-ENDLIST"))
        #expect(m3u8.contains("#EXTINF:6.0,"))
        #expect(m3u8.contains("segment_0.m4s"))
    }

    // MARK: - DVRBuffer Edge Cases

    @Test("DVRBuffer: segmentsFromOffset beyond buffer → from start")
    func dvrBufferOffsetBeyond() {
        var buffer = DVRBuffer(windowDuration: 120)
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            buffer.append(seg)
        }
        let result = buffer.segmentsFromOffset(-9999)
        #expect(result.count == 3)
        #expect(result[0].index == 0)
    }

    @Test("DVRBuffer: segmentsFromOffset=0 → live edge")
    func dvrBufferOffsetZero() {
        var buffer = DVRBuffer(windowDuration: 120)
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            buffer.append(seg)
        }
        let result = buffer.segmentsFromOffset(0)
        #expect(result.count == 1)
        #expect(result[0].index == 4)
    }

    @Test("DVRBuffer: append + evict + append → map correct")
    func dvrBufferAppendEvictAppend() {
        var buffer = DVRBuffer(windowDuration: 15)
        let batch1 = LiveSegmentFactory.makeSegments(count: 5)
        for seg in batch1 {
            buffer.append(seg)
        }
        buffer.evictExpired()

        let seg5 = LiveSegmentFactory.makeSegment(index: 5)
        buffer.append(seg5)

        #expect(buffer.segment(at: 5)?.index == 5)
        #expect(buffer.segment(at: 0) == nil)
        #expect(buffer.count > 0)
    }
}
