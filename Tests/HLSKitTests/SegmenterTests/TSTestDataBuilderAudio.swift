// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

// MARK: - stsd Builders

extension TSTestDataBuilder {

    /// Build an stsd box with avc1 entry containing avcC.
    static func buildVideoStsd() -> Data {
        var payload = Data()
        // version(1) + flags(3) + entryCount(4)
        payload.append(contentsOf: [0, 0, 0, 0])
        appendUInt32(to: &payload, value: 1)

        // avc1 entry body
        var entry = Data()
        // reserved(6) + dataRefIndex(2)
        entry.append(Data(repeating: 0, count: 6))
        appendUInt16(to: &entry, value: 1)
        // pre_defined(2) + reserved(2) + pre_defined(12)
        entry.append(Data(repeating: 0, count: 16))
        // width(2) + height(2)
        appendUInt16(to: &entry, value: 1920)
        appendUInt16(to: &entry, value: 1080)
        // hRes(4) + vRes(4)
        appendUInt32(to: &entry, value: 0x0048_0000)
        appendUInt32(to: &entry, value: 0x0048_0000)
        // reserved(4) + frameCount(2) + compressorName(32)
        // + depth(2) + pre_defined(2) = 42
        entry.append(Data(repeating: 0, count: 4))
        appendUInt16(to: &entry, value: 1)
        entry.append(Data(repeating: 0, count: 32))
        appendUInt16(to: &entry, value: 0x0018)
        appendUInt16(to: &entry, value: 0xFFFF)

        // avcC box
        let avcCPayload = buildMinimalAvcC()
        var avcCBox = Data()
        appendUInt32(
            to: &avcCBox,
            value: UInt32(8 + avcCPayload.count)
        )
        appendFourCC(to: &avcCBox, value: "avcC")
        avcCBox.append(avcCPayload)
        entry.append(avcCBox)

        // Wrap with size + codec fourCC
        let entrySize = UInt32(8 + entry.count)
        appendUInt32(to: &payload, value: entrySize)
        appendFourCC(to: &payload, value: "avc1")
        payload.append(entry)

        return MP4TestDataBuilder.box(
            type: "stsd", payload: payload
        )
    }

    /// Build stsd with mp4a entry containing esds.
    static func buildAudioStsd() -> Data {
        var payload = Data()
        payload.append(contentsOf: [0, 0, 0, 0])
        appendUInt32(to: &payload, value: 1)

        var entry = Data()
        // reserved(6) + dataRefIndex(2)
        entry.append(Data(repeating: 0, count: 6))
        appendUInt16(to: &entry, value: 1)
        // reserved(8)
        entry.append(Data(repeating: 0, count: 8))
        // channelCount(2) + sampleSize(2)
        appendUInt16(to: &entry, value: 2)
        appendUInt16(to: &entry, value: 16)
        // pre_defined(2) + reserved(2)
        entry.append(Data(repeating: 0, count: 4))
        // sampleRate(4) as 16.16
        appendUInt32(to: &entry, value: 44100 << 16)

        // esds box
        let esdsPayload = buildMinimalEsds()
        var esdsBox = Data()
        appendUInt32(
            to: &esdsBox,
            value: UInt32(12 + esdsPayload.count)
        )
        appendFourCC(to: &esdsBox, value: "esds")
        appendUInt32(to: &esdsBox, value: 0)  // version+flags
        esdsBox.append(esdsPayload)
        entry.append(esdsBox)

        let entrySize = UInt32(8 + entry.count)
        appendUInt32(to: &payload, value: entrySize)
        appendFourCC(to: &payload, value: "mp4a")
        payload.append(entry)

        return MP4TestDataBuilder.box(
            type: "stsd", payload: payload
        )
    }
}

// MARK: - AV moov Builder

extension TSTestDataBuilder {

    static func buildAVMoov(
        config: AVConfig,
        vidDuration: UInt32,
        audDuration: UInt32,
        videoStcoOffset: UInt32,
        audioStcoOffset: UInt32
    ) -> Data {
        let videoTrak = buildVideoTrak(
            config: config.video,
            duration: vidDuration,
            stcoOffset: videoStcoOffset
        )
        let audioTrak = buildAudioTrak(
            audioSamples: config.audioSamples,
            sampleDelta: config.audioSampleDelta,
            timescale: config.audioTimescale,
            duration: audDuration,
            sampleSize: config.audioSampleSize,
            stcoOffset: audioStcoOffset
        )
        return MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: config.video.timescale,
                    duration: vidDuration
                ),
                videoTrak,
                audioTrak
            ]
        )
    }

    private static func buildVideoTrak(
        config: VideoConfig,
        duration: UInt32,
        stcoOffset: UInt32
    ) -> Data {
        let stblBox = buildVideoStblWithAvcC(
            config: config, stcoOffset: stcoOffset
        )
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: config.timescale,
                    duration: duration
                ),
                MP4TestDataBuilder.hdlr(handlerType: "vide"),
                minfBox
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: duration,
                    width: 1920, height: 1080
                ),
                mdiaBox
            ]
        )
    }

    // swiftlint:disable:next function_parameter_count
    private static func buildAudioTrak(
        audioSamples: Int,
        sampleDelta: UInt32,
        timescale: UInt32,
        duration: UInt32,
        sampleSize: UInt32,
        stcoOffset: UInt32
    ) -> Data {
        let stblBox = buildAudioStbl(
            audioSamples: audioSamples,
            sampleDelta: sampleDelta,
            sampleSize: sampleSize,
            stcoOffset: stcoOffset
        )
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: timescale, duration: duration
                ),
                MP4TestDataBuilder.hdlr(handlerType: "soun"),
                minfBox
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 2, duration: duration
                ),
                mdiaBox
            ]
        )
    }

    // MARK: - Audio-Only MP4

    /// Config for building audio-only test MP4 data.
    struct AudioOnlyConfig {
        var samples: Int = 430
        var sampleDelta: UInt32 = 1024
        var timescale: UInt32 = 44100
        var sampleSize: UInt32 = 50
    }

    /// Build an audio-only MP4 with esds box (no video track).
    static func audioOnlyMP4WithEsds(
        config: AudioOnlyConfig = AudioOnlyConfig()
    ) -> Data {
        let duration =
            UInt32(config.samples) * config.sampleDelta
        let mdatPayload = buildAudioOnlyMdat(config: config)
        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = buildAudioOnlyMoov(
            config: config, duration: duration,
            stcoOffset: 0
        )
        let base = UInt32(ftypData.count + moov0.count + 8)
        let moov = buildAudioOnlyMoov(
            config: config, duration: duration,
            stcoOffset: base
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

    private static func buildAudioOnlyMdat(
        config: AudioOnlyConfig
    ) -> Data {
        var payload = Data()
        for i in 0..<config.samples {
            payload.append(
                Data(
                    repeating: UInt8((i + 0x80) & 0xFF),
                    count: Int(config.sampleSize)
                )
            )
        }
        return payload
    }

    private static func buildAudioOnlyMoov(
        config: AudioOnlyConfig,
        duration: UInt32,
        stcoOffset: UInt32
    ) -> Data {
        let audioTrak = buildAudioTrak(
            audioSamples: config.samples,
            sampleDelta: config.sampleDelta,
            timescale: config.timescale,
            duration: duration,
            sampleSize: config.sampleSize,
            stcoOffset: stcoOffset
        )
        return MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: config.timescale,
                    duration: duration
                ),
                audioTrak
            ]
        )
    }

    private static func buildAudioStbl(
        audioSamples: Int,
        sampleDelta: UInt32,
        sampleSize: UInt32,
        stcoOffset: UInt32
    ) -> Data {
        let stsdBox = buildAudioStsd()
        let sizes = [UInt32](
            repeating: sampleSize, count: audioSamples
        )
        let sttsBox = MP4TestDataBuilder.stts(
            entries: [(UInt32(audioSamples), sampleDelta)]
        )
        let stscBox = MP4TestDataBuilder.stsc(
            entries: [
                MP4TestDataBuilder.StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(audioSamples),
                    descIndex: 1
                )
            ]
        )
        let stszBox = MP4TestDataBuilder.stsz(sizes: sizes)
        let stcoBox = MP4TestDataBuilder.stco(
            offsets: [stcoOffset]
        )
        return MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                stsdBox, sttsBox, stscBox, stszBox, stcoBox
            ]
        )
    }
}
