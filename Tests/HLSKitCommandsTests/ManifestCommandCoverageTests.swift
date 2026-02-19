// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit
@testable import HLSKitCommands

// MARK: - ManifestGenerateCommand Coverage

@Suite("ManifestGenerateCommand — Integration")
struct ManifestGenerateCoverageTests {

    @Test("Generate from fMP4 directory with init.mp4 + segments")
    func generateFromFMP4Directory() async throws {
        let dir = try makeFMP4SegmentDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestGenerateCommand.parse([dir.path])
        try await cmd.run()

        let playlist = try String(
            contentsOf: dir.appendingPathComponent("playlist.m3u8"),
            encoding: .utf8
        )
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-VERSION:7"))
        #expect(playlist.contains("#EXT-X-MAP:URI=\"init.mp4\""))
        #expect(playlist.contains("segment_0.m4s"))
        #expect(playlist.contains("#EXT-X-ENDLIST"))
        #expect(!playlist.contains("38."))
    }

    @Test("Generate from TS directory")
    func generateFromTSDirectory() async throws {
        let dir = try makeTSSegmentDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestGenerateCommand.parse([dir.path])
        try await cmd.run()

        let playlist = try String(
            contentsOf: dir.appendingPathComponent("playlist.m3u8"),
            encoding: .utf8
        )
        #expect(playlist.contains("#EXT-X-VERSION:3"))
        #expect(playlist.contains("segment_0.ts"))
        #expect(playlist.contains("#EXTINF:6.000"))
    }

    @Test("Generate from JSON config to stdout")
    func generateFromJSONConfig() async throws {
        let (jsonPath, dir) = try makeManifestConfigJSON()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestGenerateCommand.parse([
            jsonPath.path
        ])
        try await cmd.run()
    }

    @Test("Generate from JSON config with --output")
    func generateFromJSONConfigToFile() async throws {
        let (jsonPath, dir) = try makeManifestConfigJSON()
        defer { try? FileManager.default.removeItem(at: dir) }

        let outputPath = dir.appendingPathComponent("master.m3u8")
        let cmd = try ManifestGenerateCommand.parse([
            jsonPath.path, "-o", outputPath.path
        ])
        try await cmd.run()

        let written = try String(
            contentsOf: outputPath, encoding: .utf8
        )
        #expect(written.contains("#EXTM3U"))
    }

    @Test("Generate with non-existent file throws fileNotFound")
    func generateNonExistentFile() async {
        let cmd = try? ManifestGenerateCommand.parse([
            "/nonexistent/config.json"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }

    @Test("Generate from empty directory throws generalError")
    func generateEmptyDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestGenerateCommand.parse([dir.path])
        do {
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }
}

// MARK: - ManifestParseCommand Coverage

@Suite("ManifestParseCommand — Coverage")
struct ManifestParseCoverageTests {

    @Test("Parse media playlist — text output")
    func parseMediaText() async throws {
        let (path, dir) = try makeMediaPlaylistFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestParseCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Parse media playlist — json output")
    func parseMediaJSON() async throws {
        let (path, dir) = try makeMediaPlaylistFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestParseCommand.parse([
            path.path, "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("Parse master playlist — text output")
    func parseMasterText() async throws {
        let (path, dir) = try makeMasterPlaylistFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestParseCommand.parse([path.path])
        try await cmd.run()
    }

    @Test("Parse master playlist — json output")
    func parseMasterJSON() async throws {
        let (path, dir) = try makeMasterPlaylistFile()
        defer { try? FileManager.default.removeItem(at: dir) }

        let cmd = try ManifestParseCommand.parse([
            path.path, "--output-format", "json"
        ])
        try await cmd.run()
    }

    @Test("Parse non-existent file throws fileNotFound")
    func parseNonExistent() async {
        let cmd = try? ManifestParseCommand.parse([
            "/nonexistent/playlist.m3u8"
        ])
        guard let cmd else { return }
        do {
            try await cmd.run()
            Issue.record("Expected error")
        } catch {}
    }
}

// MARK: - Test Fixtures

private func makeFMP4SegmentDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: dir, withIntermediateDirectories: true
    )

    let initData = buildTestInitSegment(
        trackID: 1, timescale: 90000
    )
    try initData.write(
        to: dir.appendingPathComponent("init.mp4")
    )

    let seg0 = buildTestMediaSegment(
        trackID: 1, sampleCount: 3,
        sampleDuration: 30000
    )
    try seg0.write(
        to: dir.appendingPathComponent("segment_0.m4s")
    )

    let seg1 = buildTestMediaSegment(
        trackID: 1, sampleCount: 2,
        sampleDuration: 30000
    )
    try seg1.write(
        to: dir.appendingPathComponent("segment_1.m4s")
    )

    return dir
}

private func makeTSSegmentDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: dir, withIntermediateDirectories: true
    )

    let tsData = Data(repeating: 0x47, count: 188)
    try tsData.write(
        to: dir.appendingPathComponent("segment_0.ts")
    )
    try tsData.write(
        to: dir.appendingPathComponent("segment_1.ts")
    )

    return dir
}

private func makeManifestConfigJSON() throws -> (URL, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: dir, withIntermediateDirectories: true
    )

    let json = """
        {
            "version": 7,
            "variants": [
                {
                    "bandwidth": 2800000,
                    "uri": "720p/playlist.m3u8",
                    "codecs": "avc1.64001f,mp4a.40.2",
                    "resolution": {"width": 1280, "height": 720},
                    "frameRate": 30.0,
                    "averageBandwidth": 2500000
                },
                {
                    "bandwidth": 800000,
                    "uri": "360p/playlist.m3u8"
                }
            ]
        }
        """
    let path = dir.appendingPathComponent("config.json")
    try json.write(to: path, atomically: true, encoding: .utf8)
    return (path, dir)
}

private func makeMediaPlaylistFile() throws -> (URL, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: dir, withIntermediateDirectories: true
    )

    let m3u8 = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-TARGETDURATION:6
        #EXT-X-PLAYLIST-TYPE:VOD
        #EXT-X-MAP:URI="init.mp4"
        #EXTINF:6.0,
        segment_0.m4s
        #EXTINF:4.5,
        segment_1.m4s
        #EXT-X-ENDLIST
        """
    let path = dir.appendingPathComponent("playlist.m3u8")
    try m3u8.write(to: path, atomically: true, encoding: .utf8)
    return (path, dir)
}

private func makeMasterPlaylistFile() throws -> (URL, URL) {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: dir, withIntermediateDirectories: true
    )

    let m3u8 = """
        #EXTM3U
        #EXT-X-VERSION:7
        #EXT-X-STREAM-INF:BANDWIDTH=2800000,RESOLUTION=1280x720
        720p/playlist.m3u8
        #EXT-X-STREAM-INF:BANDWIDTH=800000,RESOLUTION=640x360
        360p/playlist.m3u8
        """
    let path = dir.appendingPathComponent("master.m3u8")
    try m3u8.write(to: path, atomically: true, encoding: .utf8)
    return (path, dir)
}

// MARK: - fMP4 Test Segment Builders

private func buildTestInitSegment(
    trackID: UInt32, timescale: UInt32
) -> Data {
    var w = BinaryWriter()
    w.writeData(buildFtypBox())
    w.writeData(
        buildTestMoovBox(
            trackID: trackID, timescale: timescale
        )
    )
    return w.data
}

private func buildFtypBox() -> Data {
    var w = BinaryWriter()
    let brands = Data("isomisom".utf8)
    w.writeUInt32(UInt32(8 + brands.count))
    w.writeFourCC("ftyp")
    w.writeData(brands)
    return w.data
}

private func buildTestMoovBox(
    trackID: UInt32, timescale: UInt32
) -> Data {
    let mvhd = buildTestMvhdBox(timescale: timescale)
    let trak = buildTestTrakBox(
        trackID: trackID, timescale: timescale
    )
    var w = BinaryWriter()
    let size = 8 + mvhd.count + trak.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("moov")
    w.writeData(mvhd)
    w.writeData(trak)
    return w.data
}

private func buildTestMvhdBox(timescale: UInt32) -> Data {
    var c = BinaryWriter()
    c.writeUInt32(0)  // version + flags
    c.writeUInt32(0)  // creation
    c.writeUInt32(0)  // modification
    c.writeUInt32(timescale)
    c.writeUInt32(timescale * 3)  // 3 seconds
    c.writeUInt32(0x0001_0000)  // rate
    c.writeUInt16(0x0100)  // volume
    for _ in 0..<10 { c.writeUInt8(0) }
    let identity: [UInt32] = [
        0x0001_0000, 0, 0, 0, 0x0001_0000, 0, 0, 0,
        0x4000_0000
    ]
    for v in identity { c.writeUInt32(v) }
    for _ in 0..<24 { c.writeUInt8(0) }
    c.writeUInt32(2)  // next track ID

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + c.data.count))
    w.writeFourCC("mvhd")
    w.writeData(c.data)
    return w.data
}

private func buildTestTrakBox(
    trackID: UInt32, timescale: UInt32
) -> Data {
    let tkhd = buildTestTkhdBox(trackID: trackID)
    let mdia = buildTestMdiaBox(timescale: timescale)
    var w = BinaryWriter()
    let size = 8 + tkhd.count + mdia.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("trak")
    w.writeData(tkhd)
    w.writeData(mdia)
    return w.data
}

private func buildTestTkhdBox(trackID: UInt32) -> Data {
    var c = BinaryWriter()
    c.writeUInt8(0)  // version
    c.writeUInt8(0)
    c.writeUInt8(0)
    c.writeUInt8(3)
    c.writeUInt32(0)
    c.writeUInt32(0)
    c.writeUInt32(trackID)
    c.writeUInt32(0)  // reserved
    c.writeUInt32(270000)
    for _ in 0..<8 { c.writeUInt8(0) }
    c.writeUInt16(0)
    c.writeUInt16(0)
    c.writeUInt16(0)
    c.writeUInt16(0)
    let m: [UInt32] = [
        0x0001_0000, 0, 0, 0, 0x0001_0000, 0, 0, 0,
        0x4000_0000
    ]
    for v in m { c.writeUInt32(v) }
    c.writeUInt32(0x0280_0000)  // width
    c.writeUInt32(0x0168_0000)  // height

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + c.data.count))
    w.writeFourCC("tkhd")
    w.writeData(c.data)
    return w.data
}

private func buildTestMdiaBox(timescale: UInt32) -> Data {
    let mdhd = buildTestMdhdBox(timescale: timescale)
    let hdlr = buildTestHdlrBox()
    let minf = buildTestMinfBox()
    var w = BinaryWriter()
    let size = 8 + mdhd.count + hdlr.count + minf.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("mdia")
    w.writeData(mdhd)
    w.writeData(hdlr)
    w.writeData(minf)
    return w.data
}

private func buildTestMdhdBox(timescale: UInt32) -> Data {
    var c = BinaryWriter()
    c.writeUInt32(0)  // version+flags
    c.writeUInt32(0)
    c.writeUInt32(0)
    c.writeUInt32(timescale)
    c.writeUInt32(timescale * 3)
    c.writeUInt16(0x55C4)  // language
    c.writeUInt16(0)

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + c.data.count))
    w.writeFourCC("mdhd")
    w.writeData(c.data)
    return w.data
}

private func buildTestHdlrBox() -> Data {
    var c = BinaryWriter()
    c.writeUInt32(0)  // version+flags
    c.writeUInt32(0)  // pre-defined
    c.writeFourCC("vide")
    for _ in 0..<12 { c.writeUInt8(0) }
    c.writeUInt8(0)  // name

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + c.data.count))
    w.writeFourCC("hdlr")
    w.writeData(c.data)
    return w.data
}

private func buildTestMinfBox() -> Data {
    let stbl = buildTestStblBox()
    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + stbl.count))
    w.writeFourCC("minf")
    w.writeData(stbl)
    return w.data
}

private func buildTestStblBox() -> Data {
    // Minimal stbl with stsd only
    var stsd = BinaryWriter()
    var stsdC = BinaryWriter()
    stsdC.writeUInt32(0)  // version+flags
    stsdC.writeUInt32(0)  // entry count
    stsd.writeUInt32(UInt32(8 + stsdC.data.count))
    stsd.writeFourCC("stsd")
    stsd.writeData(stsdC.data)

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + stsd.data.count))
    w.writeFourCC("stbl")
    w.writeData(stsd.data)
    return w.data
}

private func buildTestMediaSegment(
    trackID: UInt32, sampleCount: UInt32,
    sampleDuration: UInt32
) -> Data {
    var w = BinaryWriter()
    w.writeData(
        buildTestMoofBox(
            trackID: trackID,
            sampleCount: sampleCount,
            sampleDuration: sampleDuration
        )
    )
    // mdat
    var mdat = BinaryWriter()
    mdat.writeUInt32(UInt32(8 + 16))
    mdat.writeFourCC("mdat")
    mdat.writeData(Data(repeating: 0, count: 16))
    w.writeData(mdat.data)
    return w.data
}

private func buildTestMoofBox(
    trackID: UInt32, sampleCount: UInt32,
    sampleDuration: UInt32
) -> Data {
    let mfhd = buildTestMfhdBox()
    let traf = buildTestTrafBox(
        trackID: trackID,
        sampleCount: sampleCount,
        sampleDuration: sampleDuration
    )
    var w = BinaryWriter()
    let size = 8 + mfhd.count + traf.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("moof")
    w.writeData(mfhd)
    w.writeData(traf)
    return w.data
}

private func buildTestMfhdBox() -> Data {
    var c = BinaryWriter()
    c.writeUInt32(0)  // version+flags
    c.writeUInt32(1)  // sequence number

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + c.data.count))
    w.writeFourCC("mfhd")
    w.writeData(c.data)
    return w.data
}

private func buildTestTrafBox(
    trackID: UInt32, sampleCount: UInt32,
    sampleDuration: UInt32
) -> Data {
    let tfhd = buildTestTfhdBox(trackID: trackID)
    let trun = buildTestTrunBox(
        sampleCount: sampleCount,
        sampleDuration: sampleDuration
    )
    var w = BinaryWriter()
    let size = 8 + tfhd.count + trun.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("traf")
    w.writeData(tfhd)
    w.writeData(trun)
    return w.data
}

private func buildTestTfhdBox(trackID: UInt32) -> Data {
    var c = BinaryWriter()
    // version=0, flags=0 (no optional fields)
    c.writeUInt32(0x0000_0000)
    c.writeUInt32(trackID)

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + c.data.count))
    w.writeFourCC("tfhd")
    w.writeData(c.data)
    return w.data
}

private func buildTestTrunBox(
    sampleCount: UInt32, sampleDuration: UInt32
) -> Data {
    var c = BinaryWriter()
    // version=0, flags=0x100 (sample-duration-present)
    c.writeUInt32(0x0000_0100)
    c.writeUInt32(sampleCount)
    for _ in 0..<sampleCount {
        c.writeUInt32(sampleDuration)
    }

    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + c.data.count))
    w.writeFourCC("trun")
    w.writeData(c.data)
    return w.data
}
