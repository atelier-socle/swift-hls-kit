// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - CLI Live Showcase

@Suite("CLI Live — Showcase Scenarios")
struct CLILiveShowcaseTests {

    @Test("Podcast studio setup")
    func podcastStudio() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/podcast/",
            "--preset", "podcast-live",
            "--loudness=-16",
            "--record"
        ])
        #expect(cmd.preset == "podcast-live")
        #expect(cmd.loudness == -16)
        #expect(cmd.record == true)
        let config = mapPreset(cmd.preset)
        #expect(config != nil)
    }

    @Test("Film premiere broadcast")
    func filmPremiere() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/premiere/",
            "--preset", "video-4k",
            "--push-http",
            "https://cdn.example.com/"
        ])
        #expect(cmd.preset == "video-4k")
        #expect(cmd.pushHttp.count == 1)
    }

    @Test("Sports broadcast with DVR")
    func sportsBroadcast() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/sports/",
            "--preset", "broadcast",
            "--dvr",
            "--dvr-hours", "6",
            "--push-http", "https://cdn1.example.com/",
            "--push-http", "https://cdn2.example.com/"
        ])
        #expect(cmd.preset == "broadcast")
        #expect(cmd.dvr == true)
        #expect(cmd.dvrHours == 6.0)
        #expect(cmd.pushHttp.count == 2)
    }

    @Test("DJ set with DVR and recording")
    func djSet() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/dj/",
            "--preset", "dj-mix-dvr",
            "--record",
            "--record-dir", "/tmp/recordings/"
        ])
        #expect(cmd.preset == "dj-mix-dvr")
        #expect(cmd.record == true)
        #expect(cmd.recordDir == "/tmp/recordings/")
    }

    @Test("Ad break injection via SCTE-35")
    func adBreakInjection() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/sports/",
            "--scte35",
            "--duration", "120",
            "--id", "halftime-break"
        ])
        #expect(cmd.scte35 == true)
        #expect(cmd.duration == 120)
        #expect(cmd.id == "halftime-break")
        #expect(cmd.spliceType == "out")
    }

    @Test("Interstitial ad insertion")
    func interstitialAd() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/sports/",
            "--interstitial",
            "--asset-url",
            "https://ads.example.com/spot.m3u8",
            "--resume-offset", "0"
        ])
        #expect(cmd.interstitial == true)
        #expect(
            cmd.assetUrl
                == "https://ads.example.com/spot.m3u8"
        )
        #expect(cmd.resumeOffset == 0)
    }

    @Test("Track change metadata")
    func trackChange() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/dj/",
            "--title", "Firestarter",
            "--artist", "The Prodigy"
        ])
        #expect(cmd.title == "Firestarter")
        #expect(cmd.artist == "The Prodigy")
    }

    @Test("VOD extraction from live")
    func vodExtraction() throws {
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", "/tmp/dj/stream.m3u8",
            "--output", "/tmp/vod/",
            "--renumber",
            "--include-date-time"
        ])
        #expect(cmd.playlist == "/tmp/dj/stream.m3u8")
        #expect(cmd.renumber == true)
        #expect(cmd.includeDateTime == true)
    }

    @Test("I-frame thumbnail generation")
    func iframeThumbnails() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/vod/stream.m3u8",
            "--output", "/tmp/vod/iframe.m3u8",
            "--thumbnail-output", "/tmp/thumbs/",
            "--thumbnail-size", "320x180"
        ])
        #expect(cmd.input == "/tmp/vod/stream.m3u8")
        #expect(cmd.thumbnailOutput == "/tmp/thumbs/")
        #expect(cmd.thumbnailSize == "320x180")
    }

    @Test("Conference full setup")
    func conferenceSetup() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/conf/",
            "--preset", "conference-stream",
            "--record",
            "--format", "fmp4"
        ])
        #expect(cmd.preset == "conference-stream")
        #expect(cmd.record == true)
        #expect(cmd.format == "fmp4")
        let config = mapPreset(cmd.preset)
        #expect(config != nil)
    }
}
