// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

@Suite("ValidateCommand — Argument Parsing")
struct ValidateCommandTests {

    @Test("Parse basic arguments with defaults")
    func parseBasicArgs() throws {
        let cmd = try ValidateCommand.parse(["playlist.m3u8"])
        #expect(cmd.input == "playlist.m3u8")
        #expect(cmd.strict == false)
        #expect(cmd.recursive == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse with --strict flag")
    func parseStrict() throws {
        let cmd = try ValidateCommand.parse([
            "playlist.m3u8", "--strict"
        ])
        #expect(cmd.strict == true)
    }

    @Test("Parse with --recursive flag")
    func parseRecursive() throws {
        let cmd = try ValidateCommand.parse([
            "./hls/", "--recursive"
        ])
        #expect(cmd.recursive == true)
    }

    @Test("Parse with --output-format json")
    func parseJSONFormat() throws {
        let cmd = try ValidateCommand.parse([
            "playlist.m3u8", "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Parse all flags combined")
    func parseAllFlags() throws {
        let cmd = try ValidateCommand.parse([
            "./hls/",
            "--strict",
            "--recursive",
            "--output-format", "json"
        ])
        #expect(cmd.strict == true)
        #expect(cmd.recursive == true)
        #expect(cmd.outputFormat == "json")
    }

    @Test("Missing required input throws")
    func missingInput() {
        #expect(throws: (any Error).self) {
            _ = try ValidateCommand.parse([])
        }
    }
}
