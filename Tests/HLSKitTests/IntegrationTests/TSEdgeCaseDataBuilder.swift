// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Shared data builder for TS edge case tests.
enum TSEdgeCaseDataBuilder {

    /// Specification for building a video-only MP4 moov box.
    struct VideoMP4Spec {
        var stsd: Data
        var sttsEntries: [(UInt32, UInt32)]
        var sizes: [UInt32]
        var syncSamples: [UInt32]
        var cttsEntries:
            [(
                sampleCount: UInt32, sampleOffset: Int32
            )]?
        var timescale: UInt32
        var duration: UInt32
        var samples: Int
    }

    // MARK: - MP4 Assembly

    static func assembleVideoMP4(
        spec: VideoMP4Spec
    ) -> Data {
        let mdatPayload = TSTestDataBuilder.buildVideoMdat(
            sampleCount: spec.samples,
            sampleSize: Int(spec.sizes[0])
        )
        func makeMoov(stcoOffset: UInt32) -> Data {
            buildMoov(spec: spec, stcoOffset: stcoOffset)
        }
        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = makeMoov(stcoOffset: 0)
        let offset = UInt32(
            ftypData.count + moov0.count + 8
        )
        let moov = makeMoov(stcoOffset: offset)
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat", payload: mdatPayload
        )
        var data = Data()
        data.append(ftypData)
        data.append(moov)
        data.append(mdatBox)
        return data
    }

    static func buildMoov(
        spec: VideoMP4Spec, stcoOffset: UInt32
    ) -> Data {
        let stblBox = buildStbl(
            spec: spec, stcoOffset: stcoOffset
        )
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: spec.timescale,
                    duration: spec.duration
                ),
                MP4TestDataBuilder.hdlr(
                    handlerType: "vide"
                ),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: spec.duration,
                    width: 1920, height: 1080
                ),
                mdiaBox
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: spec.timescale,
                    duration: spec.duration
                ),
                trakBox
            ]
        )
    }

    // MARK: - Stbl Builder

    private static func buildStbl(
        spec: VideoMP4Spec, stcoOffset: UInt32
    ) -> Data {
        let sttsBox = MP4TestDataBuilder.stts(
            entries: spec.sttsEntries
        )
        let stscBox = MP4TestDataBuilder.stsc(
            entries: [
                MP4TestDataBuilder.StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(spec.samples),
                    descIndex: 1
                )
            ]
        )
        let stszBox = MP4TestDataBuilder.stsz(
            sizes: spec.sizes
        )
        let stcoBox = MP4TestDataBuilder.stco(
            offsets: [stcoOffset]
        )
        let stssBox = MP4TestDataBuilder.stss(
            syncSamples: spec.syncSamples
        )
        var children = [
            spec.stsd, sttsBox, stscBox, stszBox,
            stcoBox, stssBox
        ]
        if let ctts = spec.cttsEntries {
            children.append(
                MP4TestDataBuilder.ctts(entries: ctts)
            )
        }
        return MP4TestDataBuilder.containerBox(
            type: "stbl", children: children
        )
    }

    // MARK: - Preconfigured MP4s

    static func variableSttsVideoMP4() -> Data {
        let totalSamples = 60
        let sampleSize: UInt32 = 58
        let duration: UInt32 = 30 * 3000 + 30 * 6000
        let timescale: UInt32 = 90000
        let spec = VideoMP4Spec(
            stsd: TSTestDataBuilder.buildVideoStsd(),
            sttsEntries: [(30, 3000), (30, 6000)],
            sizes: [UInt32](
                repeating: sampleSize, count: totalSamples
            ),
            syncSamples: [1, 31],
            timescale: timescale,
            duration: duration,
            samples: totalSamples
        )
        return assembleVideoMP4(spec: spec)
    }

    static func mp4WithCtts() -> Data {
        let samples = 90
        let sampleSize: UInt32 = 58
        let sampleDelta: UInt32 = 3000
        let timescale: UInt32 = 90000
        let duration = UInt32(samples) * sampleDelta
        let syncSamples =
            MP4TestDataBuilder.buildSyncSamples(
                count: samples, interval: 30
            )
        let spec = VideoMP4Spec(
            stsd: TSTestDataBuilder.buildVideoStsd(),
            sttsEntries: [(UInt32(samples), sampleDelta)],
            sizes: [UInt32](
                repeating: sampleSize, count: samples
            ),
            syncSamples: syncSamples,
            cttsEntries: [(UInt32(samples), 1500)],
            timescale: timescale,
            duration: duration,
            samples: samples
        )
        return assembleVideoMP4(spec: spec)
    }

    static func unsupportedCodecMP4() -> Data {
        let samples = 30
        let sampleSize: UInt32 = 50
        let duration: UInt32 = UInt32(samples) * 3000
        let timescale: UInt32 = 90000
        let stsd = hevcStsd()
        let syncSamples =
            MP4TestDataBuilder.buildSyncSamples(
                count: samples, interval: 30
            )
        let mdatPayload = Data(
            repeating: 0xAB,
            count: samples * Int(sampleSize)
        )
        let spec = VideoMP4Spec(
            stsd: stsd,
            sttsEntries: [(UInt32(samples), 3000)],
            sizes: [UInt32](
                repeating: sampleSize, count: samples
            ),
            syncSamples: syncSamples,
            timescale: timescale,
            duration: duration,
            samples: samples
        )
        func makeMoov(stcoOffset: UInt32) -> Data {
            buildMoov(spec: spec, stcoOffset: stcoOffset)
        }
        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = makeMoov(stcoOffset: 0)
        let offset = UInt32(
            ftypData.count + moov0.count + 8
        )
        let moov = makeMoov(stcoOffset: offset)
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat", payload: mdatPayload
        )
        var data = Data()
        data.append(ftypData)
        data.append(moov)
        data.append(mdatBox)
        return data
    }

    // MARK: - HEVC Stsd

    static func hevcStsd() -> Data {
        var payload = Data()
        payload.append(contentsOf: [0, 0, 0, 0])
        TSTestDataBuilder.appendUInt32(
            to: &payload, value: 1
        )
        var entry = Data()
        entry.append(Data(repeating: 0, count: 6))
        TSTestDataBuilder.appendUInt16(
            to: &entry, value: 1
        )
        entry.append(Data(repeating: 0, count: 16))
        TSTestDataBuilder.appendUInt16(
            to: &entry, value: 1920
        )
        TSTestDataBuilder.appendUInt16(
            to: &entry, value: 1080
        )
        TSTestDataBuilder.appendUInt32(
            to: &entry, value: 0x0048_0000
        )
        TSTestDataBuilder.appendUInt32(
            to: &entry, value: 0x0048_0000
        )
        entry.append(Data(repeating: 0, count: 4))
        TSTestDataBuilder.appendUInt16(
            to: &entry, value: 1
        )
        entry.append(Data(repeating: 0, count: 32))
        TSTestDataBuilder.appendUInt16(
            to: &entry, value: 0x0018
        )
        TSTestDataBuilder.appendUInt16(
            to: &entry, value: 0xFFFF
        )
        let entrySize = UInt32(8 + entry.count)
        TSTestDataBuilder.appendUInt32(
            to: &payload, value: entrySize
        )
        TSTestDataBuilder.appendFourCC(
            to: &payload, value: "hvc1"
        )
        payload.append(entry)
        return MP4TestDataBuilder.box(
            type: "stsd", payload: payload
        )
    }

    // MARK: - Codec Helpers

    static func makeLengthPrefixedNAL(
        size: Int
    ) -> Data {
        var data = Data()
        let nalSize = UInt32(size)
        data.append(UInt8((nalSize >> 24) & 0xFF))
        data.append(UInt8((nalSize >> 16) & 0xFF))
        data.append(UInt8((nalSize >> 8) & 0xFF))
        data.append(UInt8(nalSize & 0xFF))
        data.append(Data(repeating: 0x65, count: size))
        return data
    }

    static func makeVideoCodecConfig() -> TSCodecConfig {
        let sc = AnnexBConverter.startCode
        let sps = sc + Data(repeating: 0x67, count: 10)
        let pps = sc + Data(repeating: 0x68, count: 5)
        return TSCodecConfig(
            sps: sps, pps: pps, aacConfig: nil,
            videoStreamType: .h264, audioStreamType: nil
        )
    }
}
