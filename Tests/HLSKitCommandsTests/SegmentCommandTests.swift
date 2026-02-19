// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

@Suite("SegmentCommand — Argument Parsing")
struct SegmentCommandTests {

    @Test("Parse basic arguments with defaults")
    func parseBasicArgs() throws {
        let cmd = try SegmentCommand.parse(["input.mp4"])
        #expect(cmd.input == "input.mp4")
        #expect(cmd.output == "./hls_output/")
        #expect(cmd.format == "fmp4")
        #expect(cmd.duration == 6.0)
        #expect(cmd.byteRange == false)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse all options")
    func parseAllOptions() throws {
        let cmd = try SegmentCommand.parse([
            "video.mp4",
            "--output", "./custom/",
            "--format", "ts",
            "--duration", "10",
            "--byte-range",
            "--quiet",
            "--output-format", "json"
        ])
        #expect(cmd.input == "video.mp4")
        #expect(cmd.output == "./custom/")
        #expect(cmd.format == "ts")
        #expect(cmd.duration == 10.0)
        #expect(cmd.byteRange == true)
        #expect(cmd.quiet == true)
        #expect(cmd.outputFormat == "json")
    }

    @Test("Short option names work")
    func shortOptions() throws {
        let cmd = try SegmentCommand.parse([
            "input.mp4",
            "-o", "./out/",
            "-d", "4.5"
        ])
        #expect(cmd.output == "./out/")
        #expect(cmd.duration == 4.5)
    }

    @Test("Missing required input throws")
    func missingInput() {
        #expect(throws: (any Error).self) {
            _ = try SegmentCommand.parse([])
        }
    }

    @Test("Format ts accepted")
    func formatTS() throws {
        let cmd = try SegmentCommand.parse([
            "input.mp4", "--format", "ts"
        ])
        #expect(cmd.format == "ts")
    }

    @Test("Format fmp4 accepted")
    func formatFmp4() throws {
        let cmd = try SegmentCommand.parse([
            "input.mp4", "--format", "fmp4"
        ])
        #expect(cmd.format == "fmp4")
    }
}
