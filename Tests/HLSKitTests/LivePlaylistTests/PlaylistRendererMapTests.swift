// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PlaylistRenderer — EXT-X-MAP", .timeLimit(.minutes(1)))
struct PlaylistRendererMapTests {

    let renderer = PlaylistRenderer()

    // MARK: - Helpers

    private func renderM3U8(
        segments: [LiveSegment] = [],
        tracker: MediaSequenceTracker = .init(),
        metadata: LivePlaylistMetadata = .init(),
        targetDuration: Int = 6,
        playlistType: PlaylistRenderer.PlaylistType? = nil,
        hasEndList: Bool = false,
        initSegmentURI: String? = nil
    ) -> String {
        renderer.render(
            context: .init(
                segments: segments,
                sequenceTracker: tracker,
                metadata: metadata,
                targetDuration: targetDuration,
                playlistType: playlistType,
                hasEndList: hasEndList,
                version: 7,
                initSegmentURI: initSegmentURI
            ))
    }

    // MARK: - EXT-X-MAP Presence

    @Test("Render with initSegmentURI → EXT-X-MAP present")
    func mapPresent() {
        let m3u8 = renderM3U8(initSegmentURI: "init.mp4")
        #expect(m3u8.contains("#EXT-X-MAP:URI=\"init.mp4\""))
    }

    @Test("Render without initSegmentURI → no EXT-X-MAP")
    func mapAbsent() {
        let m3u8 = renderM3U8()
        #expect(!m3u8.contains("#EXT-X-MAP"))
    }

    // MARK: - Position

    @Test("EXT-X-MAP after header, before first segment")
    func mapPosition() throws {
        let segments = LiveSegmentFactory.makeSegments(count: 1)
        let m3u8 = renderM3U8(
            segments: segments,
            initSegmentURI: "init.mp4"
        )
        let lines = m3u8.components(separatedBy: "\n")

        let mapIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXT-X-MAP:")
            }
        )
        let mediaSeqIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXT-X-MEDIA-SEQUENCE:")
            }
        )
        let extinfIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXTINF:")
            }
        )

        #expect(mapIdx > mediaSeqIdx)
        #expect(mapIdx < extinfIdx)
    }

    // MARK: - Format

    @Test("EXT-X-MAP format: URI with quotes")
    func mapFormat() {
        let m3u8 = renderM3U8(
            initSegmentURI: "path/to/init.mp4"
        )
        #expect(
            m3u8.contains(
                "#EXT-X-MAP:URI=\"path/to/init.mp4\""
            )
        )
    }

    // MARK: - With Segments

    @Test("EXT-X-MAP with segments renders correctly")
    func mapWithSegments() {
        let segments = LiveSegmentFactory.makeSegments(count: 2)
        let m3u8 = renderM3U8(
            segments: segments,
            initSegmentURI: "init.mp4"
        )
        #expect(m3u8.contains("#EXT-X-MAP:URI=\"init.mp4\""))
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_1.m4s"))
    }

    // MARK: - Round-Trip

    @Test("Round-trip: render with EXT-X-MAP → parse → verify")
    func roundTrip() throws {
        let segments = LiveSegmentFactory.makeSegments(
            count: 2, duration: 6.0
        )
        var tracker = MediaSequenceTracker()
        for seg in segments {
            tracker.segmentAdded(index: seg.index)
        }

        let m3u8 = renderM3U8(
            segments: segments,
            tracker: tracker,
            targetDuration: 6,
            hasEndList: true,
            initSegmentURI: "init.mp4"
        )

        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.segments.count == 2)
        #expect(playlist.hasEndList == true)
        #expect(playlist.segments[0].map?.uri == "init.mp4")
    }
}
