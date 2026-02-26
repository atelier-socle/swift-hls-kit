// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

// MARK: - IFrameCommand Parsing

@Suite("IFrameCommand — Argument Parsing")
struct IFrameCommandTests {

    @Test("Parse with --input and --output")
    func parseInputOutput() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8"
        ])
        #expect(cmd.input == "/tmp/stream.m3u8")
        #expect(cmd.output == "/tmp/iframe.m3u8")
    }

    @Test("Parse with short -o for output")
    func parseShortOutput() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "-o", "/tmp/iframe.m3u8"
        ])
        #expect(cmd.output == "/tmp/iframe.m3u8")
    }

    @Test("Parse with --interval")
    func parseInterval() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--interval", "2.0"
        ])
        #expect(cmd.interval == 2.0)
    }

    @Test("Parse with --thumbnail-output")
    func parseThumbnailOutput() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--thumbnail-output", "/tmp/thumbnails/"
        ])
        #expect(cmd.thumbnailOutput == "/tmp/thumbnails/")
    }

    @Test("Parse with --thumbnail-size")
    func parseThumbnailSize() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--thumbnail-size", "320x180"
        ])
        #expect(cmd.thumbnailSize == "320x180")
    }

    @Test("Parse with --byte-range flag")
    func parseByteRange() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--byte-range"
        ])
        #expect(cmd.byteRange == true)
    }

    @Test("Parse with --quiet flag")
    func parseQuiet() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--quiet"
        ])
        #expect(cmd.quiet == true)
    }

    @Test("Parse with --output-format json")
    func parseOutputFormat() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("IFrameCommand is in HLSKitCommand subcommands")
    func inRootSubcommands() {
        let subs = HLSKitCommand.configuration.subcommands
        let hasIFrame = subs.contains {
            $0 == IFrameCommand.self
        }
        #expect(hasIFrame)
    }

    @Test("Minimal args have correct defaults")
    func minimalDefaults() throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8"
        ])
        #expect(cmd.interval == nil)
        #expect(cmd.thumbnailOutput == nil)
        #expect(cmd.thumbnailSize == nil)
        #expect(cmd.byteRange == false)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse missing input throws")
    func parseMissingInput() {
        #expect(throws: (any Error).self) {
            _ = try IFrameCommand.parse([
                "--output", "/tmp/iframe.m3u8"
            ])
        }
    }

    @Test("Parse missing output throws")
    func parseMissingOutput() {
        #expect(throws: (any Error).self) {
            _ = try IFrameCommand.parse([
                "--input", "/tmp/stream.m3u8"
            ])
        }
    }
}

// MARK: - IFrameCommand Run Coverage

@Suite("IFrameCommand — Run Coverage")
struct IFrameRunCoverageTests {

    @Test("run() with minimal args prints plan")
    func runMinimal() async throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8"
        ])
        try await cmd.run()
    }

    @Test("run() with interval option")
    func runWithInterval() async throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--interval", "2.0"
        ])
        try await cmd.run()
    }

    @Test("run() with byte-range flag")
    func runByteRange() async throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--byte-range"
        ])
        try await cmd.run()
    }

    @Test("run() with thumbnail options")
    func runThumbnails() async throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--thumbnail-output", "/tmp/thumbs/",
            "--thumbnail-size", "320x180"
        ])
        try await cmd.run()
    }

    @Test("run() with quiet suppresses output")
    func runQuiet() async throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() with JSON output format")
    func runJSON() async throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("run() with non-m3u8 input throws")
    func runInvalidInput() async {
        do {
            let cmd = try IFrameCommand.parse([
                "--input", "/tmp/stream.mp4",
                "--output", "/tmp/iframe.m3u8"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("run() with invalid thumbnail-size throws")
    func runInvalidSize() async {
        do {
            let cmd = try IFrameCommand.parse([
                "--input", "/tmp/stream.m3u8",
                "--output", "/tmp/iframe.m3u8",
                "--thumbnail-size", "invalid"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("run() with all options")
    func runAllOptions() async throws {
        let cmd = try IFrameCommand.parse([
            "--input", "/tmp/stream.m3u8",
            "--output", "/tmp/iframe.m3u8",
            "--interval", "3.0",
            "--thumbnail-output", "/tmp/thumbs/",
            "--thumbnail-size", "640x360",
            "--byte-range"
        ])
        try await cmd.run()
    }
}
