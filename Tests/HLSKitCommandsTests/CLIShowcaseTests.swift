// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import HLSKitCommands

// MARK: - Root Command

@Suite("CLI Showcase — Root Command")
struct CLIRootShowcase {

    @Test("HLSKitCommand — has 6 subcommands")
    func subcommands() {
        let subs = HLSKitCommand.configuration.subcommands
        #expect(subs.count == 6)
    }

    @Test("HLSKitCommand — command name is 'hlskit-cli'")
    func commandName() {
        #expect(
            HLSKitCommand.configuration.commandName == "hlskit-cli"
        )
    }
}

// MARK: - Segment Command

@Suite("CLI Showcase — Segment Command")
struct SegmentCommandShowcase {

    @Test("SegmentCommand — parse with defaults")
    func parseDefaults() throws {
        let cmd = try SegmentCommand.parse(["input.mp4"])
        #expect(cmd.input == "input.mp4")
        #expect(cmd.output == "./hls_output/")
        #expect(cmd.format == "fmp4")
        #expect(cmd.duration == 6.0)
        #expect(cmd.byteRange == false)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("SegmentCommand — parse with all options")
    func parseAllOptions() throws {
        let cmd = try SegmentCommand.parse([
            "video.mp4",
            "--output", "/tmp/hls/",
            "--format", "ts",
            "--duration", "4.0",
            "--byte-range",
            "--quiet",
            "--output-format", "json"
        ])
        #expect(cmd.input == "video.mp4")
        #expect(cmd.output == "/tmp/hls/")
        #expect(cmd.format == "ts")
        #expect(cmd.duration == 4.0)
        #expect(cmd.byteRange == true)
        #expect(cmd.quiet == true)
        #expect(cmd.outputFormat == "json")
    }
}

// MARK: - Transcode Command

@Suite("CLI Showcase — Transcode Command")
struct TranscodeCommandShowcase {

    @Test("TranscodeCommand — parse with defaults")
    func parseDefaults() throws {
        let cmd = try TranscodeCommand.parse(["input.mp4"])
        #expect(cmd.input == "input.mp4")
        #expect(cmd.output == "./hls_output/")
        #expect(cmd.format == "fmp4")
        #expect(cmd.duration == 6.0)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("TranscodeCommand — parse with preset")
    func parsePreset() throws {
        let cmd = try TranscodeCommand.parse([
            "video.mp4",
            "--preset", "720p"
        ])
        #expect(cmd.preset == "720p")
    }

    @Test("TranscodeCommand — parse with comma-separated presets")
    func parseMultiplePresets() throws {
        let cmd = try TranscodeCommand.parse([
            "video.mp4",
            "--presets", "360p,720p,1080p"
        ])
        #expect(cmd.presets == "360p,720p,1080p")
    }

    @Test("TranscodeCommand — parse with ladder")
    func parseLadder() throws {
        let cmd = try TranscodeCommand.parse([
            "video.mp4",
            "--ladder", "standard"
        ])
        #expect(cmd.ladder == "standard")
    }
}

// MARK: - Validate Command

@Suite("CLI Showcase — Validate Command")
struct ValidateCommandShowcase {

    @Test("ValidateCommand — parse with defaults")
    func parseDefaults() throws {
        let cmd = try ValidateCommand.parse(["playlist.m3u8"])
        #expect(cmd.input == "playlist.m3u8")
        #expect(cmd.strict == false)
        #expect(cmd.recursive == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("ValidateCommand — parse with strict + recursive flags")
    func parseFlags() throws {
        let cmd = try ValidateCommand.parse([
            "/tmp/hls/",
            "--strict",
            "--recursive",
            "--output-format", "json"
        ])
        #expect(cmd.input == "/tmp/hls/")
        #expect(cmd.strict == true)
        #expect(cmd.recursive == true)
        #expect(cmd.outputFormat == "json")
    }
}

// MARK: - Info Command

@Suite("CLI Showcase — Info Command")
struct InfoCommandShowcase {

    @Test("InfoCommand — parse with defaults")
    func parseDefaults() throws {
        let cmd = try InfoCommand.parse(["video.mp4"])
        #expect(cmd.input == "video.mp4")
        #expect(cmd.outputFormat == "text")
    }

    @Test("InfoCommand — parse with JSON output")
    func parseJSON() throws {
        let cmd = try InfoCommand.parse([
            "playlist.m3u8",
            "--output-format", "json"
        ])
        #expect(cmd.input == "playlist.m3u8")
        #expect(cmd.outputFormat == "json")
    }
}

// MARK: - Encrypt Command

@Suite("CLI Showcase — Encrypt Command")
struct EncryptCommandShowcase {

    @Test("EncryptCommand — parse with required arguments")
    func parseRequired() throws {
        let cmd = try EncryptCommand.parse([
            "/tmp/hls/",
            "--key-url", "https://cdn.example.com/key"
        ])
        #expect(cmd.input == "/tmp/hls/")
        #expect(cmd.keyURL == "https://cdn.example.com/key")
        #expect(cmd.method == "aes-128")
        #expect(cmd.writeKey == false)
        #expect(cmd.quiet == false)
    }

    @Test("EncryptCommand — parse with all options")
    func parseAllOptions() throws {
        let cmd = try EncryptCommand.parse([
            "/tmp/hls/",
            "--key-url", "https://cdn.example.com/key",
            "--method", "sample-aes",
            "--key", "00112233445566778899aabbccddeeff",
            "--iv", "aabbccddeeff00112233445566778899",
            "--rotation", "10",
            "--write-key",
            "--quiet",
            "--output-format", "json"
        ])
        #expect(cmd.method == "sample-aes")
        #expect(cmd.key == "00112233445566778899aabbccddeeff")
        #expect(cmd.iv == "aabbccddeeff00112233445566778899")
        #expect(cmd.rotation == 10)
        #expect(cmd.writeKey == true)
        #expect(cmd.quiet == true)
        #expect(cmd.outputFormat == "json")
    }
}

// MARK: - Manifest Command

@Suite("CLI Showcase — Manifest Command")
struct ManifestCommandShowcase {

    @Test("ManifestCommand — has 2 subcommands (parse, generate)")
    func subcommands() {
        let subs = ManifestCommand.configuration.subcommands
        #expect(subs.count == 2)
    }

    @Test("ManifestParseCommand — parse with defaults")
    func parseSubcommand() throws {
        let cmd = try ManifestParseCommand.parse(["playlist.m3u8"])
        #expect(cmd.input == "playlist.m3u8")
        #expect(cmd.outputFormat == "text")
    }

    @Test("ManifestGenerateCommand — parse with output option")
    func generateSubcommand() throws {
        let cmd = try ManifestGenerateCommand.parse([
            "config.json",
            "--output", "/tmp/master.m3u8"
        ])
        #expect(cmd.input == "config.json")
        #expect(cmd.output == "/tmp/master.m3u8")
    }

    @Test("ManifestConfig — decode from JSON")
    func manifestConfig() throws {
        let json = """
            {
              "version": 7,
              "variants": [
                {
                  "uri": "360p/playlist.m3u8",
                  "bandwidth": 800000,
                  "resolution": {"width": 640, "height": 360}
                }
              ]
            }
            """
        let config = try JSONDecoder().decode(
            ManifestConfig.self, from: Data(json.utf8)
        )
        #expect(config.version == 7)
        #expect(config.variants.count == 1)
        #expect(config.variants[0].bandwidth == 800_000)
        #expect(config.variants[0].resolution?.width == 640)
    }
}
