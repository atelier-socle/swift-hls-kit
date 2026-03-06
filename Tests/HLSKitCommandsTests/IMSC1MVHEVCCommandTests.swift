// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - IMSC1 Command Tests

@Suite(
    "IMSC1Command — Argument Parsing & Integration",
    .timeLimit(.minutes(1))
)
struct IMSC1CommandTests {

    @Test("Parse imsc1 parse with file path")
    func parseSubcommand() throws {
        let cmd = try IMSC1ParseCommand.parse([
            "subtitles.ttml"
        ])
        #expect(cmd.input == "subtitles.ttml")
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse imsc1 parse with --output-format json")
    func parseJSONFormat() throws {
        let cmd = try IMSC1ParseCommand.parse([
            "subtitles.ttml", "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("Parse imsc1 render with output")
    func renderSubcommand() throws {
        let cmd = try IMSC1RenderCommand.parse([
            "input.ttml", "-o", "output.ttml"
        ])
        #expect(cmd.input == "input.ttml")
        #expect(cmd.output == "output.ttml")
    }

    @Test("Parse imsc1 segment with options")
    func segmentSubcommand() throws {
        let cmd = try IMSC1SegmentCommand.parse([
            "input.ttml",
            "--output-directory", "/tmp/out",
            "--language", "fr",
            "--segment-duration", "4.0",
            "--timescale", "48000"
        ])
        #expect(cmd.input == "input.ttml")
        #expect(cmd.outputDirectory == "/tmp/out")
        #expect(cmd.language == "fr")
        #expect(cmd.segmentDuration == 4.0)
        #expect(cmd.timescale == 48000)
    }

    @Test("IMSC1 parse with valid TTML file")
    func imsc1ParseValid() async throws {
        let (path, cleanup) = try makeTTMLFile()
        defer { cleanup() }

        let cmd = try IMSC1ParseCommand.parse([path])
        try await cmd.run()
    }

    @Test("IMSC1 parse JSON with valid TTML")
    func imsc1ParseJSON() async throws {
        let (path, cleanup) = try makeTTMLFile()
        defer { cleanup() }

        let cmd = try IMSC1ParseCommand.parse([
            path, "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("IMSC1 render produces normalized TTML")
    func imsc1Render() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let (inPath, _) = try makeTTMLFile(in: tmpDir)
        let outPath = tmpDir.appendingPathComponent("out.ttml")
        let cmd = try IMSC1RenderCommand.parse([
            inPath, "-o", outPath.path
        ])
        try await cmd.run()

        let output = try String(
            contentsOf: outPath, encoding: .utf8
        )
        #expect(output.contains("<tt"))
    }

    @Test("IMSC1 segment creates init + media + playlist")
    func imsc1Segment() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let (inPath, _) = try makeTTMLFile(in: tmpDir)
        let outDir = tmpDir.appendingPathComponent("segments")
        let cmd = try IMSC1SegmentCommand.parse([
            inPath,
            "--output-directory", outDir.path
        ])
        try await cmd.run()

        let fm = FileManager.default
        #expect(
            fm.fileExists(
                atPath: outDir.appendingPathComponent("init.mp4").path
            ))
        #expect(
            fm.fileExists(
                atPath: outDir.appendingPathComponent(
                    "segment_000.m4s"
                ).path
            ))
        #expect(
            fm.fileExists(
                atPath: outDir.appendingPathComponent(
                    "playlist.m3u8"
                ).path
            ))
    }

    @Test("IMSC1 segment with language override")
    func imsc1SegmentLanguage() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let (inPath, _) = try makeTTMLFile(in: tmpDir)
        let outDir = tmpDir.appendingPathComponent("segments")
        let cmd = try IMSC1SegmentCommand.parse([
            inPath,
            "--output-directory", outDir.path,
            "--language", "fr"
        ])
        try await cmd.run()

        #expect(
            FileManager.default.fileExists(
                atPath: outDir.appendingPathComponent("init.mp4")
                    .path
            ))
    }

    @Test("IMSC1 segment playlist contains EXT-X-MAP")
    func imsc1SegmentPlaylistMap() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        let (inPath, _) = try makeTTMLFile(in: tmpDir)
        let outDir = tmpDir.appendingPathComponent("segments")
        let cmd = try IMSC1SegmentCommand.parse([
            inPath,
            "--output-directory", outDir.path
        ])
        try await cmd.run()

        let playlist = try String(
            contentsOf: outDir.appendingPathComponent(
                "playlist.m3u8"
            ),
            encoding: .utf8
        )
        #expect(playlist.contains("EXT-X-MAP"))
    }

    @Test("IMSC1 parse missing file throws")
    func imsc1ParseMissing() async {
        let cmd = try? IMSC1ParseCommand.parse([
            "/nonexistent/file.ttml"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for missing file")
        } catch {
            // Expected — file not found
        }
    }
}

// MARK: - MV-HEVC Command Tests

@Suite(
    "MVHEVCCommand — Argument Parsing & Integration",
    .timeLimit(.minutes(1))
)
struct MVHEVCCommandTests {

    @Test("Parse mvhevc package with options")
    func parsePackage() throws {
        let cmd = try MVHEVCPackageCommand.parse([
            "input.hevc",
            "--output-directory", "/tmp/out",
            "--layout", "stereo",
            "--frame-rate", "30",
            "--width", "1920",
            "--height", "1080"
        ])
        #expect(cmd.input == "input.hevc")
        #expect(cmd.outputDirectory == "/tmp/out")
        #expect(cmd.layout == "stereo")
        #expect(cmd.frameRate == 30.0)
        #expect(cmd.width == 1920)
        #expect(cmd.height == 1080)
    }

    @Test("Parse mvhevc package with mono layout")
    func parsePackageMono() throws {
        let cmd = try MVHEVCPackageCommand.parse([
            "input.hevc",
            "--output-directory", "/tmp/out",
            "--layout", "mono"
        ])
        #expect(cmd.layout == "mono")
    }

    @Test("Parse mvhevc info with file path")
    func parseInfo() throws {
        let cmd = try MVHEVCInfoCommand.parse([
            "spatial.mp4"
        ])
        #expect(cmd.input == "spatial.mp4")
        #expect(cmd.outputFormat == "text")
    }

    @Test("Parse mvhevc info with JSON format")
    func parseInfoJSON() throws {
        let cmd = try MVHEVCInfoCommand.parse([
            "spatial.mp4", "--output-format", "json"
        ])
        #expect(cmd.outputFormat == "json")
    }

    @Test("MV-HEVC package missing file throws")
    func mvhevcPackageMissing() async {
        let cmd = try? MVHEVCPackageCommand.parse([
            "/nonexistent/file.hevc",
            "--output-directory", "/tmp/out"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for missing file")
        } catch {
            // Expected — file not found
        }
    }

    @Test("MV-HEVC info on non-spatial fMP4")
    func mvhevcInfoNonSpatial() async throws {
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: tmpDir) }

        var data = Data()
        data.append(buildTestFtypBox())
        data.append(buildTestMinimalMoov())

        let path = tmpDir.appendingPathComponent("test.mp4")
        try data.write(to: path)

        let cmd = try MVHEVCInfoCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("MV-HEVC info missing file throws")
    func mvhevcInfoMissing() async {
        let cmd = try? MVHEVCInfoCommand.parse([
            "/nonexistent/file.mp4"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error for missing file")
        } catch {
            // Expected — file not found
        }
    }

    @Test("MV-HEVC package defaults")
    func mvhevcPackageDefaults() throws {
        let cmd = try MVHEVCPackageCommand.parse([
            "input.hevc",
            "--output-directory", "/tmp/out"
        ])
        #expect(cmd.layout == "stereo")
        #expect(cmd.segmentDuration == 6.0)
        #expect(cmd.frameRate == 30.0)
        #expect(cmd.width == 1920)
        #expect(cmd.height == 1080)
    }
}

// MARK: - Spatial Box Detection Tests (P0 Bug Fix)

@Suite(
    "findSpatialBoxes — Payload Scanning Fix",
    .timeLimit(.minutes(1))
)
struct SpatialBoxDetectionTests {

    /// Minimal valid parameter sets for testing.
    private var testParameterSets: HEVCParameterSets {
        var sps = Data(count: 15)
        sps[0] = 0x42
        sps[1] = 0x01
        sps[2] = 0x01
        sps[3] = 0x42
        sps[4] = 0x20
        sps[14] = 123
        return HEVCParameterSets(
            vps: Data([0x40, 0x01, 0xAA, 0xBB]),
            sps: sps,
            pps: Data([0x44, 0x01, 0xCC])
        )
    }

    @Test("Detects vexu in packager init segment")
    func detectsVexu() throws {
        let info = try parseSpatialBoxes()
        #expect(info.hasVexu)
    }

    @Test("Detects stri in packager init segment")
    func detectsStri() throws {
        let info = try parseSpatialBoxes()
        #expect(info.hasStri)
    }

    @Test("Detects hero in packager init segment")
    func detectsHero() throws {
        let info = try parseSpatialBoxes()
        #expect(info.hasHero)
    }

    @Test("Detects hvcC in packager init segment")
    func detectsHvcC() throws {
        let info = try parseSpatialBoxes()
        #expect(info.hasHvcC)
    }

    @Test("Non-spatial MP4 reports no spatial boxes")
    func nonSpatialMP4() throws {
        var data = Data()
        data.append(buildTestFtypBox())
        data.append(buildTestMinimalMoov())

        let reader = MP4BoxReader()
        let boxes = try reader.readBoxes(from: data)
        let info = findSpatialBoxes(in: boxes)

        #expect(!info.hasVexu)
        #expect(!info.hasStri)
        #expect(!info.hasHero)
    }

    private func parseSpatialBoxes() throws -> SpatialBoxInfo {
        let packager = MVHEVCPackager()
        let config = SpatialVideoConfiguration.visionProStandard
        let initData = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        let reader = MP4BoxReader()
        let boxes = try reader.readBoxes(from: initData)
        return findSpatialBoxes(in: boxes)
    }
}

// MARK: - Helpers

private let ttmlContent = """
    <?xml version="1.0" encoding="UTF-8"?>
    <tt xml:lang="en" xmlns="http://www.w3.org/ns/ttml">
      <body>
        <div>
          <p begin="00:00:01.000" end="00:00:04.000">Hello</p>
        </div>
      </body>
    </tt>
    """

private func makeTTMLFile(
    in dir: URL? = nil
) throws -> (String, () -> Void) {
    let tmpDir =
        dir
        ?? FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    if dir == nil {
        try FileManager.default.createDirectory(
            at: tmpDir, withIntermediateDirectories: true
        )
    }
    let path = tmpDir.appendingPathComponent("subs.ttml")
    try ttmlContent.write(
        to: path, atomically: true, encoding: .utf8
    )
    let cleanup: () -> Void =
        dir == nil
        ? { try? FileManager.default.removeItem(at: tmpDir) }
        : {}
    return (path.path, cleanup)
}

private func buildTestFtypBox() -> Data {
    var data = Data()
    let brand = "isom".data(using: .ascii) ?? Data()
    var size = UInt32(20).bigEndian
    data.append(Data(bytes: &size, count: 4))
    data.append("ftyp".data(using: .ascii) ?? Data())
    data.append(brand)
    var version = UInt32(0x200).bigEndian
    data.append(Data(bytes: &version, count: 4))
    data.append(brand)
    return data
}

private func buildTestMinimalMoov() -> Data {
    var mvhd = Data()
    let mvhdPayload = Data(repeating: 0, count: 100)
    var mvhdSize = UInt32(8 + mvhdPayload.count).bigEndian
    mvhd.append(Data(bytes: &mvhdSize, count: 4))
    mvhd.append("mvhd".data(using: .ascii) ?? Data())
    mvhd.append(mvhdPayload)

    var moov = Data()
    var moovSize = UInt32(8 + mvhd.count).bigEndian
    moov.append(Data(bytes: &moovSize, count: 4))
    moov.append("moov".data(using: .ascii) ?? Data())
    moov.append(mvhd)
    return moov
}
