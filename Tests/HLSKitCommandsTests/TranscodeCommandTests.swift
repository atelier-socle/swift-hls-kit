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

    @Test("No arguments parses with nil input (for --list-presets)")
    func noArgsNilInput() throws {
        let cmd = try TranscodeCommand.parse([])
        #expect(cmd.input == nil)
        #expect(cmd.listPresets == false)
    }

    @Test("Parse --list-presets flag")
    func parseListPresets() throws {
        let cmd = try TranscodeCommand.parse(["--list-presets"])
        #expect(cmd.listPresets == true)
        #expect(cmd.input == nil)
    }

    @Test("Parse --timeout flag with default")
    func parseTimeoutDefault() throws {
        let cmd = try TranscodeCommand.parse(["input.mp4"])
        #expect(cmd.timeout == 300)
    }

    @Test("Parse --timeout flag with custom value")
    func parseTimeoutCustom() throws {
        let cmd = try TranscodeCommand.parse([
            "input.mp4", "--timeout", "60"
        ])
        #expect(cmd.timeout == 60)
    }

    @Test("Parse --timeout 0 disables timeout")
    func parseTimeoutZero() throws {
        let cmd = try TranscodeCommand.parse([
            "input.mp4", "--timeout", "0"
        ])
        #expect(cmd.timeout == 0)
    }

    @Test("Preset aliases: low, medium, high")
    func presetAliases() throws {
        let low = try TranscodeCommand.parse([
            "input.mp4", "--preset", "low"
        ])
        #expect(low.preset == "low")

        let med = try TranscodeCommand.parse([
            "input.mp4", "--preset", "medium"
        ])
        #expect(med.preset == "medium")

        let high = try TranscodeCommand.parse([
            "input.mp4", "--preset", "high"
        ])
        #expect(high.preset == "high")
    }
}
