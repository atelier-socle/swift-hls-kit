// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Media Segment Boxes

extension MVHEVCPackager {

    func assembleMoof(
        sequenceNumber: UInt32,
        baseDecodeTime: UInt64,
        sampleSizes: [UInt32],
        sampleDurations: [UInt32]
    ) -> Data {
        let mdatHeaderSize = 8
        // Pass 1: measure with dataOffset = 0
        let moof0 = buildMoofData(
            sequenceNumber: sequenceNumber,
            baseDecodeTime: baseDecodeTime,
            sampleSizes: sampleSizes,
            sampleDurations: sampleDurations,
            dataOffset: 0
        )
        let moofSize = moof0.count
        // Pass 2: rebuild with correct dataOffset
        return buildMoofData(
            sequenceNumber: sequenceNumber,
            baseDecodeTime: baseDecodeTime,
            sampleSizes: sampleSizes,
            sampleDurations: sampleDurations,
            dataOffset: Int32(moofSize + mdatHeaderSize)
        )
    }

    private func buildMoofData(
        sequenceNumber: UInt32,
        baseDecodeTime: UInt64,
        sampleSizes: [UInt32],
        sampleDurations: [UInt32],
        dataOffset: Int32
    ) -> Data {
        let mfhd = buildMfhd(sequenceNumber: sequenceNumber)
        let tfhd = buildTfhd()
        let tfdt = buildTfdt(baseDecodeTime: baseDecodeTime)
        let trun = buildTrun(
            sampleSizes: sampleSizes,
            sampleDurations: sampleDurations,
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

    func buildMfhd(sequenceNumber: UInt32) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(sequenceNumber)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "mfhd", version: 0, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildTfhd() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // track ID
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tfhd", version: 0, flags: 0x020000,
            payload: payload.data
        )
        return box.data
    }

    func buildTfdt(baseDecodeTime: UInt64) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt64(baseDecodeTime)
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tfdt", version: 1, flags: 0,
            payload: payload.data
        )
        return box.data
    }

    func buildTrun(
        sampleSizes: [UInt32],
        sampleDurations: [UInt32],
        dataOffset: Int32
    ) -> Data {
        // flags: data-offset-present(0x01) |
        //        sample-duration-present(0x100) |
        //        sample-size-present(0x200) |
        //        sample-flags-present(0x400)
        let flags: UInt32 = 0x000701
        let sampleCount = min(sampleSizes.count, sampleDurations.count)

        var payload = BinaryWriter()
        payload.writeUInt32(UInt32(sampleCount))
        payload.writeInt32(dataOffset)

        for i in 0..<sampleCount {
            payload.writeUInt32(sampleDurations[i])
            payload.writeUInt32(sampleSizes[i])
            // First sample is sync (keyframe), rest are non-sync
            let sampleFlags: UInt32 =
                i == 0
                ? syncSampleFlags
                : nonSyncSampleFlags
            payload.writeUInt32(sampleFlags)
        }

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

    func buildMvex() -> Data {
        let trex = buildTrex()
        var writer = BinaryWriter()
        writer.writeContainerBox(
            type: "mvex", children: [trex]
        )
        return writer.data
    }

    private func buildTrex() -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(1)  // track ID
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

    /// Sync sample flags: depends_on=2, non_sync=0.
    var syncSampleFlags: UInt32 { 0x0200_0000 }

    /// Non-sync sample flags: depends_on=1, non_sync=1.
    var nonSyncSampleFlags: UInt32 { 0x0101_0000 }
}
