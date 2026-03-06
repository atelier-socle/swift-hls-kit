// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Media Segment Boxes

extension IMSC1Segmenter {

    func assembleMoof(
        sequenceNumber: UInt32,
        baseDecodeTime: UInt64,
        sampleSize: UInt32,
        duration: UInt32
    ) -> Data {
        let mdatHeaderSize = 8
        // Pass 1: measure with dataOffset = 0
        let moof0 = buildMoofData(
            sequenceNumber: sequenceNumber,
            baseDecodeTime: baseDecodeTime,
            sampleSize: sampleSize,
            duration: duration,
            dataOffset: 0
        )
        let moofSize = moof0.count
        // Pass 2: rebuild with correct dataOffset
        return buildMoofData(
            sequenceNumber: sequenceNumber,
            baseDecodeTime: baseDecodeTime,
            sampleSize: sampleSize,
            duration: duration,
            dataOffset: Int32(moofSize + mdatHeaderSize)
        )
    }

    private func buildMoofData(
        sequenceNumber: UInt32,
        baseDecodeTime: UInt64,
        sampleSize: UInt32,
        duration: UInt32,
        dataOffset: Int32
    ) -> Data {
        let mfhd = buildMfhd(sequenceNumber: sequenceNumber)
        let tfhd = buildTfhd()
        let tfdt = buildTfdt(baseDecodeTime: baseDecodeTime)
        let trun = buildTrun(
            sampleSize: sampleSize,
            duration: duration,
            dataOffset: dataOffset
        )
        var trafBox = BinaryWriter()
        trafBox.writeContainerBox(
            type: "traf",
            children: [tfhd, tfdt, trun]
        )
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "moof",
            children: [mfhd, trafBox.data]
        )
        return writer.data
    }

    private func buildMfhd(sequenceNumber: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(sequenceNumber)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mfhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    private func buildTfhd() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // track ID
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

    private func buildTrun(
        sampleSize: UInt32,
        duration: UInt32,
        dataOffset: Int32
    ) -> Data {
        // flags: data-offset-present(0x01) |
        //        sample-duration-present(0x100) |
        //        sample-size-present(0x200)
        let flags: UInt32 = 0x000301
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // sample count
        payload.writeInt32(dataOffset)
        payload.writeUInt32(duration)
        payload.writeUInt32(sampleSize)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "trun", version: 0, flags: flags,
            payload: payload.data
        )
        return box.data
    }

    func buildMdat(payload: Data) -> Data {
        var writer = BinaryWriter()
        writer.writeBox(type: "mdat", payload: payload)
        return writer.data
    }
}

// MARK: - Shared Helpers

extension IMSC1Segmenter {

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

    func encodeLanguage(_ lang: String) -> UInt16 {
        let chars = Array(lang.prefix(3))
        guard chars.count == 3 else { return 0x55C4 }
        let c1 = UInt16(chars[0].asciiValue ?? 0) - 0x60
        let c2 = UInt16(chars[1].asciiValue ?? 0) - 0x60
        let c3 = UInt16(chars[2].asciiValue ?? 0) - 0x60
        return (c1 << 10) | (c2 << 5) | c3
    }
}
