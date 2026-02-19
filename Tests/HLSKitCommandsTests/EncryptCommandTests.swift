// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKitCommands

@Suite("EncryptCommand — Argument Parsing")
struct EncryptCommandTests {

    @Test("Parse with directory and --key-url")
    func parseBasicArgs() throws {
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--key-url", "https://example.com/key.bin"
        ])
        #expect(cmd.input == "./hls/")
        #expect(cmd.keyURL == "https://example.com/key.bin")
        #expect(cmd.method == "aes-128")
        #expect(cmd.key == nil)
        #expect(cmd.iv == nil)
        #expect(cmd.rotation == nil)
        #expect(cmd.writeKey == false)
        #expect(cmd.quiet == false)
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse with --method aes-128")
    func parseMethodAES128() throws {
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--key-url", "https://example.com/key.bin",
            "--method", "aes-128"
        ])
        #expect(cmd.method == "aes-128")
    }

    @Test("Parse with --method sample-aes")
    func parseMethodSampleAES() throws {
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--key-url", "https://example.com/key.bin",
            "--method", "sample-aes"
        ])
        #expect(cmd.method == "sample-aes")
    }

    @Test("Parse with --key hex string")
    func parseKeyHex() throws {
        let hex = "00112233445566778899aabbccddeeff"
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--key-url", "https://example.com/key.bin",
            "--key", hex
        ])
        #expect(cmd.key == hex)
    }

    @Test("Parse with --iv hex string")
    func parseIVHex() throws {
        let hex = "aabbccddeeff00112233445566778899"
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--key-url", "https://example.com/key.bin",
            "--iv", hex
        ])
        #expect(cmd.iv == hex)
    }

    @Test("Parse with --rotation interval")
    func parseRotation() throws {
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--key-url", "https://example.com/key.bin",
            "--rotation", "10"
        ])
        #expect(cmd.rotation == 10)
    }

    @Test("Parse with --write-key flag")
    func parseWriteKey() throws {
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--key-url", "https://example.com/key.bin",
            "--write-key"
        ])
        #expect(cmd.writeKey == true)
    }

    @Test("Parse all options combined")
    func parseAllOptions() throws {
        let cmd = try EncryptCommand.parse([
            "./hls/",
            "--method", "sample-aes",
            "--key-url", "https://example.com/key.bin",
            "--key", "00112233445566778899aabbccddeeff",
            "--iv", "aabbccddeeff00112233445566778899",
            "--rotation", "5",
            "--write-key",
            "--quiet",
            "--output-format", "json"
        ])
        #expect(cmd.method == "sample-aes")
        #expect(cmd.key != nil)
        #expect(cmd.iv != nil)
        #expect(cmd.rotation == 5)
        #expect(cmd.writeKey == true)
        #expect(cmd.quiet == true)
        #expect(cmd.outputFormat == "json")
    }

    @Test("Missing --key-url throws")
    func missingKeyURL() {
        #expect(throws: (any Error).self) {
            _ = try EncryptCommand.parse(["./hls/"])
        }
    }

    @Test("Missing required input throws")
    func missingInput() {
        #expect(throws: (any Error).self) {
            _ = try EncryptCommand.parse([])
        }
    }
}
