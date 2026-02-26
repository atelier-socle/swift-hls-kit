// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - CLI Live Integration

@Suite("CLI Live — Integration Tests")
struct CLILiveIntegrationTests {

    @Test("HLSKitCommand has 8 subcommands")
    func rootSubcommandCount() {
        let subs = HLSKitCommand.configuration.subcommands
        #expect(subs.count == 8)
    }

    @Test("LiveCommand has 5 subcommands")
    func liveSubcommandCount() {
        let subs = LiveCommand.configuration.subcommands
        #expect(subs.count == 5)
    }

    @Test("Full podcast workflow parsing")
    func podcastWorkflow() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/podcast/",
            "--preset", "podcast-live",
            "--record"
        ])
        #expect(cmd.output == "/tmp/podcast/")
        #expect(cmd.preset == "podcast-live")
        #expect(cmd.record == true)
        let config = mapPreset(cmd.preset)
        #expect(config != nil)
    }

    @Test("Full broadcast workflow parsing")
    func broadcastWorkflow() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/broadcast/",
            "--preset", "broadcast",
            "--dvr",
            "--dvr-hours", "4",
            "--push-http",
            "https://cdn.example.com/"
        ])
        #expect(cmd.preset == "broadcast")
        #expect(cmd.dvr == true)
        #expect(cmd.dvrHours == 4.0)
        #expect(cmd.pushHttp.count == 1)
    }

    @Test("Metadata injection parsing")
    func metadataInjection() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35",
            "--duration", "30",
            "--id", "ad-break"
        ])
        #expect(cmd.scte35 == true)
        #expect(cmd.duration == 30)
        #expect(cmd.id == "ad-break")
    }

    @Test("VOD conversion chain")
    func vodConversion() throws {
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", "/tmp/stream.m3u8",
            "--output", "/tmp/vod/",
            "--renumber"
        ])
        #expect(cmd.playlist == "/tmp/stream.m3u8")
        #expect(cmd.output == "/tmp/vod/")
        #expect(cmd.renumber == true)
    }

    @Test("I-frame extraction parsing")
    func iframeExtraction() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--interval", "2",
            "--byte-range"
        ])
        #expect(cmd.input == "/tmp/stream.m3u8")
        #expect(cmd.output == "/tmp/iframe.m3u8")
        #expect(cmd.interval == 2.0)
        #expect(cmd.byteRange == true)
    }

    @Test(
        "All preset names produce configurations",
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
    func allPresetsValid(name: String) {
        #expect(mapPreset(name) != nil)
    }

    @Test("Stats with JSON output format")
    func statsJsonFormat() throws {
        let cmd = try LiveStatsCommand.parse([
            "--output", "/tmp/live/",
            "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Metadata with JSON output format")
    func metadataJsonFormat() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Test",
            "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
        #expect(cmd.title == "Test")
    }

    @Test("Stop with VOD conversion")
    func stopWithVod() throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "/tmp/live/",
            "--convert-to-vod"
        ])
        #expect(cmd.convertToVod == true)
    }

    @Test("Root subcommands contain all expected types")
    func rootSubcommandTypes() {
        let subs = HLSKitCommand.configuration.subcommands
        let names = subs.map {
            $0.configuration.commandName ?? ""
        }
        #expect(names.contains("segment"))
        #expect(names.contains("transcode"))
        #expect(names.contains("validate"))
        #expect(names.contains("info"))
        #expect(names.contains("encrypt"))
        #expect(names.contains("manifest"))
        #expect(names.contains("live"))
        #expect(names.contains("iframe"))
    }

    @Test("Live subcommands contain all expected types")
    func liveSubcommandTypes() {
        let subs = LiveCommand.configuration.subcommands
        let names = subs.map {
            $0.configuration.commandName ?? ""
        }
        #expect(names.contains("start"))
        #expect(names.contains("stop"))
        #expect(names.contains("stats"))
        #expect(names.contains("convert-to-vod"))
        #expect(names.contains("metadata"))
    }

    @Test("Metadata daterange with full options")
    func metadataDaterangeFull() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--daterange",
            "--daterange-class", "com.example.ad",
            "--duration", "30",
            "--id", "ad-001"
        ])
        #expect(cmd.daterange == true)
        #expect(cmd.daterangeClass == "com.example.ad")
        #expect(cmd.duration == 30.0)
        #expect(cmd.id == "ad-001")
    }

    @Test("I-frame with thumbnail options")
    func iframeThumbnails() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--thumbnail-output", "/tmp/thumbs/",
            "--thumbnail-size", "320x180"
        ])
        #expect(cmd.thumbnailOutput == "/tmp/thumbs/")
        #expect(cmd.thumbnailSize == "320x180")
    }
}
