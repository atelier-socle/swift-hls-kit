// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("PlaylistRenderer", .timeLimit(.minutes(1)))
struct PlaylistRendererTests {

    let renderer = PlaylistRenderer()

    // MARK: - Helpers

    private func renderM3U8(
        segments: [LiveSegment] = [],
        tracker: MediaSequenceTracker = .init(),
        metadata: LivePlaylistMetadata = .init(),
        targetDuration: Int = 6,
        playlistType: PlaylistRenderer.PlaylistType? = nil,
        hasEndList: Bool = false
    ) -> String {
        renderer.render(
            context: .init(
                segments: segments,
                sequenceTracker: tracker,
                metadata: metadata,
                targetDuration: targetDuration,
                playlistType: playlistType,
                hasEndList: hasEndList,
                version: 7
            ))
    }

    // MARK: - Empty Playlist

    @Test("Render empty playlist produces valid header")
    func emptyPlaylist() {
        let m3u8 = renderM3U8()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(m3u8.contains("#EXT-X-VERSION:7"))
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:6"))
        #expect(m3u8.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        #expect(!m3u8.contains("#EXT-X-ENDLIST"))
    }

    // MARK: - Segments

    @Test("Render with segments produces EXTINF + URI")
    func withSegments() {
        let segments = LiveSegmentFactory.makeSegments(
            count: 2, duration: 6.006
        )
        let m3u8 = renderM3U8(
            segments: segments, targetDuration: 7
        )
        #expect(m3u8.contains("#EXTINF:6.006,"))
        #expect(m3u8.contains("segment_0.m4s"))
        #expect(m3u8.contains("segment_1.m4s"))
    }

    @Test("Render with discontinuity tag")
    func withDiscontinuity() {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.discontinuityInserted()
        tracker.segmentAdded(index: 1)

        let segments = LiveSegmentFactory.makeSegments(count: 2)
        let m3u8 = renderM3U8(
            segments: segments, tracker: tracker
        )
        #expect(m3u8.contains("#EXT-X-DISCONTINUITY"))
    }

    @Test("Render with programDateTime")
    func withProgramDateTime() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let segment = LiveSegmentFactory.makeSegment(
            programDateTime: date
        )
        let m3u8 = renderM3U8(segments: [segment])
        #expect(m3u8.contains("#EXT-X-PROGRAM-DATE-TIME:"))
    }

    @Test("Render with gap tag")
    func withGap() {
        let segment = LiveSegmentFactory.makeSegment(isGap: true)
        let m3u8 = renderM3U8(segments: [segment])
        #expect(m3u8.contains("#EXT-X-GAP"))
    }

    // MARK: - Metadata

    @Test("Render with independentSegments")
    func independentSegments() {
        let meta = LivePlaylistMetadata(independentSegments: true)
        let m3u8 = renderM3U8(metadata: meta)
        #expect(m3u8.contains("#EXT-X-INDEPENDENT-SEGMENTS"))
    }

    @Test("Render with startOffset")
    func startOffset() {
        let meta = LivePlaylistMetadata(startOffset: -12.0)
        let m3u8 = renderM3U8(metadata: meta)
        #expect(m3u8.contains("#EXT-X-START:TIME-OFFSET=-12.0"))
    }

    @Test("Render with startOffset precise")
    func startOffsetPrecise() {
        let meta = LivePlaylistMetadata(
            startOffset: -6.0, startPrecise: true
        )
        let m3u8 = renderM3U8(metadata: meta)
        #expect(
            m3u8.contains(
                "#EXT-X-START:TIME-OFFSET=-6.0,PRECISE=YES"
            )
        )
    }

    @Test("Render with custom tags")
    func customTags() {
        let meta = LivePlaylistMetadata(
            customTags: ["#EXT-X-SESSION-DATA:DATA-ID=\"test\""]
        )
        let m3u8 = renderM3U8(metadata: meta)
        #expect(
            m3u8.contains(
                "#EXT-X-SESSION-DATA:DATA-ID=\"test\""
            )
        )
    }

    // MARK: - Playlist Type

    @Test("Render event type")
    func eventType() {
        let m3u8 = renderM3U8(playlistType: .event)
        #expect(m3u8.contains("#EXT-X-PLAYLIST-TYPE:EVENT"))
    }

    @Test("Render VOD type")
    func vodType() {
        let m3u8 = renderM3U8(playlistType: .vod)
        #expect(m3u8.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
    }

    // MARK: - End List

    @Test("Render with endList")
    func withEndList() {
        let m3u8 = renderM3U8(hasEndList: true)
        #expect(m3u8.contains("#EXT-X-ENDLIST"))
    }

    // MARK: - Duration Formatting

    @Test("Duration 3 decimal places, trailing zeros trimmed")
    func durationFormatting() {
        #expect(renderer.formatDuration(6.006) == "6.006")
        #expect(renderer.formatDuration(6.0) == "6.0")
        #expect(renderer.formatDuration(6.100) == "6.1")
        #expect(renderer.formatDuration(6.120) == "6.12")
        #expect(renderer.formatDuration(0.0) == "0.0")
    }

    // MARK: - ISO 8601

    @Test("ISO 8601 date formatting")
    func iso8601Formatting() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let result = renderer.formatISO8601(date)
        #expect(result.contains("2023-11-14"))
        #expect(result.contains("T"))
    }

    // MARK: - Tag Ordering

    @Test("Tag ordering follows HLS spec")
    func tagOrdering() throws {
        var tracker = MediaSequenceTracker()
        tracker.segmentAdded(index: 0)
        tracker.segmentEvicted(index: 0)
        tracker.discontinuityInserted()
        tracker.segmentAdded(index: 1)
        tracker.segmentEvicted(index: 1)

        let meta = LivePlaylistMetadata(
            independentSegments: true, startOffset: -6.0
        )
        let segments = LiveSegmentFactory.makeSegments(
            count: 1, startIndex: 2
        )
        let m3u8 = renderM3U8(
            segments: segments,
            tracker: tracker,
            metadata: meta,
            playlistType: .event,
            hasEndList: true
        )
        let lines = m3u8.components(separatedBy: "\n")

        let extm3uIdx = try #require(
            lines.firstIndex(of: "#EXTM3U")
        )
        let versionIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXT-X-VERSION:")
            })
        let targetIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXT-X-TARGETDURATION:")
            })
        let mediaSeqIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXT-X-MEDIA-SEQUENCE:")
            })
        let discSeqIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXT-X-DISCONTINUITY-SEQUENCE:")
            })
        let ptypeIdx = try #require(
            lines.firstIndex {
                $0.hasPrefix("#EXT-X-PLAYLIST-TYPE:")
            })
        let endListIdx = try #require(
            lines.firstIndex(of: "#EXT-X-ENDLIST")
        )

        #expect(extm3uIdx < versionIdx)
        #expect(versionIdx < targetIdx)
        #expect(targetIdx < mediaSeqIdx)
        #expect(mediaSeqIdx < discSeqIdx)
        #expect(discSeqIdx < ptypeIdx)
        #expect(ptypeIdx < endListIdx)
    }

    // MARK: - Discontinuity Sequence

    @Test("Discontinuity sequence omitted when 0")
    func discSeqOmittedWhenZero() {
        let m3u8 = renderM3U8()
        #expect(
            !m3u8.contains("#EXT-X-DISCONTINUITY-SEQUENCE:")
        )
    }

    // MARK: - Round-Trip

    @Test("Round-trip: render → parse → fields match")
    func roundTrip() throws {
        let segments = LiveSegmentFactory.makeSegments(
            count: 3, duration: 6.006
        )
        var tracker = MediaSequenceTracker()
        for seg in segments {
            tracker.segmentAdded(index: seg.index)
        }

        let m3u8 = renderM3U8(
            segments: segments,
            tracker: tracker,
            targetDuration: 7,
            playlistType: .event,
            hasEndList: true
        )

        let parser = ManifestParser()
        let result = try parser.parse(m3u8)

        guard case .media(let playlist) = result else {
            Issue.record("Expected media playlist")
            return
        }

        #expect(playlist.targetDuration == 7)
        #expect(playlist.mediaSequence == 0)
        #expect(playlist.segments.count == 3)
        #expect(playlist.hasEndList == true)
        #expect(playlist.playlistType == .event)
        #expect(playlist.segments[0].uri == "segment_0.m4s")
        #expect(playlist.segments[1].uri == "segment_1.m4s")
        #expect(playlist.segments[2].uri == "segment_2.m4s")
        #expect(abs(playlist.segments[0].duration - 6.006) < 0.01)
    }
}
