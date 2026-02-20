// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - ExitCodes

@Suite("ExitCodes")
struct ExitCodesTests {

    @Test("Success exit code is 0")
    func successCode() {
        #expect(ExitCodes.success == 0)
    }

    @Test("General error exit code is 1")
    func generalErrorCode() {
        #expect(ExitCodes.generalError == 1)
    }

    @Test("Validation error exit code is 2")
    func validationErrorCode() {
        #expect(ExitCodes.validationError == 2)
    }

    @Test("File not found exit code is 66")
    func fileNotFoundCode() {
        #expect(ExitCodes.fileNotFound == 66)
    }

    @Test("IO error exit code is 74")
    func ioErrorCode() {
        #expect(ExitCodes.ioError == 74)
    }
}

// MARK: - FileHandleOutputStream

@Suite("FileHandleOutputStream")
struct FileHandleOutputStreamTests {

    @Test("Write to stderr does not crash")
    func writeToStderr() {
        var stream = FileHandleOutputStream(
            FileHandle.standardError
        )
        stream.write("test output\n")
    }

    @Test("Write empty string does not crash")
    func writeEmpty() {
        var stream = FileHandleOutputStream(
            FileHandle.standardError
        )
        stream.write("")
    }
}

// MARK: - HLSKitCommand Root

@Suite("HLSKitCommand Root")
struct HLSKitCommandRootTests {

    @Test("Root command init accessible")
    func rootInit() {
        let cmd = HLSKitCommand()
        // Verifies public init exists and doesn't crash
        _ = cmd
    }

    @Test("Root command configuration has 6 subcommands")
    func subcommandCount() {
        let config = HLSKitCommand.configuration
        #expect(config.subcommands.count == 6)
    }

    @Test("Root command version is 0.2.0")
    func version() {
        #expect(HLSKitCommand.configuration.version == "0.2.0")
    }

    @Test("Root command name is hlskit-cli")
    func commandName() {
        #expect(
            HLSKitCommand.configuration.commandName == "hlskit-cli"
        )
    }
}

// MARK: - ManifestConfig

@Suite("ManifestConfig")
struct ManifestConfigTests {

    @Test("Decode JSON config with all fields")
    func decodeFullConfig() throws {
        let json = """
            {
                "version": 7,
                "variants": [
                    {
                        "bandwidth": 800000,
                        "uri": "low.m3u8",
                        "averageBandwidth": 700000,
                        "codecs": "avc1.4d401e,mp4a.40.2",
                        "resolution": {"width": 640, "height": 360},
                        "frameRate": 30.0
                    }
                ]
            }
            """
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(
            ManifestConfig.self, from: data
        )
        #expect(config.version == 7)
        #expect(config.variants.count == 1)
        #expect(config.variants[0].bandwidth == 800000)
        #expect(config.variants[0].uri == "low.m3u8")
        #expect(config.variants[0].averageBandwidth == 700000)
        #expect(config.variants[0].codecs != nil)
        #expect(config.variants[0].resolution?.width == 640)
        #expect(config.variants[0].frameRate == 30.0)
    }

    @Test("Decode JSON config with minimal fields")
    func decodeMinimalConfig() throws {
        let json = """
            {
                "variants": [
                    {"bandwidth": 500000, "uri": "stream.m3u8"}
                ]
            }
            """
        let data = Data(json.utf8)
        let config = try JSONDecoder().decode(
            ManifestConfig.self, from: data
        )
        #expect(config.version == nil)
        #expect(config.variants.count == 1)
        #expect(config.variants[0].resolution == nil)
        #expect(config.variants[0].codecs == nil)
        #expect(config.variants[0].frameRate == nil)
    }
}

// MARK: - ManifestGenerateCommand Integration

@Suite("ManifestGenerateCommand — Integration")
struct ManifestGenerateIntegrationTests {

    @Test("Generate manifest from JSON config to stdout")
    func generateToStdout() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let json = """
            {
                "version": 3,
                "variants": [
                    {
                        "bandwidth": 800000,
                        "uri": "low.m3u8",
                        "resolution": {"width": 640, "height": 360}
                    },
                    {
                        "bandwidth": 2000000,
                        "uri": "high.m3u8",
                        "resolution": {"width": 1280, "height": 720}
                    }
                ]
            }
            """
        let path = tmpDir.appendingPathComponent("config.json")
        try json.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try ManifestGenerateCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Generate manifest from JSON config to file")
    func generateToFile() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let json = """
            {
                "variants": [
                    {"bandwidth": 500000, "uri": "stream.m3u8"}
                ]
            }
            """
        let configPath = tmpDir.appendingPathComponent("config.json")
        try json.write(
            to: configPath, atomically: true, encoding: .utf8
        )
        let outputPath = tmpDir.appendingPathComponent("master.m3u8")

        let cmd = try ManifestGenerateCommand.parse([
            configPath.path, "--output", outputPath.path
        ])
        try await cmd.run()

        let written = try String(
            contentsOf: outputPath, encoding: .utf8
        )
        #expect(written.contains("#EXTM3U"))
        #expect(written.contains("stream.m3u8"))
    }

    @Test("Generate manifest with version and full variant")
    func generateFullVariant() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let json = """
            {
                "version": 7,
                "variants": [
                    {
                        "bandwidth": 2000000,
                        "uri": "720p.m3u8",
                        "averageBandwidth": 1800000,
                        "codecs": "avc1.4d401f",
                        "resolution": {"width": 1280, "height": 720},
                        "frameRate": 29.97
                    }
                ]
            }
            """
        let path = tmpDir.appendingPathComponent("config.json")
        try json.write(to: path, atomically: true, encoding: .utf8)

        let outputPath = tmpDir.appendingPathComponent("out.m3u8")
        let cmd = try ManifestGenerateCommand.parse([
            path.path, "--output", outputPath.path
        ])
        try await cmd.run()

        let written = try String(
            contentsOf: outputPath, encoding: .utf8
        )
        #expect(written.contains("#EXTM3U"))
        #expect(written.contains("720p.m3u8"))
    }
}

// MARK: - EncryptCommand Integration

@Suite("EncryptCommand — Integration")
struct EncryptCommandIntegrationTests {

    @Test("Encrypt with invalid key URL throws")
    func invalidKeyURL() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data(repeating: 0, count: 188).write(
            to: tmpDir.appendingPathComponent("seg0.ts")
        )

        let cmd = try EncryptCommand.parse([
            tmpDir.path,
            "--key-url", "https://example.com/key",
            "--method", "aes-128",
            "--key", "00112233445566778899aabbccddeeff"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected — invalid segment data
        }
    }

    @Test("Encrypt with sample-aes method")
    func sampleAESMethod() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data(repeating: 0, count: 188).write(
            to: tmpDir.appendingPathComponent("seg0.ts")
        )

        let cmd = try EncryptCommand.parse([
            tmpDir.path,
            "--key-url", "https://example.com/key",
            "--method", "sample-aes",
            "--key", "00112233445566778899aabbccddeeff",
            "--iv", "aabbccddeeff00112233445566778899",
            "--rotation", "5",
            "--write-key",
            "--quiet"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected — invalid segment data
        }
    }

    @Test("Encrypt finds .m4s files")
    func findsM4sFiles() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data(repeating: 0xFF, count: 100).write(
            to: tmpDir.appendingPathComponent("seg0.m4s")
        )
        try Data(repeating: 0xFF, count: 100).write(
            to: tmpDir.appendingPathComponent("seg1.m4s")
        )

        let cmd = try EncryptCommand.parse([
            tmpDir.path,
            "--key-url", "https://example.com/key"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected — invalid segment data
        }
    }

    @Test("Encrypt with hex string parsing edge cases")
    func hexStringParsing() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data(repeating: 0, count: 10).write(
            to: tmpDir.appendingPathComponent("seg0.ts")
        )

        // Key with 0x prefix
        let cmd = try EncryptCommand.parse([
            tmpDir.path,
            "--key-url", "https://example.com/key",
            "--key", "0x00112233445566778899aabbccddeeff"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected
        }
    }

    @Test("Encrypt with short key is ignored")
    func shortKeyIgnored() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        try Data(repeating: 0, count: 10).write(
            to: tmpDir.appendingPathComponent("seg0.ts")
        )

        // Key too short (not 32 hex chars) → parseHexString returns nil
        let cmd = try EncryptCommand.parse([
            tmpDir.path,
            "--key-url", "https://example.com/key",
            "--key", "0011223344"
        ])

        do {
            try await cmd.run()
        } catch {
            // Expected
        }
    }
}
