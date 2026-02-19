// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

@Suite("TranscodeCommand — Argument Parsing")
struct TranscodeCommandTests {

    @Test("Parse basic arguments with defaults")
    func parseBasicArgs() throws {
        let cmd = try TranscodeCommand.parse(["input.mp4"])
        #expect(cmd.input == "input.mp4")
        #expect(cmd.output == "./hls_output/")
        #expect(cmd.preset == nil)
        #expect(cmd.presets == nil)
        #expect(cmd.ladder == nil)
        #expect(cmd.format == "fmp4")
        #expect(cmd.duration == 6.0)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse with --preset 720p")
    func parsePreset720p() throws {
        let cmd = try TranscodeCommand.parse([
            "input.mp4", "--preset", "720p"
        ])
        #expect(cmd.preset == "720p")
    }

    @Test("Parse with --presets comma-separated")
    func parseMultiplePresets() throws {
        let cmd = try TranscodeCommand.parse([
            "input.mp4", "--presets", "480p,720p,1080p"
        ])
        #expect(cmd.presets == "480p,720p,1080p")
    }

    @Test("Parse with --ladder standard")
    func parseLadderStandard() throws {
        let cmd = try TranscodeCommand.parse([
            "input.mp4", "--ladder", "standard"
        ])
        #expect(cmd.ladder == "standard")
    }

    @Test("Parse with --ladder full")
    func parseLadderFull() throws {
        let cmd = try TranscodeCommand.parse([
            "input.mp4", "--ladder", "full"
        ])
        #expect(cmd.ladder == "full")
    }

    @Test("Parse all options")
    func parseAllOptions() throws {
        let cmd = try TranscodeCommand.parse([
            "video.mp4",
            "--output", "./out/",
            "--preset", "1080p",
            "--format", "ts",
            "--duration", "4",
            "--quiet",
            "--output-format", "json"
        ])
        #expect(cmd.output == "./out/")
        #expect(cmd.preset == "1080p")
        #expect(cmd.format == "ts")
        #expect(cmd.duration == 4.0)
        #expect(cmd.quiet == true)
        #expect(cmd.outputFormat == "json")
    }

    @Test("Short option names work")
    func shortOptions() throws {
        let cmd = try TranscodeCommand.parse([
            "input.mp4",
            "-o", "./out/",
            "-d", "8"
        ])
        #expect(cmd.output == "./out/")
        #expect(cmd.duration == 8.0)
    }

    @Test("Missing required input throws")
    func missingInput() {
        #expect(throws: (any Error).self) {
            _ = try TranscodeCommand.parse([])
        }
    }
}
