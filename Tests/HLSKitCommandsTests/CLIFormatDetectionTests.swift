// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import HLSKitCommands

// MARK: - Segment Format Detection

@Suite("Segment Format Detection")
struct SegmentFormatDetectionTests {

    @Test("segment accepts MP3 for auto-transcode")
    func acceptsMP3() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a fake MP3 file (ID3 header)
        let mp3File = tmpDir.appendingPathComponent("test.mp3")
        var mp3Data = Data([0xFF, 0xFB, 0x90, 0x00])
        mp3Data.append(Data(repeating: 0, count: 100))
        try mp3Data.write(to: mp3File)

        let cmd = try SegmentCommand.parse([
            mp3File.path, "-o", tmpDir.path
        ])
        do {
            try await cmd.run()
        } catch let exitCode as ExitCode {
            // MP3 is NOT rejected as a format error — it goes
            // through auto-transcode which may fail on fake data
            #expect(
                exitCode.rawValue != ExitCodes.validationError
            )
        } catch {
            // Transcode/parse errors are expected for fake data
        }
    }

    @Test("segment accepts WAV for auto-transcode")
    func acceptsWAV() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let wavFile = tmpDir.appendingPathComponent("test.wav")
        var wavData = Data("RIFF".utf8)
        wavData.append(Data(repeating: 0, count: 100))
        try wavData.write(to: wavFile)

        let cmd = try SegmentCommand.parse([
            wavFile.path, "-o", tmpDir.path
        ])
        do {
            try await cmd.run()
        } catch let exitCode as ExitCode {
            // WAV is NOT rejected as a format error — it goes
            // through auto-transcode which may fail on fake data
            #expect(
                exitCode.rawValue != ExitCodes.validationError
            )
        } catch {
            // Transcode/parse errors are expected for fake data
        }
    }

    @Test("segment accepts MP4 file extension")
    func acceptsMP4Extension() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        // Create a file with ftyp magic bytes
        let mp4File = tmpDir.appendingPathComponent("test.mp4")
        var mp4Data = Data(repeating: 0, count: 4)
        mp4Data.append(Data("ftyp".utf8))
        mp4Data.append(Data(repeating: 0, count: 100))
        try mp4Data.write(to: mp4File)

        let cmd = try SegmentCommand.parse([
            mp4File.path, "-o", tmpDir.path
        ])
        do {
            try await cmd.run()
        } catch let exitCode as ExitCode {
            // File not found or validation error is NOT
            // expected for format detection
            #expect(
                exitCode.rawValue != ExitCodes.validationError
            )
        } catch {
            // MP4 parsing errors are expected (minimal data),
            // but NOT format rejection
        }
    }
}

// MARK: - Info Command Media Format Support

@Suite("Info Command Media Formats")
struct InfoCommandMediaFormatTests {

    @Test("info command accepts MP4 file extension")
    func infoAcceptsMP4() throws {
        let cmd = try InfoCommand.parse(["test.mp4"])
        #expect(cmd.input == "test.mp4")
    }

    @Test("info command parses with output-format option")
    func infoWithOutputFormat() throws {
        let cmd = try InfoCommand.parse([
            "test.mp4", "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }
}
