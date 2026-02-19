// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

// MARK: - TempMP4Setup

struct TempMP4Setup {
    let inputPath: String
    let outputDir: String
    let cleanup: () -> Void
}

func makeTempMP4() throws -> TempMP4Setup {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(
        at: tmpDir, withIntermediateDirectories: true
    )
    let mp4Data = buildMinimalMP4()
    let inputPath = tmpDir.appendingPathComponent("test.mp4")
    try mp4Data.write(to: inputPath)
    let outputDir = tmpDir.appendingPathComponent("out")
    return TempMP4Setup(
        inputPath: inputPath.path,
        outputDir: outputDir.path,
        cleanup: { try? FileManager.default.removeItem(at: tmpDir) }
    )
}

// MARK: - Minimal MP4 Builder

/// Builds a minimal valid MP4 file for testing.
func buildMinimalMP4() -> Data {
    var w = BinaryWriter()

    // ftyp box
    let ftyp = buildFtypBox()
    w.writeData(ftyp)

    // moov box
    let moov = buildMoovBox()
    w.writeData(moov)

    // mdat box (minimal)
    let sampleData = Data(
        repeating: 0, count: 1024
    )
    var mdatW = BinaryWriter()
    mdatW.writeUInt32(UInt32(8 + sampleData.count))
    mdatW.writeFourCC("mdat")
    mdatW.writeData(sampleData)
    w.writeData(mdatW.data)

    return w.data
}

private func buildFtypBox() -> Data {
    var w = BinaryWriter()
    let isom = Data("isom".utf8)
    let brands = isom + isom
    w.writeUInt32(UInt32(8 + brands.count))
    w.writeFourCC("ftyp")
    w.writeData(brands)
    return w.data
}

private func buildMoovBox() -> Data {
    let mvhd = buildMvhdBox()
    let trak = buildTrakBox()
    var w = BinaryWriter()
    let size = 8 + mvhd.count + trak.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("moov")
    w.writeData(mvhd)
    w.writeData(trak)
    return w.data
}

private func buildMvhdBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)  // version
    content.writeUInt8(0)  // flags[0]
    content.writeUInt8(0)  // flags[1]
    content.writeUInt8(0)  // flags[2]
    content.writeUInt32(0)  // creation time
    content.writeUInt32(0)  // modification time
    content.writeUInt32(90000)  // timescale
    content.writeUInt32(270000)  // duration (3 seconds)
    content.writeUInt32(0x0001_0000)  // rate
    content.writeUInt16(0x0100)  // volume
    // reserved: 10 bytes
    for _ in 0..<10 { content.writeUInt8(0) }
    // matrix: 36 bytes (identity)
    let identity: [UInt32] = [
        0x0001_0000, 0, 0, 0, 0x0001_0000, 0, 0, 0, 0x4000_0000
    ]
    for val in identity { content.writeUInt32(val) }
    // pre-defined: 24 bytes
    for _ in 0..<24 { content.writeUInt8(0) }
    content.writeUInt32(2)  // next track ID

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("mvhd")
    w.writeData(content.data)
    return w.data
}

private func buildTrakBox() -> Data {
    let tkhd = buildTkhdBox()
    let mdia = buildMdiaBox()
    var w = BinaryWriter()
    let size = 8 + tkhd.count + mdia.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("trak")
    w.writeData(tkhd)
    w.writeData(mdia)
    return w.data
}

private func buildTkhdBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)  // version
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(3)  // flags = enabled+in_movie
    content.writeUInt32(0)  // creation time
    content.writeUInt32(0)  // modification time
    content.writeUInt32(1)  // track ID
    content.writeUInt32(0)  // reserved
    content.writeUInt32(270000)  // duration
    for _ in 0..<8 { content.writeUInt8(0) }  // reserved
    content.writeUInt16(0)  // layer
    content.writeUInt16(0)  // alternate group
    content.writeUInt16(0)  // volume
    content.writeUInt16(0)  // reserved
    // matrix: 36 bytes
    let identity: [UInt32] = [
        0x0001_0000, 0, 0, 0, 0x0001_0000, 0, 0, 0, 0x4000_0000
    ]
    for val in identity { content.writeUInt32(val) }
    content.writeUInt32(0x0280_0000)  // width 640.0
    content.writeUInt32(0x0168_0000)  // height 360.0

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("tkhd")
    w.writeData(content.data)
    return w.data
}

private func buildMdiaBox() -> Data {
    let mdhd = buildMdhdBox()
    let hdlr = buildHdlrBox()
    let minf = buildMinfBox()
    var w = BinaryWriter()
    let size = 8 + mdhd.count + hdlr.count + minf.count
    w.writeUInt32(UInt32(size))
    w.writeFourCC("mdia")
    w.writeData(mdhd)
    w.writeData(hdlr)
    w.writeData(minf)
    return w.data
}

private func buildMdhdBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)  // version
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)  // flags
    content.writeUInt32(0)  // creation
    content.writeUInt32(0)  // modification
    content.writeUInt32(90000)  // timescale
    content.writeUInt32(270000)  // duration
    content.writeUInt16(0x55C4)  // language (und)
    content.writeUInt16(0)  // pre-defined

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("mdhd")
    w.writeData(content.data)
    return w.data
}

private func buildHdlrBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)  // version
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)  // flags
    content.writeUInt32(0)  // pre-defined
    content.writeFourCC("vide")  // handler type
    for _ in 0..<12 { content.writeUInt8(0) }  // reserved
    content.writeUInt8(0)  // name (null-terminated)

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("hdlr")
    w.writeData(content.data)
    return w.data
}

private func buildMinfBox() -> Data {
    let stbl = buildStblBox()
    var w = BinaryWriter()
    w.writeUInt32(UInt32(8 + stbl.count))
    w.writeFourCC("minf")
    w.writeData(stbl)
    return w.data
}

private func buildStblBox() -> Data {
    let stsd = buildStsdBox()
    let stts = buildSttsBox()
    let stsc = buildStscBox()
    let stsz = buildStszBox()
    let stco = buildStcoBox()
    let stss = buildStssBox()

    let totalSize =
        8 + stsd.count + stts.count + stsc.count
        + stsz.count + stco.count + stss.count
    var w = BinaryWriter()
    w.writeUInt32(UInt32(totalSize))
    w.writeFourCC("stbl")
    w.writeData(stsd)
    w.writeData(stts)
    w.writeData(stsc)
    w.writeData(stsz)
    w.writeData(stco)
    w.writeData(stss)
    return w.data
}

private func buildStsdBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)  // version+flags
    content.writeUInt32(1)  // entry count
    // Minimal avc1 entry (just fourCC + size for detection)
    var entry = BinaryWriter()
    entry.writeUInt8(0)
    entry.writeUInt8(0)
    entry.writeUInt8(0)
    entry.writeUInt8(0)
    entry.writeUInt8(0)
    entry.writeUInt8(0)
    entry.writeUInt16(1)  // data ref index
    // Video-specific: 70 bytes of fixed fields
    for _ in 0..<16 { entry.writeUInt8(0) }  // reserved
    entry.writeUInt16(640)  // width
    entry.writeUInt16(360)  // height
    entry.writeUInt32(0x0048_0000)  // horiz resolution
    entry.writeUInt32(0x0048_0000)  // vert resolution
    entry.writeUInt32(0)  // reserved
    entry.writeUInt16(1)  // frame count
    for _ in 0..<32 { entry.writeUInt8(0) }  // compressor name
    entry.writeUInt16(0x0018)  // depth
    entry.writeUInt16(0xFFFF)  // pre-defined (-1)

    var entryW = BinaryWriter()
    entryW.writeUInt32(UInt32(8 + entry.data.count))
    entryW.writeFourCC("avc1")
    entryW.writeData(entry.data)

    content.writeData(entryW.data)

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("stsd")
    w.writeData(content.data)
    return w.data
}

private func buildSttsBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)  // version+flags
    content.writeUInt32(1)  // entry count
    content.writeUInt32(1)  // sample count
    content.writeUInt32(270000)  // sample delta (3s at 90k)

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("stts")
    w.writeData(content.data)
    return w.data
}

private func buildStscBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt32(1)  // entry count
    content.writeUInt32(1)  // first chunk
    content.writeUInt32(1)  // samples per chunk
    content.writeUInt32(1)  // sample description index

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("stsc")
    w.writeData(content.data)
    return w.data
}

private func buildStszBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt32(1024)  // uniform sample size
    content.writeUInt32(1)  // sample count

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("stsz")
    w.writeData(content.data)
    return w.data
}

private func buildStcoBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt32(1)  // entry count
    // offset to mdat payload (ftyp(16) + moov(varies))
    // This is approximate; the segmenter recalculates
    content.writeUInt32(0)

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("stco")
    w.writeData(content.data)
    return w.data
}

private func buildStssBox() -> Data {
    var w = BinaryWriter()
    var content = BinaryWriter()
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt8(0)
    content.writeUInt32(1)  // entry count
    content.writeUInt32(1)  // sync sample 1

    w.writeUInt32(UInt32(8 + content.data.count))
    w.writeFourCC("stss")
    w.writeData(content.data)
    return w.data
}
