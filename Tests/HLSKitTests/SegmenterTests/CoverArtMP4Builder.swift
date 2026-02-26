// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

// MARK: - Cover Art MP4 Test Data Builder

/// Builds MP4 data with audio + jpeg cover art for regression tests.
enum CoverArtMP4Builder {

    struct Config {
        let samples: Int
        let sampleDelta: UInt32
        let timescale: UInt32
        let sampleSize: UInt32
        var duration: UInt32 {
            UInt32(samples) * sampleDelta
        }
    }

    static let defaultConfig = Config(
        samples: 100, sampleDelta: 1024,
        timescale: 44100, sampleSize: 50
    )

    /// Build with proper esds audio stsd (for TS segmenter).
    static func buildWithEsds() -> Data {
        buildMP4(useEsds: true)
    }

    /// Build with generic audio stsd (for fMP4 segmenter).
    static func buildSimple() -> Data {
        buildMP4(useEsds: false)
    }

    private static func buildMP4(useEsds: Bool) -> Data {
        let c = defaultConfig
        var mdatPayload = Data()
        for i in 0..<c.samples {
            mdatPayload.append(
                Data(
                    repeating: UInt8((i + 0x80) & 0xFF),
                    count: Int(c.sampleSize)
                )
            )
        }
        let coverData = Data(repeating: 0xFF, count: 160)
        mdatPayload.append(coverData)
        let coverSize = UInt32(coverData.count)

        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = buildMoov(
            c, coverSize: coverSize,
            stcoOffset: 0, useEsds: useEsds
        )
        let base = UInt32(ftypData.count + moov0.count + 8)
        let moov = buildMoov(
            c, coverSize: coverSize,
            stcoOffset: base, useEsds: useEsds
        )
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat", payload: mdatPayload
        )
        var data = Data()
        data.append(ftypData)
        data.append(moov)
        data.append(mdatBox)
        return data
    }

    private static func buildMoov(
        _ c: Config, coverSize: UInt32,
        stcoOffset: UInt32, useEsds: Bool
    ) -> Data {
        let audioTrak = buildAudioTrak(
            c, stcoOffset: stcoOffset, useEsds: useEsds
        )
        let coverTrak = buildCoverTrak(
            c, coverSize: coverSize, stcoOffset: stcoOffset
        )
        return MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: c.timescale,
                    duration: c.duration
                ),
                audioTrak,
                coverTrak
            ]
        )
    }

    private static func buildAudioTrak(
        _ c: Config, stcoOffset: UInt32, useEsds: Bool
    ) -> Data {
        let stbl: Data
        if useEsds {
            stbl = buildEsdsAudioStbl(
                c, stcoOffset: stcoOffset
            )
        } else {
            stbl = MP4TestDataBuilder.stbl(
                codec: "mp4a",
                sttsEntries: [(UInt32(c.samples), c.sampleDelta)],
                stszSizes: [UInt32](
                    repeating: c.sampleSize, count: c.samples
                ),
                stcoOffsets: [stcoOffset],
                stscEntries: [
                    MP4TestDataBuilder.StscEntry(
                        firstChunk: 1,
                        samplesPerChunk: UInt32(c.samples),
                        descIndex: 1
                    )
                ]
            )
        }
        let minf = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stbl]
        )
        let mdia = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: c.timescale,
                    duration: c.duration
                ),
                MP4TestDataBuilder.hdlr(handlerType: "soun"),
                minf
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: c.duration
                ),
                mdia
            ]
        )
    }

    private static func buildEsdsAudioStbl(
        _ c: Config, stcoOffset: UInt32
    ) -> Data {
        let stsd = TSTestDataBuilder.buildAudioStsd()
        let stts = MP4TestDataBuilder.stts(
            entries: [(UInt32(c.samples), c.sampleDelta)]
        )
        let stsc = MP4TestDataBuilder.stsc(
            entries: [
                MP4TestDataBuilder.StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(c.samples),
                    descIndex: 1
                )
            ]
        )
        let stsz = MP4TestDataBuilder.stsz(
            sizes: [UInt32](
                repeating: c.sampleSize, count: c.samples
            )
        )
        let stco = MP4TestDataBuilder.stco(
            offsets: [stcoOffset]
        )
        return MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [stsd, stts, stsc, stsz, stco]
        )
    }

    private static func buildCoverTrak(
        _ c: Config, coverSize: UInt32, stcoOffset: UInt32
    ) -> Data {
        let coverOffset =
            stcoOffset + UInt32(c.samples) * c.sampleSize
        let stbl = MP4TestDataBuilder.stbl(
            codec: "jpeg",
            sttsEntries: [(1, c.duration)],
            stszSizes: [coverSize],
            stcoOffsets: [coverOffset],
            stscEntries: [
                MP4TestDataBuilder.StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: 1,
                    descIndex: 1
                )
            ]
        )
        let minf = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stbl]
        )
        let mdia = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: c.timescale,
                    duration: c.duration
                ),
                MP4TestDataBuilder.hdlr(handlerType: "vide"),
                minf
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 2, duration: c.duration
                ),
                mdia
            ]
        )
    }
}
