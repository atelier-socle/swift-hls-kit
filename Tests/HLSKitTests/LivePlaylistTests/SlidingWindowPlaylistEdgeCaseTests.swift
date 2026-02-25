// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "SlidingWindowPlaylist — Edge Cases",
    .timeLimit(.minutes(1))
)
struct SlidingWindowPlaylistEdgeCaseTests {

    // MARK: - Metadata

    @Test("updateMetadata → INDEPENDENT-SEGMENTS rendered")
    func independentSegments() async throws {
        let playlist = SlidingWindowPlaylist()
        await playlist.updateMetadata(
            LivePlaylistMetadata(independentSegments: true)
        )
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }

    @Test("updateMetadata → START rendered")
    func startOffset() async {
        let playlist = SlidingWindowPlaylist()
        await playlist.updateMetadata(
            LivePlaylistMetadata(startOffset: -12.0)
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-START:TIME-OFFSET=-12.0"))
    }

    @Test("Custom tags in metadata rendered")
    func customTags() async {
        let playlist = SlidingWindowPlaylist()
        await playlist.updateMetadata(
            LivePlaylistMetadata(
                customTags: ["#EXT-X-SESSION-DATA:DATA-ID=\"x\""]
            )
        )
        let m3u8 = await playlist.renderPlaylist()
        #expect(
            m3u8.contains("#EXT-X-SESSION-DATA:DATA-ID=\"x\"")
        )
    }

    // MARK: - End Stream

    @Test("endStream → ENDLIST present")
    func endStream() async throws {
        let playlist = SlidingWindowPlaylist()
        try await playlist.addSegment(
            LiveSegmentFactory.makeSegment()
        )
        let m3u8 = await playlist.endStream()
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
    }

    @Test("Add after endStream → throws streamEnded")
    func addAfterEnd() async throws {
        let playlist = SlidingWindowPlaylist()
        _ = await playlist.endStream()
        await #expect(throws: LivePlaylistError.streamEnded) {
            try await playlist.addSegment(
                LiveSegmentFactory.makeSegment()
            )
        }
    }

    // MARK: - Partial Segments

    @Test("addPartialSegment after end → throws")
    func partialAfterEnd() async throws {
        let playlist = SlidingWindowPlaylist()
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
        let playlist = SlidingWindowPlaylist()
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

    // MARK: - Program Date Time

    @Test("PROGRAM-DATE-TIME rendered when segment has it")
    func programDateTime() async throws {
        let playlist = SlidingWindowPlaylist()
        let segment = LiveSegmentFactory.makeSegment(
            programDateTime: Date(
                timeIntervalSince1970: 1_700_000_000
            )
        )
        try await playlist.addSegment(segment)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    // MARK: - Gap

    @Test("GAP rendered for gap segments")
    func gapSegment() async throws {
        let playlist = SlidingWindowPlaylist()
        let segment = LiveSegmentFactory.makeSegment(isGap: true)
        try await playlist.addSegment(segment)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("#EXT-X-GAP"))
    }

    // MARK: - Filenames

    @Test("Segment filenames in M3U8")
    func filenames() async throws {
        let playlist = SlidingWindowPlaylist()
        let segment = LiveSegmentFactory.makeSegment(
            filename: "custom_file.m4s"
        )
        try await playlist.addSegment(segment)
        let m3u8 = await playlist.renderPlaylist()
        #expect(m3u8.contains("custom_file.m4s"))
    }
}
