// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Shared moov Boxes

extension CMAFWriter {

    func buildMvhd(
        timescale: UInt32, nextTrackID: UInt32
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(0)  // duration = 0 (fragmented)
        payload.writeFixedPoint16x16(1.0)  // rate
        payload.writeUInt16(0x0100)  // volume (1.0 as 8.8)
        payload.writeZeros(10)  // reserved
        writeIdentityMatrix(to: &payload)
        payload.writeZeros(24)  // pre_defined
        payload.writeUInt32(nextTrackID)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mvhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildTkhd(
        trackID: UInt32, isAudio: Bool,
        width: Int, height: Int
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(trackID)
        payload.writeUInt32(0)  // reserved
        payload.writeUInt32(0)  // duration = 0
        payload.writeZeros(8)  // reserved
        payload.writeUInt16(0)  // layer
        payload.writeUInt16(0)  // alternate group
        payload.writeUInt16(isAudio ? 0x0100 : 0)
        payload.writeZeros(2)  // reserved
        writeIdentityMatrix(to: &payload)
        payload.writeFixedPoint16x16(Double(width))
        payload.writeFixedPoint16x16(Double(height))
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tkhd", version: 0, flags: 0x03,
            payload: payload.data
        )
        return box.data
    }

    func buildMdhd(timescale: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // creation time
        payload.writeUInt32(0)  // modification time
        payload.writeUInt32(timescale)
        payload.writeUInt32(0)  // duration = 0
        // Language: "und"
        let langCode = encodeLanguage("und")
        payload.writeUInt16(langCode)
        payload.writeUInt16(0)  // pre_defined
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mdhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildHdlr(type: String, name: String) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(0)  // pre_defined
        payload.writeFourCC(type)
        payload.writeZeros(12)  // reserved
        payload.writeData(Data(name.utf8))
        payload.writeUInt8(0)  // null terminator
        var box = BinaryWriter()
        box.writeFullBox(
            type: "hdlr", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildSmhd() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt16(0)  // balance
        payload.writeUInt16(0)  // reserved
        var box = BinaryWriter()
        box.writeFullBox(
            type: "smhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildVmhd() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt16(0)  // graphicsmode
        payload.writeZeros(6)  // opcolor
        var box = BinaryWriter()
        box.writeFullBox(
            type: "vmhd", version: 0, flags: 1,
            payload: payload.data
        )
        return box.data
    }

    func buildDinf() -> Data {
        var drefPayload = BinaryWriter()
        drefPayload.writeUInt32(1)  // entry count
        var urlBox = BinaryWriter()
        urlBox.writeFullBox(
            type: "url ", version: 0, flags: 1,
            payload: Data()
        )
        drefPayload.writeData(urlBox.data)
        var dref = BinaryWriter()
        dref.writeFullBox(
            type: "dref", version: 0, flags: 0,
            payload: drefPayload.data
        )
        var dinf = BinaryWriter()
        dinf.writeContainerBox(
            type: "dinf", children: [dref.data]
        )
        return dinf.data
    }

    func buildEmptySampleTables() -> [Data] {
        let emptyEntry = emptyEntryPayload()
        var stts = BinaryWriter()
        stts.writeFullBox(
            type: "stts", version: 0, flags: 0,
            payload: emptyEntry
        )
        var stsc = BinaryWriter()
        stsc.writeFullBox(
            type: "stsc", version: 0, flags: 0,
            payload: emptyEntry
        )
        var stszPayload = BinaryWriter()
        stszPayload.writeUInt32(0)  // sample_size
        stszPayload.writeUInt32(0)  // sample_count
        var stsz = BinaryWriter()
        stsz.writeFullBox(
            type: "stsz", version: 0, flags: 0,
            payload: stszPayload.data
        )
        var stco = BinaryWriter()
        stco.writeFullBox(
            type: "stco", version: 0, flags: 0,
            payload: emptyEntry
        )
        return [stts.data, stsc.data, stsz.data, stco.data]
    }

    func buildMvex(trackID: UInt32) -> Data {
        let trex = buildTrex(trackID: trackID)
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mvex", children: [trex]
        )
        return writer.data
    }

    private func buildTrex(trackID: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(trackID)
        payload.writeUInt32(1)  // default_sample_description_index
        payload.writeUInt32(0)  // default_sample_duration
        payload.writeUInt32(0)  // default_sample_size
        payload.writeUInt32(0)  // default_sample_flags
        var box = BinaryWriter()
        box.writeFullBox(
            type: "trex", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func emptyEntryPayload() -> Data {
        var w = BinaryWriter()
        w.writeUInt32(0)
        return w.data
    }

    func writeIdentityMatrix(
        to writer: inout BinaryWriter
    ) {
        writer.writeUInt32(0x0001_0000)  // 1.0
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeUInt32(0x0001_0000)  // 1.0
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeZeros(4)
        writer.writeUInt32(0x4000_0000)  // 2.30 format
    }

    private func encodeLanguage(_ lang: String) -> UInt16 {
        let chars = Array(lang.prefix(3))
        guard chars.count == 3 else { return 0x55C4 }
        let c1 = UInt16(chars[0].asciiValue ?? 0) - 0x60
        let c2 = UInt16(chars[1].asciiValue ?? 0) - 0x60
        let c3 = UInt16(chars[2].asciiValue ?? 0) - 0x60
        return (c1 << 10) | (c2 << 5) | c3
    }
}
