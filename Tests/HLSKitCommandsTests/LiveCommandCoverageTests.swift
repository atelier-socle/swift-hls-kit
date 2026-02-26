// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - LiveStartCommand Run Coverage

@Suite("LiveStartCommand — Run Coverage")
struct LiveStartRunCoverageTests {

    @Test("run() with --list-presets prints preset table")
    func listPresets() async throws {
        let cmd = try LiveStartCommand.parse([
            "--list-presets"
        ])
        try await cmd.run()
    }

    @Test("run() with --list-presets and JSON format")
    func listPresetsJSON() async throws {
        let cmd = try LiveStartCommand.parse([
            "--list-presets",
            "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("run() with valid preset prints config")
    func validPresetRun() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--preset", "podcast-live"
        ])
        try await cmd.run()
    }

    @Test("run() with JSON output format")
    func validPresetJSON() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--preset", "webradio",
            "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("run() with quiet suppresses output")
    func quietMode() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() with all overrides applied")
    func allOverrides() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--preset", "podcast-live",
            "--segment-duration", "4.0",
            "--audio-bitrate", "256",
            "--loudness=-16.0",
            "--format", "fmp4",
            "--push-http", "https://cdn.example.com",
            "--push-header", "Auth:token",
            "--record",
            "--record-dir", "/tmp/rec",
            "--dvr",
            "--dvr-hours", "2.0"
        ])
        try await cmd.run()
    }

    @Test("run() with mpegts format override")
    func mpegtsFormat() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--format", "mpegts",
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() with cmaf format override")
    func cmafFormat() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--format", "cmaf",
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() with ts format alias")
    func tsFormatAlias() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--format", "ts",
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() without --output throws")
    func missingOutput() async {
        do {
            let cmd = try LiveStartCommand.parse([
                "--preset", "podcast-live"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("run() with unknown preset throws")
    func unknownPreset() async {
        do {
            let cmd = try LiveStartCommand.parse([
                "--output", "/tmp/test-live",
                "--preset", "nonexistent"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("run() with video preset shows video info")
    func videoPreset() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--preset", "video-live"
        ])
        try await cmd.run()
    }

    @Test("run() with broadcast preset (DVR, loudness)")
    func broadcastPreset() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--preset", "broadcast"
        ])
        try await cmd.run()
    }

    @Test("run() with event-recording preset")
    func eventRecordingPreset() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--preset", "event-recording"
        ])
        try await cmd.run()
    }

    @Test("run() with push destinations")
    func pushDestinations() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/test-live",
            "--push-http", "https://a.example.com",
            "--push-http", "https://b.example.com",
            "--push-header", "Key:Value"
        ])
        try await cmd.run()
    }
}

// MARK: - LiveStopCommand Run Coverage

@Suite("LiveStopCommand — Run Coverage")
struct LiveStopRunCoverageTests {

    @Test("run() prints stop message")
    func stopRun() async throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "/tmp/test-live"
        ])
        try await cmd.run()
    }

    @Test("run() with convert-to-vod flag")
    func stopWithVOD() async throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "/tmp/test-live",
            "--convert-to-vod"
        ])
        try await cmd.run()
    }

    @Test("run() quiet mode suppresses output")
    func stopQuiet() async throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "/tmp/test-live",
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() with JSON output format")
    func stopJSON() async throws {
        let cmd = try LiveStopCommand.parse([
            "--output", "/tmp/test-live",
            "--output-format", "json"
        ])
        try await cmd.run()
    }
}

// MARK: - LiveStatsCommand Run Coverage

@Suite("LiveStatsCommand — Run Coverage")
struct LiveStatsRunCoverageTests {

    @Test("run() prints sample stats text")
    func statsRun() async throws {
        let cmd = try LiveStatsCommand.parse([
            "--output", "/tmp/test-live"
        ])
        try await cmd.run()
    }

    @Test("run() with JSON output format")
    func statsJSON() async throws {
        let cmd = try LiveStatsCommand.parse([
            "--output", "/tmp/test-live",
            "--output-format", "json"
        ])
        try await cmd.run()
    }
}

// MARK: - LiveConvertToVODCommand Run Coverage

@Suite("LiveConvertToVODCommand — Run Coverage")
struct LiveConvertToVODRunCoverageTests {

    @Test("run() converts event playlist to VOD")
    func convertEvent() async throws {
        let tmpDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(
                at: tmpDir
            )
        }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:6.0,
            seg0.ts
            #EXTINF:6.0,
            seg1.ts
            """
        let input = tmpDir.appendingPathComponent(
            "live.m3u8"
        )
        try m3u8.write(
            to: input, atomically: true, encoding: .utf8
        )

        let output = tmpDir.appendingPathComponent(
            "vod.m3u8"
        )
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", input.path,
            "--output", output.path
        ])
        try await cmd.run()

        let result = try String(
            contentsOf: output, encoding: .utf8
        )
        #expect(result.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        #expect(result.contains("#EXT-X-ENDLIST"))
    }

    @Test("run() inserts VOD type when missing")
    func convertNoType() async throws {
        let tmpDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(
                at: tmpDir
            )
        }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXTINF:6.0,
            seg0.ts
            """
        let input = tmpDir.appendingPathComponent(
            "live.m3u8"
        )
        try m3u8.write(
            to: input, atomically: true, encoding: .utf8
        )

        let output = tmpDir.appendingPathComponent(
            "vod.m3u8"
        )
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", input.path,
            "--output", output.path
        ])
        try await cmd.run()

        let result = try String(
            contentsOf: output, encoding: .utf8
        )
        #expect(result.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
    }

    @Test("run() quiet suppresses output")
    func convertQuiet() async throws {
        let tmpDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(
                at: tmpDir
            )
        }

        let m3u8 = "#EXTM3U\n#EXT-X-TARGETDURATION:6\n"
        let input = tmpDir.appendingPathComponent(
            "live.m3u8"
        )
        try m3u8.write(
            to: input, atomically: true, encoding: .utf8
        )

        let output = tmpDir.appendingPathComponent(
            "vod.m3u8"
        )
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", input.path,
            "--output", output.path,
            "--quiet"
        ])
        try await cmd.run()
    }

    @Test("run() with missing playlist throws")
    func convertMissing() async {
        do {
            let cmd = try LiveConvertToVODCommand.parse([
                "--playlist", "/nonexistent/live.m3u8",
                "--output", "/tmp/vod.m3u8"
            ])
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("run() strips existing ENDLIST before re-adding")
    func convertWithEndlist() async throws {
        let tmpDir = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(
                at: tmpDir
            )
        }

        let m3u8 = """
            #EXTM3U
            #EXT-X-TARGETDURATION:6
            #EXT-X-PLAYLIST-TYPE:EVENT
            #EXTINF:6.0,
            seg0.ts
            #EXT-X-ENDLIST
            """
        let input = tmpDir.appendingPathComponent(
            "live.m3u8"
        )
        try m3u8.write(
            to: input, atomically: true, encoding: .utf8
        )

        let output = tmpDir.appendingPathComponent(
            "vod.m3u8"
        )
        let cmd = try LiveConvertToVODCommand.parse([
            "--playlist", input.path,
            "--output", output.path
        ])
        try await cmd.run()

        let result = try String(
            contentsOf: output, encoding: .utf8
        )
        #expect(result.contains("#EXT-X-PLAYLIST-TYPE:VOD"))
        let endlistCount =
            result.components(
                separatedBy: "#EXT-X-ENDLIST"
            ).count - 1
        #expect(endlistCount == 1)
    }
}
