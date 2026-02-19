// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

@Suite("InfoCommand — Argument Parsing")
struct InfoCommandTests {

    @Test("Parse basic arguments with defaults")
    func parseBasicArgs() throws {
        let cmd = try InfoCommand.parse(["input.mp4"])
        #expect(cmd.input == "input.mp4")
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse with --output-format json")
    func parseJSONFormat() throws {
        let cmd = try InfoCommand.parse([
            "playlist.m3u8", "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Parse with directory path")
    func parseDirectory() throws {
        let cmd = try InfoCommand.parse(["./hls_output/"])
        #expect(cmd.input == "./hls_output/")
    }

    @Test("Missing required input throws")
    func missingInput() {
        #expect(throws: (any Error).self) {
            _ = try InfoCommand.parse([])
        }
    }
}
