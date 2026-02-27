// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
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

// MARK: - Test Fixture

private struct IFrameFixture {
    let dir: URL
    let playlist: URL
    let output: URL
}

private func createIFrameFixture() throws -> IFrameFixture {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "iframe_test_\(UUID().uuidString)"
        )
    try FileManager.default.createDirectory(
        at: dir, withIntermediateDirectories: true
    )
    let m3u8 = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-TARGETDURATION:6
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-MAP:URI="init.mp4"
        #EXTINF:6.000,
        segment_0.m4s
        #EXTINF:4.500,
        segment_1.m4s
        #EXT-X-ENDLIST
        """
    let playlistURL = dir.appendingPathComponent("stream.m3u8")
    try m3u8.write(
        to: playlistURL, atomically: true, encoding: .utf8
    )
    let outputURL = dir.appendingPathComponent("iframe.m3u8")
    return IFrameFixture(
        dir: dir, playlist: playlistURL, output: outputURL
    )
}

// MARK: - IFrameCommand Run Coverage

@Suite("IFrameCommand — Run Coverage")
struct IFrameRunCoverageTests {

    @Test("run() with minimal args generates I-frame playlist")
    func runMinimal() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path
        ])
        try await cmd.run()
        #expect(
            FileManager.default.fileExists(
                atPath: fix.output.path
            )
        )
    }

    @Test("run() with interval option")
    func runWithInterval() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path,
            "--interval", "2.0"
        ])
        try await cmd.run()
        #expect(
            FileManager.default.fileExists(
                atPath: fix.output.path
            )
        )
    }

    @Test("run() with byte-range flag")
    func runByteRange() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path,
            "--byte-range"
        ])
        try await cmd.run()
        #expect(
            FileManager.default.fileExists(
                atPath: fix.output.path
            )
        )
    }

    @Test("run() with thumbnail options")
    func runThumbnails() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path,
            "--thumbnail-output", "/tmp/thumbs/",
            "--thumbnail-size", "320x180"
        ])
        try await cmd.run()
        #expect(
            FileManager.default.fileExists(
                atPath: fix.output.path
            )
        )
    }

    @Test("run() with quiet suppresses output")
    func runQuiet() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path,
            "--quiet"
        ])
        try await cmd.run()
        #expect(
            FileManager.default.fileExists(
                atPath: fix.output.path
            )
        )
    }

    @Test("run() with JSON output format")
    func runJSON() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path,
            "--output-format", "json"
        ])
        try await cmd.run()
        #expect(
            FileManager.default.fileExists(
                atPath: fix.output.path
            )
        )
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

    @Test("run() with all options generates output")
    func runAllOptions() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path,
            "--interval", "3.0",
            "--thumbnail-output", "/tmp/thumbs/",
            "--thumbnail-size", "640x360",
            "--byte-range"
        ])
        try await cmd.run()
        #expect(
            FileManager.default.fileExists(
                atPath: fix.output.path
            )
        )
    }

    @Test("run() output contains I-FRAMES-ONLY tag")
    func outputContainsIFrameTag() async throws {
        let fix = try createIFrameFixture()
        defer {
            try? FileManager.default.removeItem(at: fix.dir)
        }
        let cmd = try IFrameCommand.parse([
            "--input", fix.playlist.path,
            "--output", fix.output.path,
            "--quiet"
        ])
        try await cmd.run()
        let content = try String(
            contentsOf: fix.output, encoding: .utf8
        )
        #expect(content.contains("#EXT-X-I-FRAMES-ONLY"))
        #expect(content.contains("#EXT-X-ENDLIST"))
        #expect(content.contains("segment_0.m4s"))
    }

    @Test("run() file not found throws")
    func runFileNotFound() async {
        do {
            let cmd = try IFrameCommand.parse([
                "--input",
                "/tmp/nonexistent_\(UUID()).m3u8",
                "--output", "/tmp/iframe.m3u8"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }
}
