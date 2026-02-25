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

// MARK: - moof Assembly

extension CMAFWriter {

    struct CMAFTrafData {
        let tfhd: Data
        let tfdt: Data
        let trunFlags: UInt32
        let trunPayload: Data
        let dataOffsetPosition: Int
    }

    func buildTraf(
        frames: [EncodedFrame],
        trackID: UInt32,
        timescale: UInt32
    ) -> CMAFTrafData {
        let tfhd = buildTfhd(trackID: trackID)
        let baseTime =
            frames.first.map {
                UInt64($0.timestamp.seconds * Double(timescale))
            } ?? 0
        let tfdt = buildTfdt(baseDecodeTime: baseTime)

        let hasVideo = frames.contains { $0.codec.isVideo }
        var flags: UInt32 = 0x000301
        if hasVideo {
            flags |= 0x400  // sample-flags-present
        }

        var payload = BinaryWriter()
        payload.writeUInt32(UInt32(frames.count))
        let dataOffsetPosition = payload.count
        payload.writeInt32(0)  // data_offset placeholder

        for frame in frames {
            let duration = UInt32(
                frame.duration.seconds * Double(timescale)
            )
            payload.writeUInt32(duration)
            payload.writeUInt32(UInt32(frame.data.count))
            if hasVideo {
                payload.writeUInt32(
                    frame.isKeyframe
                        ? syncSample : nonSyncSample
                )
            }
        }

        return CMAFTrafData(
            tfhd: tfhd,
            tfdt: tfdt,
            trunFlags: flags,
            trunPayload: payload.data,
            dataOffsetPosition: dataOffsetPosition
        )
    }

    func assembleMoof(
        sequenceNumber: UInt32,
        traf: CMAFTrafData,
        mdatPayloadSize: Int
    ) -> Data {
        let mdatHeaderSize = 8
        // Pass 1: measure with dataOffset = 0
        let moof0 = buildMoofData(
            sequenceNumber: sequenceNumber,
            traf: traf,
            dataOffset: 0
        )
        let moofSize = moof0.count
        // Pass 2: rebuild with correct dataOffset
        return buildMoofData(
            sequenceNumber: sequenceNumber,
            traf: traf,
            dataOffset: Int32(moofSize + mdatHeaderSize)
        )
    }

    private func buildMoofData(
        sequenceNumber: UInt32,
        traf: CMAFTrafData,
        dataOffset: Int32
    ) -> Data {
        let mfhd = buildMfhd(
            sequenceNumber: sequenceNumber
        )
        var trunPayload = traf.trunPayload
        patchInt32(
            in: &trunPayload,
            at: traf.dataOffsetPosition,
            value: dataOffset
        )
        var trunBox = BinaryWriter()
        trunBox.writeFullBox(
            type: "trun", version: 0,
            flags: traf.trunFlags,
            payload: trunPayload
        )
        var trafBox = BinaryWriter()
        trafBox.writeContainerBox(
            type: "traf",
            children: [traf.tfhd, traf.tfdt, trunBox.data]
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "moof",
            children: [mfhd, trafBox.data]
        )
        return writer.data
    }

    private func buildTfhd(trackID: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(trackID)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tfhd", version: 0, flags: 0x020000,
            payload: payload.data
        )
        return box.data
    }

    private func buildTfdt(baseDecodeTime: UInt64) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt64(baseDecodeTime)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tfdt", version: 1, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildMfhd(
        sequenceNumber: UInt32
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(sequenceNumber)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mfhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildMdat(payload: Data) -> Data {
        var writer = BinaryWriter()
        writer.writeBox(type: "mdat", payload: payload)
        return writer.data
    }

    func patchInt32(
        in data: inout Data,
        at offset: Int,
        value: Int32
    ) {
        let unsigned = UInt32(bitPattern: value)
        let start = data.startIndex + offset
        data[start] = UInt8((unsigned >> 24) & 0xFF)
        data[start + 1] = UInt8((unsigned >> 16) & 0xFF)
        data[start + 2] = UInt8((unsigned >> 8) & 0xFF)
        data[start + 3] = UInt8(unsigned & 0xFF)
    }

    /// Sync sample flags: depends_on=2, non_sync=0.
    var syncSample: UInt32 { 0x0200_0000 }

    /// Non-sync sample flags: depends_on=1, non_sync=1.
    var nonSyncSample: UInt32 { 0x0101_0000 }
}
