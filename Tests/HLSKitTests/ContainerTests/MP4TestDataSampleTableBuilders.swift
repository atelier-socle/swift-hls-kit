// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Sample Table Builders

extension MP4TestDataBuilder {

    /// Build an stts box.
    static func stts(
        entries: [(sampleCount: UInt32, sampleDelta: UInt32)]
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(UInt32(entries.count))
        for entry in entries {
            payload.appendUInt32(entry.sampleCount)
            payload.appendUInt32(entry.sampleDelta)
        }
        return box(type: "stts", payload: payload)
    }

    /// Build a ctts box.
    static func ctts(
        entries: [(sampleCount: UInt32, sampleOffset: Int32)],
        version: UInt8 = 0
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(version)
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(UInt32(entries.count))
        for entry in entries {
            payload.appendUInt32(entry.sampleCount)
            payload.appendUInt32(
                UInt32(bitPattern: entry.sampleOffset)
            )
        }
        return box(type: "ctts", payload: payload)
    }

    /// stsc entry for test data building.
    struct StscEntry {
        let firstChunk: UInt32
        let samplesPerChunk: UInt32
        let descIndex: UInt32
    }

    /// Build an stsc box.
    static func stsc(entries: [StscEntry]) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(UInt32(entries.count))
        for entry in entries {
            payload.appendUInt32(entry.firstChunk)
            payload.appendUInt32(entry.samplesPerChunk)
            payload.appendUInt32(entry.descIndex)
        }
        return box(type: "stsc", payload: payload)
    }

    /// Build an stsz box (variable sizes).
    static func stsz(sizes: [UInt32]) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(0)  // sample_size = 0 (variable)
        payload.appendUInt32(UInt32(sizes.count))
        for size in sizes {
            payload.appendUInt32(size)
        }
        return box(type: "stsz", payload: payload)
    }

    /// Build an stsz box (uniform size).
    static func stszUniform(
        sampleSize: UInt32, count: UInt32
    ) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(sampleSize)
        payload.appendUInt32(count)
        return box(type: "stsz", payload: payload)
    }

    /// Build an stco box (32-bit offsets).
    static func stco(offsets: [UInt32]) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(UInt32(offsets.count))
        for offset in offsets {
            payload.appendUInt32(offset)
        }
        return box(type: "stco", payload: payload)
    }

    /// Build a co64 box (64-bit offsets).
    static func co64(offsets: [UInt64]) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(UInt32(offsets.count))
        for offset in offsets {
            payload.appendUInt64(offset)
        }
        return box(type: "co64", payload: payload)
    }

    /// Build an stss box (sync samples, 1-based).
    static func stss(syncSamples: [UInt32]) -> Data {
        var payload = Data()
        payload.appendUInt8(0)  // version
        payload.append(contentsOf: [0, 0, 0])  // flags
        payload.appendUInt32(UInt32(syncSamples.count))
        for sample in syncSamples {
            payload.appendUInt32(sample)
        }
        return box(type: "stss", payload: payload)
    }

    /// Build a complete stbl with all tables.
    static func stbl(
        codec: String = "avc1",
        sttsEntries: [(
            sampleCount: UInt32, sampleDelta: UInt32
        )],
        stszSizes: [UInt32],
        stcoOffsets: [UInt32],
        stscEntries: [StscEntry],
        stssSyncSamples: [UInt32]? = nil,
        cttsEntries: [(
            sampleCount: UInt32, sampleOffset: Int32
        )]? = nil
    ) -> Data {
        var children = [
            stsd(codec: codec),
            stts(entries: sttsEntries),
            stsc(entries: stscEntries),
            stsz(sizes: stszSizes),
            stco(offsets: stcoOffsets)
        ]
        if let sync = stssSyncSamples {
            children.append(stss(syncSamples: sync))
        }
        if let cttsData = cttsEntries {
            children.append(ctts(entries: cttsData))
        }
        return containerBox(type: "stbl", children: children)
    }

    /// Build a complete MP4 with known sample tables.
    static func segmentableMP4(
        videoSamples: Int = 300,
        keyframeInterval: Int = 30,
        sampleDelta: UInt32 = 3000,
        timescale: UInt32 = 90000,
        sampleSize: UInt32 = 50_000
    ) -> Data {
        let duration = UInt32(videoSamples) * sampleDelta
        let sizes = [UInt32](
            repeating: sampleSize, count: videoSamples
        )
        var syncSamples: [UInt32] = []
        for i in stride(
            from: 0, to: videoSamples, by: keyframeInterval
        ) {
            syncSamples.append(UInt32(i + 1))  // 1-based
        }
        let stblBox = stbl(
            codec: "avc1",
            sttsEntries: [
                (UInt32(videoSamples), sampleDelta)
            ],
            stszSizes: sizes,
            stcoOffsets: [1000],
            stscEntries: [
                StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(videoSamples),
                    descIndex: 1
                )
            ],
            stssSyncSamples: syncSamples
        )
        let minfBox = containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = containerBox(
            type: "mdia",
            children: [
                mdhd(timescale: timescale, duration: duration),
                hdlr(handlerType: "vide"),
                minfBox
            ]
        )
        let trakBox = containerBox(
            type: "trak",
            children: [
                tkhd(
                    trackId: 1, duration: duration,
                    width: 1920, height: 1080
                ),
                mdiaBox
            ]
        )
        let moovBox = containerBox(
            type: "moov",
            children: [
                mvhd(timescale: timescale, duration: duration),
                trakBox
            ]
        )
        var data = Data()
        data.append(ftyp())
        data.append(moovBox)
        return data
    }
}
