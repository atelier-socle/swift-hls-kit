// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - LiveSubtitlePlaylist

@Suite("LiveSubtitlePlaylist — Playlist Generation")
struct LiveSubtitlePlaylistTests {

    @Test("Default init has correct defaults")
    func defaultInit() {
        let playlist = LiveSubtitlePlaylist()
        #expect(playlist.targetDuration == 6)
        #expect(playlist.language == "en")
        #expect(playlist.name == "English")
        #expect(!playlist.forced)
        #expect(playlist.windowSize == 5)
        #expect(playlist.segmentCount == 0)
    }

    @Test("Custom init sets all properties")
    func customInit() {
        let playlist = LiveSubtitlePlaylist(
            targetDuration: 10,
            language: "fr",
            name: "French",
            forced: true,
            windowSize: 3
        )
        #expect(playlist.targetDuration == 10)
        #expect(playlist.language == "fr")
        #expect(playlist.name == "French")
        #expect(playlist.forced)
        #expect(playlist.windowSize == 3)
    }

    @Test("addSegment increases segment count")
    func addSegment() {
        var playlist = LiveSubtitlePlaylist()
        playlist.addSegment(uri: "sub_001.vtt", duration: 6.0)
        #expect(playlist.segmentCount == 1)
    }

    @Test("Sliding window trims to windowSize")
    func slidingWindow() {
        var playlist = LiveSubtitlePlaylist(windowSize: 3)
        for i in 1...5 {
            playlist.addSegment(uri: "sub_\(i).vtt", duration: 6.0)
        }
        #expect(playlist.segmentCount == 3)
    }

    @Test("mediaSequence increments on trim")
    func mediaSequenceIncrements() {
        var playlist = LiveSubtitlePlaylist(windowSize: 2)
        playlist.addSegment(uri: "sub_1.vtt", duration: 6.0)
        playlist.addSegment(uri: "sub_2.vtt", duration: 6.0)
        let before = playlist.render()
        #expect(before.contains("MEDIA-SEQUENCE:0"))

        playlist.addSegment(uri: "sub_3.vtt", duration: 6.0)
        let after = playlist.render()
        #expect(after.contains("MEDIA-SEQUENCE:1"))
    }

    @Test("render produces valid M3U8 format")
    func render() {
        var playlist = LiveSubtitlePlaylist(targetDuration: 6)
        playlist.addSegment(uri: "sub_001.vtt", duration: 6.0)
        let m3u8 = playlist.render()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:6"))
        #expect(m3u8.contains("#EXT-X-VERSION:3"))
        #expect(m3u8.contains("#EXT-X-MEDIA-SEQUENCE:0"))
        #expect(m3u8.contains("#EXTINF:"))
        #expect(m3u8.contains("sub_001.vtt"))
    }

    @Test("render with no segments still produces valid header")
    func renderEmpty() {
        let playlist = LiveSubtitlePlaylist()
        let m3u8 = playlist.render()
        #expect(m3u8.hasPrefix("#EXTM3U\n"))
        #expect(m3u8.contains("#EXT-X-TARGETDURATION:6"))
    }

    @Test("renditionEntry generates correct EXT-X-MEDIA tag")
    func renditionEntry() {
        let playlist = LiveSubtitlePlaylist(language: "en", name: "English")
        let entry = playlist.renditionEntry(uri: "subs/en.m3u8")
        #expect(entry.hasPrefix("#EXT-X-MEDIA:"))
        #expect(entry.contains("TYPE=SUBTITLES"))
        #expect(entry.contains("LANGUAGE=\"en\""))
        #expect(entry.contains("NAME=\"English\""))
        #expect(entry.contains("URI=\"subs/en.m3u8\""))
        #expect(entry.contains("DEFAULT=NO"))
        #expect(entry.contains("AUTOSELECT=YES"))
    }

    @Test("renditionEntry with isDefault true")
    func renditionEntryDefault() {
        let playlist = LiveSubtitlePlaylist()
        let entry = playlist.renditionEntry(uri: "subs/en.m3u8", isDefault: true)
        #expect(entry.contains("DEFAULT=YES"))
    }

    @Test("renditionEntry with custom groupID")
    func renditionEntryCustomGroup() {
        let playlist = LiveSubtitlePlaylist()
        let entry = playlist.renditionEntry(
            groupID: "subtitles", uri: "subs/en.m3u8"
        )
        #expect(entry.contains("GROUP-ID=\"subtitles\""))
    }

    @Test("renditionEntry includes FORCED=YES for forced subtitles")
    func renditionEntryForced() {
        let playlist = LiveSubtitlePlaylist(forced: true)
        let entry = playlist.renditionEntry(uri: "subs/forced.m3u8")
        #expect(entry.contains("FORCED=YES"))
    }

    @Test("Non-forced playlist omits FORCED attribute")
    func renditionEntryNotForced() {
        let playlist = LiveSubtitlePlaylist(forced: false)
        let entry = playlist.renditionEntry(uri: "subs/en.m3u8")
        #expect(!entry.contains("FORCED"))
    }

    @Test("Multiple segments render correctly")
    func multipleSegments() {
        var playlist = LiveSubtitlePlaylist()
        playlist.addSegment(uri: "sub_001.vtt", duration: 6.0)
        playlist.addSegment(uri: "sub_002.vtt", duration: 5.5)
        let m3u8 = playlist.render()
        #expect(m3u8.contains("sub_001.vtt"))
        #expect(m3u8.contains("sub_002.vtt"))
    }

    @Test("segmentCount reflects current window")
    func segmentCount() {
        var playlist = LiveSubtitlePlaylist(windowSize: 3)
        #expect(playlist.segmentCount == 0)
        playlist.addSegment(uri: "a.vtt", duration: 6.0)
        #expect(playlist.segmentCount == 1)
        playlist.addSegment(uri: "b.vtt", duration: 6.0)
        playlist.addSegment(uri: "c.vtt", duration: 6.0)
        playlist.addSegment(uri: "d.vtt", duration: 6.0)
        #expect(playlist.segmentCount == 3)
    }
}
