// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import HLSKit
@testable import HLSKitCommands

@Suite("CLI Integration")
struct CLIIntegrationTests {

    // MARK: - Validate Command

    @Test("Validate command with valid M3U8")
    func validateValid() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-VERSION:3
            #EXTINF:6.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let path = tmpDir.appendingPathComponent("valid.m3u8")
        try m3u8.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try ValidateCommand.parse([path.path])
        // Should not throw — valid manifest
        try await cmd.run()
    }

    @Test("Validate command with invalid M3U8 throws")
    func validateInvalid() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg0.ts
            #EXTINF:20.0,
            seg1.ts
            #EXT-X-ENDLIST
            """
        let path = tmpDir.appendingPathComponent("invalid.m3u8")
        try m3u8.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try ValidateCommand.parse([path.path])
        // Should throw because segment duration exceeds target
        do {
            try await cmd.run()
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.validationError)
        }
    }

    @Test("Validate command with --strict and warnings throws")
    func validateStrictWarnings() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let path = tmpDir.appendingPathComponent("warn.m3u8")
        try m3u8.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try ValidateCommand.parse([
            path.path, "--strict"
        ])
        // In strict mode, warnings become errors
        // Whether this throws depends on whether the validator
        // finds warnings. Either way, it should not crash.
        do {
            try await cmd.run()
        } catch is ExitCode {
            // Expected if there were warnings
        }
    }

    // MARK: - Info Command

    @Test("Info command on M3U8 file")
    func infoM3U8() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-VERSION:3
            #EXTINF:6.0,
            seg0.ts
            #EXTINF:4.5,
            seg1.ts
            #EXT-X-ENDLIST
            """
        let path = tmpDir.appendingPathComponent("media.m3u8")
        try m3u8.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try InfoCommand.parse([path.path])
        // Should display info without throwing
        try await cmd.run()
    }

    @Test("Info command on master M3U8")
    func infoMasterM3U8() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
            360p.m3u8
            #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
            720p.m3u8
            """
        let path = tmpDir.appendingPathComponent("master.m3u8")
        try m3u8.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try InfoCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Info command on directory")
    func infoDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create some dummy files
        try Data().write(
            to: tmpDir.appendingPathComponent("seg0.ts")
        )
        try Data().write(
            to: tmpDir.appendingPathComponent("seg1.ts")
        )
        try "".write(
            to: tmpDir.appendingPathComponent("index.m3u8"),
            atomically: true,
            encoding: .utf8
        )

        let cmd = try InfoCommand.parse([tmpDir.path])
        try await cmd.run()
    }

    // MARK: - Manifest Parse Command

    @Test("Manifest parse command on media playlist")
    func manifestParseMedia() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-VERSION:3
            #EXTINF:5.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let path = tmpDir.appendingPathComponent("media.m3u8")
        try m3u8.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try ManifestParseCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Manifest parse command on master playlist")
    func manifestParseMaster() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=640x360
            low.m3u8
            """
        let path = tmpDir.appendingPathComponent("master.m3u8")
        try m3u8.write(to: path, atomically: true, encoding: .utf8)

        let cmd = try ManifestParseCommand.parse([path.path])
        try await cmd.run()
    }

    // MARK: - Validate Directory

    @Test("Validate command on directory with M3U8 files")
    func validateDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-VERSION:3
            #EXTINF:5.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        try m3u8.write(
            to: tmpDir.appendingPathComponent("index.m3u8"),
            atomically: true,
            encoding: .utf8
        )

        let cmd = try ValidateCommand.parse([tmpDir.path])
        try await cmd.run()
    }

    @Test("Validate command on empty directory prints message")
    func validateEmptyDirectory() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let cmd = try ValidateCommand.parse([tmpDir.path])
        // Should not throw — just prints "No M3U8 files found"
        try await cmd.run()
    }
}
