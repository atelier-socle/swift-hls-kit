// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - LiveStartCommand

@Suite("LiveStartCommand — Argument Parsing")
struct LiveStartCommandTests {

    @Test("Parse with defaults")
    func parseDefaults() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/"
        ])
        #expect(cmd.output == "./live/")
        #expect(cmd.preset == "podcast-live")
        #expect(cmd.segmentDuration == nil)
        #expect(cmd.audioBitrate == nil)
        #expect(cmd.loudness == nil)
        #expect(cmd.format == nil)
        #expect(cmd.pushHttp.isEmpty)
        #expect(cmd.pushHeader.isEmpty)
        #expect(cmd.record == false)
        #expect(cmd.recordDir == nil)
        #expect(cmd.dvr == false)
        #expect(cmd.dvrHours == nil)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
        #expect(cmd.listPresets == false)
    }

    @Test("Parse with preset")
    func parsePreset() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--preset", "broadcast"
        ])
        #expect(cmd.preset == "broadcast")
    }

    @Test("Parse with short -o output")
    func parseShortOutput() throws {
        let cmd = try LiveStartCommand.parse([
            "-o", "/tmp/hls/"
        ])
        #expect(cmd.output == "/tmp/hls/")
    }

    @Test("Parse with segment duration override")
    func parseSegmentDuration() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--segment-duration", "4.0"
        ])
        #expect(cmd.segmentDuration == 4.0)
    }

    @Test("Parse with audio bitrate override")
    func parseAudioBitrate() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--audio-bitrate", "256"
        ])
        #expect(cmd.audioBitrate == 256)
    }

    @Test("Parse with loudness override")
    func parseLoudness() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--loudness=-23.0"
        ])
        #expect(cmd.loudness == -23.0)
    }

    @Test("Parse with format override")
    func parseFormat() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--format", "mpegts"
        ])
        #expect(cmd.format == "mpegts")
    }

    @Test("Parse with push HTTP destinations")
    func parsePushHttp() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--push-http", "https://cdn.example.com/ingest",
            "--push-http", "https://backup.example.com/ingest"
        ])
        #expect(cmd.pushHttp.count == 2)
        #expect(
            cmd.pushHttp[0]
                == "https://cdn.example.com/ingest"
        )
    }

    @Test("Parse with push headers")
    func parsePushHeaders() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--push-header", "Authorization:Bearer token123"
        ])
        #expect(cmd.pushHeader.count == 1)
        #expect(
            cmd.pushHeader[0]
                == "Authorization:Bearer token123"
        )
    }

    @Test("Parse with record flag")
    func parseRecord() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--record"
        ])
        #expect(cmd.record == true)
    }

    @Test("Parse with record directory")
    func parseRecordDir() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--record",
            "--record-dir", "/tmp/recordings"
        ])
        #expect(cmd.record == true)
        #expect(cmd.recordDir == "/tmp/recordings")
    }

    @Test("Parse with DVR flags")
    func parseDVR() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--dvr",
            "--dvr-hours", "4.0"
        ])
        #expect(cmd.dvr == true)
        #expect(cmd.dvrHours == 4.0)
    }

    @Test("Parse with quiet flag")
    func parseQuiet() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--quiet"
        ])
        #expect(cmd.quiet == true)
    }

    @Test("Parse with JSON output format")
    func parseOutputFormat() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Parse with list-presets flag")
    func parseListPresets() throws {
        let cmd = try LiveStartCommand.parse([
            "--list-presets"
        ])
        #expect(cmd.listPresets == true)
        #expect(cmd.output == nil)
    }

    @Test("Parse with all overrides")
    func parseAllOverrides() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "./live/",
            "--preset", "webradio",
            "--segment-duration", "4.0",
            "--audio-bitrate", "256",
            "--loudness=-16.0",
            "--format", "fmp4",
            "--push-http", "https://cdn.example.com",
            "--push-header", "Auth:token",
            "--record",
            "--record-dir", "/tmp/rec",
            "--dvr",
            "--dvr-hours", "2.0",
            "--quiet",
            "--output-format", "json"
        ])
        #expect(cmd.preset == "webradio")
        #expect(cmd.segmentDuration == 4.0)
        #expect(cmd.audioBitrate == 256)
        #expect(cmd.loudness == -16.0)
        #expect(cmd.format == "fmp4")
        #expect(cmd.pushHttp.count == 1)
        #expect(cmd.pushHeader.count == 1)
        #expect(cmd.record == true)
        #expect(cmd.recordDir == "/tmp/rec")
        #expect(cmd.dvr == true)
        #expect(cmd.dvrHours == 2.0)
        #expect(cmd.quiet == true)
        #expect(cmd.outputFormat == "json")
    }
}

// MARK: - Preset Mapping

@Suite("mapPreset — All 16 Presets")
struct MapPresetTests {

    @Test(
        "All 16 preset names map correctly",
        arguments: [
            "podcast-live", "webradio", "dj-mix",
            "low-bandwidth", "video-live",
            "low-latency-video", "video-simulcast",
            "video-4k", "video-4k-low-latency",
            "podcast-video", "video-live-dvr",
            "apple-podcast-live", "broadcast",
            "event-recording", "conference-stream",
            "dj-mix-dvr"
        ]
    )
    func validPresets(name: String) {
        let config = mapPreset(name)
        #expect(config != nil)
    }

    @Test("Unknown preset returns nil")
    func unknownPreset() {
        #expect(mapPreset("invalid-preset") == nil)
    }

    @Test("podcast-live maps to podcastLive config")
    func podcastLiveMapping() {
        let config = mapPreset("podcast-live")
        #expect(
            config == LivePipelineConfiguration.podcastLive
        )
    }

    @Test("broadcast maps to broadcast config")
    func broadcastMapping() {
        let config = mapPreset("broadcast")
        #expect(
            config
                == LivePipelineConfiguration.broadcast
        )
    }
}

// MARK: - LiveStopCommand

@Suite("LiveStopCommand — Argument Parsing")
struct LiveStopCommandTests {

    @Test("Parse with output")
    func parseOutput() throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "./live/"
        ])
        #expect(cmd.output == "./live/")
        #expect(cmd.convertToVod == false)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse with convert-to-vod flag")
    func parseConvertToVod() throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "./live/",
            "--convert-to-vod"
        ])
        #expect(cmd.convertToVod == true)
    }

    @Test("Parse with output-format json")
    func parseOutputFormat() throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "./live/",
            "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Parse missing output throws")
    func parseMissingOutput() {
        #expect(throws: (any Error).self) {
            _ = try LiveStopCommand.parse([])
        }
    }
}

// MARK: - LiveStatsCommand

@Suite("LiveStatsCommand — Argument Parsing")
struct LiveStatsCommandTests {

    @Test("Parse with output")
    func parseOutput() throws {
        let cmd = try LiveStatsCommand.parse([
            "--output", "./live/"
        ])
        #expect(cmd.output == "./live/")
        #expect(cmd.watch == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse with watch flag")
    func parseWatch() throws {
        let cmd = try LiveStatsCommand.parse([
            "--output", "./live/",
            "--watch"
        ])
        #expect(cmd.watch == true)
    }

    @Test("Parse with output-format json")
    func parseOutputFormat() throws {
        let cmd = try LiveStatsCommand.parse([
            "--output", "./live/",
            "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }
}

// MARK: - LiveConvertToVODCommand

@Suite("LiveConvertToVODCommand — Argument Parsing")
struct LiveConvertToVODCommandTests {

    @Test("Parse with playlist and output")
    func parseRequired() throws {
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", "live.m3u8",
            "--output", "vod.m3u8"
        ])
        #expect(cmd.playlist == "live.m3u8")
        #expect(cmd.output == "vod.m3u8")
        #expect(cmd.renumber == false)
        #expect(cmd.includeDateTime == false)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse with short -o output")
    func parseShortOutput() throws {
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", "live.m3u8",
            "-o", "vod.m3u8"
        ])
        #expect(cmd.output == "vod.m3u8")
    }

    @Test("Parse with renumber flag")
    func parseRenumber() throws {
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", "live.m3u8",
            "--output", "vod.m3u8",
            "--renumber"
        ])
        #expect(cmd.renumber == true)
    }

    @Test("Parse with include-date-time flag")
    func parseIncludeDateTime() throws {
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", "live.m3u8",
            "--output", "vod.m3u8",
            "--include-date-time"
        ])
        #expect(cmd.includeDateTime == true)
    }

    @Test("Parse missing playlist throws")
    func parseMissingPlaylist() {
        #expect(throws: (any Error).self) {
            _ = try LiveConvertToVODCommand.parse([
                "--output", "vod.m3u8"
            ])
        }
    }

    @Test("Parse missing output throws")
    func parseMissingOutput() {
        #expect(throws: (any Error).self) {
            _ = try LiveConvertToVODCommand.parse([
                "--playlist", "live.m3u8"
            ])
        }
    }
}

// MARK: - Integration

@Suite("LiveCommand — Integration")
struct LiveCommandIntegrationTests {

    @Test("LiveCommand has 4 subcommands")
    func subcommandCount() {
        let subs = LiveCommand.configuration.subcommands
        #expect(subs.count == 4)
    }

    @Test("HLSKitCommand includes LiveCommand")
    func rootIncludesLive() {
        let subs = HLSKitCommand.configuration.subcommands
        let hasLive = subs.contains {
            $0 == LiveCommand.self
        }
        #expect(hasLive)
    }
}
