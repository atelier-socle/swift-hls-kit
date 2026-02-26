// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - Live Command Showcase

@Suite("CLI Showcase — Live Command")
struct LiveCommandShowcaseTests {

    @Test("LiveCommand — has 4 subcommands (start, stop, stats, convert-to-vod)")
    func subcommands() {
        let subs = LiveCommand.configuration.subcommands
        #expect(subs.count == 4)
    }

    @Test("LiveStartCommand — podcast live with default preset")
    func podcastLiveDefaults() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./podcast-live/"
        ])
        #expect(cmd.output == "./podcast-live/")
        #expect(cmd.preset == "podcast-live")
        #expect(cmd.quiet == false)
    }

    @Test("LiveStartCommand — video simulcast with push destinations")
    func videoSimulcastWithPush() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/simulcast/",
            "--preset", "video-simulcast",
            "--push-http", "https://cdn1.example.com/ingest",
            "--push-http", "https://cdn2.example.com/ingest",
            "--push-header", "Authorization:Bearer abc123",
            "--push-header", "X-Stream-Key:live_key"
        ])
        #expect(cmd.preset == "video-simulcast")
        #expect(cmd.pushHttp.count == 2)
        #expect(cmd.pushHeader.count == 2)
    }

    @Test("LiveStartCommand — broadcast with DVR and recording")
    func broadcastWithDVR() throws {
        let cmd = try LiveStartCommand.parse([
            "-o", "/tmp/broadcast/",
            "--preset", "broadcast",
            "--dvr",
            "--dvr-hours", "6.0",
            "--record",
            "--record-dir", "/tmp/recordings/",
            "--output-format", "json"
        ])
        #expect(cmd.preset == "broadcast")
        #expect(cmd.dvr == true)
        #expect(cmd.dvrHours == 6.0)
        #expect(cmd.record == true)
        #expect(cmd.recordDir == "/tmp/recordings/")
        #expect(cmd.outputFormat == "json")
    }

    @Test("LiveStartCommand — list presets without output")
    func listPresetsOnly() throws {
        let cmd = try LiveStartCommand.parse([
            "--list-presets"
        ])
        #expect(cmd.listPresets == true)
        #expect(cmd.output == nil)
    }

    @Test("LiveStopCommand — stop with VOD conversion")
    func stopWithVOD() throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "./live/",
            "--convert-to-vod",
            "--quiet"
        ])
        #expect(cmd.output == "./live/")
        #expect(cmd.convertToVod == true)
        #expect(cmd.quiet == true)
    }

    @Test("LiveStatsCommand — watch mode with JSON output")
    func watchStatsJSON() throws {
        let cmd = try LiveStatsCommand.parse([
            "--output", "./live/",
            "--watch",
            "--output-format", "json"
        ])
        #expect(cmd.watch == true)
        #expect(cmd.outputFormat == "json")
    }

    @Test("LiveConvertToVODCommand — full conversion with all flags")
    func fullConversion() throws {
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", "/tmp/live/playlist.m3u8",
            "-o", "/tmp/vod/playlist.m3u8",
            "--renumber",
            "--include-date-time",
            "--output-format", "json"
        ])
        #expect(
            cmd.playlist == "/tmp/live/playlist.m3u8"
        )
        #expect(
            cmd.output == "/tmp/vod/playlist.m3u8"
        )
        #expect(cmd.renumber == true)
        #expect(cmd.includeDateTime == true)
        #expect(cmd.outputFormat == "json")
    }

    @Test("OutputFormatter — formatPresetList returns all 16 presets")
    func presetListContainsAll() {
        let formatter = OutputFormatter.text
        let list = formatter.formatPresetList()
        let presetNames = [
            "podcast-live", "webradio", "dj-mix",
            "low-bandwidth", "video-live",
            "low-latency-video", "video-simulcast",
            "video-4k", "video-4k-low-latency",
            "podcast-video", "video-live-dvr",
            "apple-podcast-live", "broadcast",
            "event-recording", "conference-stream",
            "dj-mix-dvr"
        ]
        for name in presetNames {
            #expect(
                list.contains(name),
                "Preset list missing: \(name)"
            )
        }
    }
}
