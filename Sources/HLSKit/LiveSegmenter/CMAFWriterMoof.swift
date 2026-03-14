// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - moof Assembly

extension CMAFWriter {

    struct CMAFTrafData {
        let tfhd: Data
        let tfdt: Data
        let trunFlags: UInt32
        let trunVersion: UInt8
        let trunPayload: Data
        let dataOffsetPosition: Int
    }

    func buildTraf(
        frames: [EncodedFrame],
        trackID: UInt32,
        timescale: UInt32
    ) -> CMAFTrafData {
        let hasVideo = frames.contains { $0.codec.isVideo }
        let tfhd = buildTfhd(
            trackID: trackID, isAudio: !hasVideo
        )
        let baseTime = Self.computeBaseDecodeTime(
            timestamp: frames.first?.timestamp,
            timescale: timescale
        )
        let tfdt = buildTfdt(baseDecodeTime: baseTime)
        let hasCTS = frames.contains {
            ($0.compositionTimeOffset ?? 0) != 0
        }
        let hasNegativeCTS = frames.contains {
            ($0.compositionTimeOffset ?? 0) < 0
        }

        var flags: UInt32 = 0x000301
        if hasVideo {
            flags |= 0x000400  // sample-flags-present
        }
        if hasCTS {
            flags |= 0x000800  // sample-composition-time-offsets
        }
        let trunVersion: UInt8 = hasNegativeCTS ? 1 : 0

        var payload = BinaryWriter()
        payload.writeUInt32(UInt32(frames.count))
        let dataOffsetPosition = payload.count
        payload.writeInt32(0)  // data_offset placeholder

        for frame in frames {
            let duration = Self.computeSampleDuration(
                duration: frame.duration,
                timescale: timescale
            )
            payload.writeUInt32(duration)
            payload.writeUInt32(UInt32(frame.data.count))
            if hasVideo {
                payload.writeUInt32(
                    frame.isKeyframe
                        ? syncSample : nonSyncSample
                )
            }
            if hasCTS {
                payload.writeInt32(
                    frame.compositionTimeOffset ?? 0
                )
            }
        }

        return CMAFTrafData(
            tfhd: tfhd,
            tfdt: tfdt,
            trunFlags: flags,
            trunVersion: trunVersion,
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
            type: "trun", version: traf.trunVersion,
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

    private func buildTfhd(
        trackID: UInt32, isAudio: Bool
    ) -> Data {
        var payload = BinaryWriter()
        payload.writeUInt32(trackID)
        // default-base-is-moof (CMAF §7.3.2)
        var flags: UInt32 = 0x020000
        if isAudio {
            // default-sample-flags-present
            flags |= 0x000020
            // All audio samples are sync (depends_on=2)
            payload.writeUInt32(syncSample)
        }
        var box = BinaryWriter()
        box.writeFullBox(
            type: "tfhd", version: 0, flags: flags,
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

    // MARK: - Integer Timestamp Helpers

    /// Compute baseMediaDecodeTime using integer math when
    /// timescales match, falling back to Double otherwise.
    static func computeBaseDecodeTime(
        timestamp: MediaTimestamp?,
        timescale: UInt32
    ) -> UInt64 {
        guard let ts = timestamp else { return 0 }
        if ts.timescale == Int32(timescale) {
            return UInt64(max(ts.value, 0))
        }
        // Cross-timescale: rescale via integer arithmetic
        let scaled =
            Int64(ts.value) * Int64(timescale)
            / Int64(ts.timescale)
        return UInt64(max(scaled, 0))
    }

    /// Compute sample duration using integer math when
    /// timescales match, falling back to Double otherwise.
    static func computeSampleDuration(
        duration: MediaTimestamp,
        timescale: UInt32
    ) -> UInt32 {
        if duration.timescale == Int32(timescale) {
            return UInt32(max(duration.value, 0))
        }
        let scaled =
            Int64(duration.value) * Int64(timescale)
            / Int64(duration.timescale)
        return UInt32(max(scaled, 0))
    }
}
