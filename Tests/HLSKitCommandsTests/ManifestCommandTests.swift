// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

@Suite("ManifestCommand — Argument Parsing")
struct ManifestCommandTests {

    // MARK: - Parse Subcommand

    @Test("Parse manifest parse with file path")
    func parseSubcommand() throws {
        let cmd = try ManifestParseCommand.parse([
            "playlist.m3u8"
        ])
        #expect(cmd.input == "playlist.m3u8")
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse manifest parse with --output-format json")
    func parseJSONFormat() throws {
        let cmd = try ManifestParseCommand.parse([
            "playlist.m3u8", "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Parse manifest parse missing input throws")
    func parseMissingInput() {
        #expect(throws: (any Error).self) {
            _ = try ManifestParseCommand.parse([])
        }
    }

    // MARK: - Generate Subcommand

    @Test("Parse manifest generate with config file")
    func generateSubcommand() throws {
        let cmd = try ManifestGenerateCommand.parse([
            "config.json"
        ])
        #expect(cmd.input == "config.json")
        #expect(cmd.output == nil)
    }

    @Test("Parse manifest generate with --output")
    func generateWithOutput() throws {
        let cmd = try ManifestGenerateCommand.parse([
            "config.json", "--output", "master.m3u8"
        ])
        #expect(cmd.output == "master.m3u8")
    }

    @Test("Parse manifest generate with short -o")
    func generateWithShortOutput() throws {
        let cmd = try ManifestGenerateCommand.parse([
            "config.json", "-o", "master.m3u8"
        ])
        #expect(cmd.output == "master.m3u8")
    }

    @Test("Parse manifest generate missing input throws")
    func generateMissingInput() {
        #expect(throws: (any Error).self) {
            _ = try ManifestGenerateCommand.parse([])
        }
    }
}
