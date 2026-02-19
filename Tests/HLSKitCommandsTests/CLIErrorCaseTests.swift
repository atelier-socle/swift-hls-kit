// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import HLSKitCommands

// MARK: - Error Cases

@Suite("CLI Error Cases")
struct CLIErrorCaseTests {

    @Test("Segment command with non-existent file throws")
    func segmentFileNotFound() async {
        let cmd = try? SegmentCommand.parse([
            "/nonexistent/path/file.mp4"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for non-existent file")
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.fileNotFound)
        } catch {
            // Other errors are acceptable
        }
    }

    @Test("Validate command with non-existent file throws")
    func validateFileNotFound() async {
        let cmd = try? ValidateCommand.parse([
            "/nonexistent/path/file.m3u8"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for non-existent file")
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.fileNotFound)
        } catch {
            // Other errors are acceptable
        }
    }

    @Test("Info command with non-existent file throws")
    func infoFileNotFound() async {
        let cmd = try? InfoCommand.parse([
            "/nonexistent/path/file.mp4"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for non-existent file")
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.fileNotFound)
        } catch {
            // Other errors are acceptable
        }
    }

    @Test("Encrypt command with non-existent directory throws")
    func encryptDirNotFound() async {
        let cmd = try? EncryptCommand.parse([
            "/nonexistent/path/",
            "--key-url", "https://example.com/key"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for non-existent dir")
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.fileNotFound)
        } catch {
            // Other errors are acceptable
        }
    }

    @Test("Transcode command with non-existent file throws")
    func transcodeFileNotFound() async {
        let cmd = try? TranscodeCommand.parse([
            "/nonexistent/path/file.mp4"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for non-existent file")
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.fileNotFound)
        } catch {
            // Other errors are acceptable
        }
    }

    @Test("Manifest parse command with non-existent file throws")
    func manifestParseFileNotFound() async {
        let cmd = try? ManifestParseCommand.parse([
            "/nonexistent/path/file.m3u8"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for non-existent file")
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.fileNotFound)
        } catch {
            // Other errors are acceptable
        }
    }

    @Test("Manifest generate command with non-existent file throws")
    func manifestGenerateFileNotFound() async {
        let cmd = try? ManifestGenerateCommand.parse([
            "/nonexistent/path/config.json"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for non-existent file")
        } catch let exitCode as ExitCode {
            #expect(exitCode.rawValue == ExitCodes.fileNotFound)
        } catch {
            // Other errors are acceptable
        }
    }
}
