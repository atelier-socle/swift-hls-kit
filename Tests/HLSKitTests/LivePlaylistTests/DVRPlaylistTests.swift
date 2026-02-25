// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("DVRPlaylist", .timeLimit(.minutes(1)))
struct DVRPlaylistTests {

    // MARK: - Basic Operations

    @Test("Add segment renders in M3U8")
    func addSegment() async throws {
        let playlist = DVRPlaylist()
        let segment = LiveSegmentFactory.makeSegment()
        try await playlist.addSegment(segment)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("#EXTINF:6.0,"))
    }

    @Test("Add multiple segments → all present")
    func addMultiple() async throws {
        let playlist = DVRPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_1.m4s"))
        #expect(m3u8.contains("segment_2.m4s"))
    }

    // MARK: - Time-Based Eviction

    @Test("Time-based eviction removes expired segments")
    func timeEviction() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 15
        )
        let playlist = DVRPlaylist(configuration: config)
        // 5 segments of 6s: timestamps 0, 6, 12, 18, 24
        // Latest = 24, cutoff = 24 - 15 = 9
        // Segment 0 ends at 6 < 9 → evicted
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let m3u8 = await playlist.renderPlaylist()
        #expect(!m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_1.m4s"))
        #expect(m3u8.contains("segment_4.m4s"))
    }

    @Test("mediaSequence increments with eviction")
    func mediaSequenceIncrement() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 15
        )
        let playlist = DVRPlaylist(configuration: config)
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let seq = await playlist.mediaSequence
        #expect(seq == 1)  // 1 segment evicted
    }

    // MARK: - DVR Offset Rendering

    @Test("renderPlaylistFromOffset returns subset")
    func renderFromOffset() async throws {
        let playlist = DVRPlaylist(
            configuration: .init(dvrWindowDuration: 120)
        )
        // 10 segments of 6s, timestamps: 0, 6, 12, 18, 24, 30, 36, 42, 48, 54
        let segments = LiveSegmentFactory.makeSegments(count: 10)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        // Offset -18: target = 54 + (-18) = 36
        let m3u8 = await playlist.renderPlaylistFromOffset(-18)
        #expect(!m3u8.contains("segment_5.m4s"))
        #expect(m3u8.contains("segment_6.m4s"))
        #expect(m3u8.contains("segment_9.m4s"))
    }

    // MARK: - End Stream

    @Test("endStream → EXT-X-ENDLIST present")
    func endStream() async throws {
        let playlist = DVRPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.endStream()
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
    }

    @Test("Add after endStream → throws streamEnded")
    func addAfterEnd() async throws {
        let playlist = DVRPlaylist()
        _ = await playlist.endStream()
        await #expect(throws: LivePlaylistError.streamEnded) {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment()
            )
        }
    }

    // MARK: - DVR Accessors

    @Test("totalDuration computed correctly")
    func totalDuration() async throws {
        let playlist = DVRPlaylist()
        let segments = LiveSegmentFactory.makeSegments(
            count: 3, duration: 6.0
        )
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let duration = await playlist.totalDuration
        #expect(abs(duration - 18.0) < 0.01)
    }

    @Test("segmentCount matches buffer count")
    func segmentCount() async throws {
        let playlist = DVRPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 4)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let count = await playlist.segmentCount
        #expect(count == 4)
    }

    @Test("totalDataSize computed correctly")
    func totalDataSize() async throws {
        let playlist = DVRPlaylist()
        let segments = LiveSegmentFactory.makeSegments(count: 3)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let size = await playlist.totalDataSize
        #expect(size == 192)  // 3 × 64 bytes
    }

    @Test("allSegments returns current buffer")
    func allSegments() async throws {
        let config = DVRPlaylistConfiguration(
            dvrWindowDuration: 15
        )
        let playlist = DVRPlaylist(configuration: config)
        let segments = LiveSegmentFactory.makeSegments(count: 5)
        for seg in segments {
            try await playlist.addSegment(seg)
        }
        let all = await playlist.allSegments
        // Segment 0 evicted (ends at 6 < cutoff 9)
        #expect(all.count == 4)
        #expect(all[0].index == 1)
    }

    // MARK: - No Playlist Type

    @Test("No PLAYLIST-TYPE tag (live DVR)")
    func noPlaylistType() async throws {
        let playlist = DVRPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(!m3u8.contains("#EXT-X-PLAYLIST-TYPE"))
    }

    // MARK: - Discontinuity

    @Test("insertDiscontinuity → DISCONTINUITY tag")
    func discontinuity() async throws {
        let playlist = DVRPlaylist()
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

    // MARK: - Metadata

    @Test("updateMetadata → rendered in M3U8")
    func updateMetadata() async throws {
        let playlist = DVRPlaylist()
        await playlist.updateMetadata(
            LivePlaylistMetadata(independentSegments: true)
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }

    // MARK: - Partial Segments

    @Test("addPartialSegment after end → throws")
    func partialAfterEnd() async throws {
        let playlist = DVRPlaylist()
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
        let playlist = DVRPlaylist()
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

    // MARK: - Target Duration

    @Test("TARGETDURATION = ceil of max segment duration")
    func targetDuration() async throws {
        let playlist = DVRPlaylist()
        let seg1 = LiveSegmentFactory.makeSegment(
            index: 0, duration: 5.5
        )
        let seg2 = LiveSegmentFactory.makeSegment(
            index: 1, duration: 6.006
        )
        try await playlist.addSegment(seg1)
        try await playlist.addSegment(seg2)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:7"))
    }

    @Test("Empty playlist uses config targetDuration")
    func emptyTargetDuration() async {
        let config = DVRPlaylistConfiguration(
            targetDuration: 4.0
        )
        let playlist = DVRPlaylist(configuration: config)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:4"))
    }

    // MARK: - Presets

    @Test("DVR presets work with playlist")
    func presets() async {
        let short = DVRPlaylist(
            configuration: .shortDVR
        )
        let long = DVRPlaylist(
            configuration: .longDVR
        )
        let shortConfig = await short.configuration
        let longConfig = await long.configuration
        #expect(shortConfig.dvrWindowDuration == 1800)
        #expect(longConfig.dvrWindowDuration == 28800)
    }
}
