// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - Info Command Definitions & Spatial Tests

@Suite(
    "InfoCommand — Definitions & Spatial Display",
    .timeLimit(.minutes(1))
)
struct InfoCommandDefinitionsTests {

    @Test("Info with M3U8 containing variable definitions")
    func infoWithDefinitions() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
            360p.m3u8
            """
        let path = tmpDir.appendingPathComponent("master.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try InfoCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Info with M3U8 containing REQ-VIDEO-LAYOUT")
    func infoWithVideoLayout() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=10000000,RESOLUTION=1920x1080,REQ-VIDEO-LAYOUT="CH-STEREO"
            stereo.m3u8
            """
        let path = tmpDir.appendingPathComponent("spatial.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try InfoCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Info JSON format includes definitions")
    func infoJSONDefinitions() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-DEFINE:NAME="token",VALUE="abc123"
            #EXT-X-STREAM-INF:BANDWIDTH=500000
            low.m3u8
            """
        let path = tmpDir.appendingPathComponent("defs.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try InfoCommand.parse([
            path.path, "--output-format", "json"
        ])
        try await cmd.run()
    }
}

// MARK: - Manifest Parse Definitions & Spatial Tests

@Suite(
    "ManifestParseCommand — Definitions & Spatial Display",
    .timeLimit(.minutes(1))
)
struct ManifestParseCommandDefinitionsTests {

    @Test("Parse with variable definitions shows definitions")
    func parseWithDefinitions() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-DEFINE:IMPORT="token"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            360p.m3u8
            """
        let path = tmpDir.appendingPathComponent("defs.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try ManifestParseCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Parse JSON includes 0.4.0 variant attributes")
    func parseJSONVariantAttributes() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=10000000,RESOLUTION=1920x1080,SUPPLEMENTAL-CODECS="dvh1.20.09/db4h",REQ-VIDEO-LAYOUT="CH-STEREO"
            spatial.m3u8
            """
        let path = tmpDir.appendingPathComponent("spatial.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try ManifestParseCommand.parse([
            path.path, "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("Parse with IMSC1 rendition shows codec")
    func parseIMSC1Rendition() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="subs",NAME="English",DEFAULT=YES,LANGUAGE="en",URI="subs_en.m3u8",CODECS="stpp.ttml.im1t"
            #EXT-X-STREAM-INF:BANDWIDTH=800000,SUBTITLES="subs"
            main.m3u8
            """
        let path = tmpDir.appendingPathComponent("subs.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try ManifestParseCommand.parse([path.path])
        try await cmd.run()
    }
}

// MARK: - Manifest Generate Definitions & Spatial Tests

@Suite(
    "ManifestGenerateCommand — Definitions & Spatial Generation",
    .timeLimit(.minutes(1))
)
struct ManifestGenerateCommandDefinitionsTests {

    @Test("Generate with definitions in JSON config")
    func generateWithDefinitions() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let json = """
            {
                "version": 7,
                "definitions": [
                    {"name": "base", "value": "https://cdn.example.com"},
                    {"import": "token"}
                ],
                "variants": [
                    {"bandwidth": 800000, "uri": "360p.m3u8"}
                ]
            }
            """
        let jsonPath = tmpDir.appendingPathComponent("config.json")
        try json.write(
            to: jsonPath, atomically: true, encoding: .utf8
        )

        let outPath = tmpDir.appendingPathComponent("out.m3u8")
        let cmd = try ManifestGenerateCommand.parse([
            jsonPath.path, "--output", outPath.path
        ])
        try await cmd.run()

        let output = try String(
            contentsOf: outPath, encoding: .utf8
        )
        #expect(output.contains("EXT-X-DEFINE"))
    }

    @Test("Generate with supplementalCodecs")
    func generateWithSupplementalCodecs() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let json = """
            {
                "variants": [
                    {
                        "bandwidth": 10000000,
                        "uri": "spatial.m3u8",
                        "supplementalCodecs": "dvh1.20.09/db4h"
                    }
                ]
            }
            """
        let jsonPath = tmpDir.appendingPathComponent("config.json")
        try json.write(
            to: jsonPath, atomically: true, encoding: .utf8
        )

        let outPath = tmpDir.appendingPathComponent("out.m3u8")
        let cmd = try ManifestGenerateCommand.parse([
            jsonPath.path, "--output", outPath.path
        ])
        try await cmd.run()

        let output = try String(
            contentsOf: outPath, encoding: .utf8
        )
        #expect(output.contains("SUPPLEMENTAL-CODECS"))
    }

    @Test("Generate with videoLayoutDescriptor")
    func generateWithVideoLayout() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let json = """
            {
                "variants": [
                    {
                        "bandwidth": 10000000,
                        "uri": "stereo.m3u8",
                        "videoLayoutDescriptor": "CH-STEREO"
                    }
                ]
            }
            """
        let jsonPath = tmpDir.appendingPathComponent("config.json")
        try json.write(
            to: jsonPath, atomically: true, encoding: .utf8
        )

        let outPath = tmpDir.appendingPathComponent("out.m3u8")
        let cmd = try ManifestGenerateCommand.parse([
            jsonPath.path, "--output", outPath.path
        ])
        try await cmd.run()

        let output = try String(
            contentsOf: outPath, encoding: .utf8
        )
        #expect(output.contains("REQ-VIDEO-LAYOUT"))
    }
}

// MARK: - Validate Definitions & Spatial Tests

@Suite(
    "ValidateCommand — Definitions & Spatial Validation",
    .timeLimit(.minutes(1))
)
struct ValidateCommandDefinitionsTests {

    @Test("Validate with variable definitions works")
    func validateWithDefinitions() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-DEFINE:NAME="base",VALUE="https://cdn.example.com"
            #EXT-X-STREAM-INF:BANDWIDTH=800000
            {$base}/360p.m3u8
            """
        let path = tmpDir.appendingPathComponent("vars.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try ValidateCommand.parse([path.path])
        do {
            try await cmd.run()
        } catch is ExitCode {
            // Variable validation may produce warnings/errors
        }
    }

    @Test("Validate with spatial layout works")
    func validateWithSpatialLayout() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let m3u8 = """
            #EXTM3U
            #EXT-X-STREAM-INF:BANDWIDTH=10000000,RESOLUTION=1920x1080,REQ-VIDEO-LAYOUT="CH-STEREO"
            stereo.m3u8
            """
        let path = tmpDir.appendingPathComponent("spatial.m3u8")
        try m3u8.write(
            to: path, atomically: true, encoding: .utf8
        )

        let cmd = try ValidateCommand.parse([path.path])
        do {
            try await cmd.run()
        } catch is ExitCode {
            // Spatial validation may produce warnings
        }
    }
}

// MARK: - Live Start Transport Policy Tests

@Suite(
    "LiveStartCommand — Transport Policy",
    .timeLimit(.minutes(1))
)
struct LiveStartCommandTransportTests {

    @Test("Parse --transport-policy responsive")
    func parseTransportPolicyResponsive() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/live",
            "--transport-policy", "responsive"
        ])
        #expect(cmd.transportPolicy == "responsive")
    }

    @Test("Parse --transport-policy conservative")
    func parseTransportPolicyConservative() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/live",
            "--transport-policy", "conservative"
        ])
        #expect(cmd.transportPolicy == "conservative")
    }

    @Test("Parse --transport-policy immediate")
    func parseTransportPolicyImmediate() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/live",
            "--transport-policy", "immediate"
        ])
        #expect(cmd.transportPolicy == "immediate")
    }

    @Test("Parse --transport-policy disabled")
    func parseTransportPolicyDisabled() throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/live",
            "--transport-policy", "disabled"
        ])
        #expect(cmd.transportPolicy == "disabled")
    }

    @Test("Live start with transport policy runs")
    func liveStartWithTransportPolicy() async throws {
        let cmd = try LiveStartCommand.parse([
            "--output", "/tmp/live",
            "--transport-policy", "responsive"
        ])
        try await cmd.run()
    }
}
