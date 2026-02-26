// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

// MARK: - LiveMetadataCommand Parsing

@Suite("LiveMetadataCommand — Argument Parsing")
struct LiveMetadataCommandTests {

    @Test("Parse with --title")
    func parseTitle() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "My Song"
        ])
        #expect(cmd.title == "My Song")
        #expect(cmd.output == "/tmp/live/")
    }

    @Test("Parse with --artist")
    func parseArtist() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--artist", "The Band"
        ])
        #expect(cmd.artist == "The Band")
    }

    @Test("Parse with --album")
    func parseAlbum() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--album", "Greatest Hits"
        ])
        #expect(cmd.album == "Greatest Hits")
    }

    @Test("Parse with all ID3 options")
    func parseAllID3() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Song",
            "--artist", "Artist",
            "--album", "Album"
        ])
        #expect(cmd.title == "Song")
        #expect(cmd.artist == "Artist")
        #expect(cmd.album == "Album")
    }

    @Test("Parse with --daterange flag")
    func parseDaterange() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--daterange"
        ])
        #expect(cmd.daterange == true)
    }

    @Test("Parse with daterange and options")
    func parseDaterangeWithOptions() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--daterange",
            "--daterange-class", "com.example",
            "--duration", "30"
        ])
        #expect(cmd.daterange == true)
        #expect(cmd.daterangeClass == "com.example")
        #expect(cmd.duration == 30)
    }

    @Test("Parse with --daterange --id")
    func parseDaterangeWithID() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--daterange",
            "--id", "custom-id"
        ])
        #expect(cmd.id == "custom-id")
    }

    @Test("Parse with --scte35 flag")
    func parseSCTE35() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35"
        ])
        #expect(cmd.scte35 == true)
    }

    @Test("Parse with --scte35 --splice-type in")
    func parseSCTE35SpliceTypeIn() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35",
            "--splice-type", "in"
        ])
        #expect(cmd.spliceType == "in")
    }

    @Test("Parse with --scte35 --duration --id")
    func parseSCTE35WithDurationAndID() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35",
            "--duration", "60",
            "--id", "ad-1"
        ])
        #expect(cmd.scte35 == true)
        #expect(cmd.duration == 60)
        #expect(cmd.id == "ad-1")
    }

    @Test("Parse with --interstitial --asset-url")
    func parseInterstitial() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--interstitial",
            "--asset-url",
            "https://cdn.example.com/ad.m3u8"
        ])
        #expect(cmd.interstitial == true)
        #expect(
            cmd.assetUrl
                == "https://cdn.example.com/ad.m3u8"
        )
    }

    @Test("Parse with --interstitial --resume-offset")
    func parseInterstitialResumeOffset() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--interstitial",
            "--asset-url", "https://example.com/ad.m3u8",
            "--resume-offset", "0"
        ])
        #expect(cmd.resumeOffset == 0)
    }

    @Test("Parse with --quiet flag")
    func parseQuiet() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Test",
            "--quiet"
        ])
        #expect(cmd.quiet == true)
    }

    @Test("Parse with --output-format json")
    func parseOutputFormat() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Test",
            "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Default splice-type is out")
    func defaultSpliceType() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35"
        ])
        #expect(cmd.spliceType == "out")
    }

    @Test("Default output-format is text")
    func defaultOutputFormat() throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Test"
        ])
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse missing output throws")
    func parseMissingOutput() {
        #expect(throws: (any Error).self) {
            _ = try LiveMetadataCommand.parse([
                "--title", "Test"
            ])
        }
    }
}

// MARK: - LiveMetadataCommand Run Coverage

@Suite("LiveMetadataCommand — Run Coverage")
struct LiveMetadataRunCoverageTests {

    @Test("run() with ID3 title prints metadata")
    func runTitle() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Test Track"
        ])
        try await cmd.run()
    }

    @Test("run() with all ID3 fields")
    func runAllID3() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Song",
            "--artist", "Artist",
            "--album", "Album"
        ])
        try await cmd.run()
    }

    @Test("run() with daterange prints DATERANGE info")
    func runDaterange() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--daterange",
            "--daterange-class", "com.example",
            "--duration", "30",
            "--id", "dr-001"
        ])
        try await cmd.run()
    }

    @Test("run() with SCTE-35 out splice")
    func runSCTE35Out() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35",
            "--duration", "60",
            "--id", "ad-1"
        ])
        try await cmd.run()
    }

    @Test("run() with SCTE-35 in splice")
    func runSCTE35In() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35",
            "--splice-type", "in"
        ])
        try await cmd.run()
    }

    @Test("run() with interstitial prints details")
    func runInterstitial() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--interstitial",
            "--asset-url",
            "https://cdn.example.com/ad.m3u8",
            "--resume-offset", "0"
        ])
        try await cmd.run()
    }

    @Test("run() with quiet suppresses output")
    func runQuiet() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--title", "Test",
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() with JSON output format")
    func runJSON() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--scte35",
            "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("run() without metadata type throws")
    func runNoMetadata() async {
        do {
            let cmd = try LiveMetadataCommand.parse([
                "--output", "/tmp/live/"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("run() with interstitial without asset-url throws")
    func runInterstitialNoURL() async {
        do {
            let cmd = try LiveMetadataCommand.parse([
                "--output", "/tmp/live/",
                "--interstitial"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("run() with daterange flag only")
    func runDaterangeOnly() async throws {
        let cmd = try LiveMetadataCommand.parse([
            "--output", "/tmp/live/",
            "--daterange"
        ])
        try await cmd.run()
    }
}
