// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Builds synthetic MP4 test data with avcC/esds boxes
/// for TS segmentation testing.
enum TSTestDataBuilder {

    /// Config for building video-only test MP4 data.
    struct VideoConfig {
        var samples: Int = 90
        var keyframeInterval: Int = 30
        var sampleDelta: UInt32 = 3000
        var timescale: UInt32 = 90000
        var sampleSize: UInt32 = 58
    }

    /// Config for building AV test MP4 data.
    struct AVConfig {
        var video = VideoConfig()
        var audioSamples: Int = 430
        var audioSampleDelta: UInt32 = 1024
        var audioTimescale: UInt32 = 44100
        var audioSampleSize: UInt32 = 50
    }

    // MARK: - Video-Only MP4 with avcC

    /// Build an MP4 with video track containing avcC box
    /// in the stsd entry. Samples are length-prefixed NAL units.
    static func videoMP4WithAvcC(
        config: VideoConfig = VideoConfig()
    ) -> Data {
        let duration =
            UInt32(config.samples) * config.sampleDelta

        let mdatPayload = buildVideoMdat(
            sampleCount: config.samples,
            sampleSize: Int(config.sampleSize)
        )

        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = buildVideoMoov(
            config: config, duration: duration,
            stcoOffset: 0
        )
        let mdatHeaderSize = 8
        let stcoOffset = UInt32(
            ftypData.count + moov0.count + mdatHeaderSize
        )
        let moov = buildVideoMoov(
            config: config, duration: duration,
            stcoOffset: stcoOffset
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

    // MARK: - AV MP4 with avcC + esds

    /// Build an MP4 with video (avcC) + audio (esds) tracks.
    static func avMP4WithAvcCAndEsds(
        config: AVConfig = AVConfig()
    ) -> Data {
        let vidDuration =
            UInt32(config.video.samples)
            * config.video.sampleDelta
        let audDuration =
            UInt32(config.audioSamples)
            * config.audioSampleDelta
        let videoMdatSize =
            config.video.samples * Int(config.video.sampleSize)
        let mdatPayload = buildAVMdat(
            videoSamples: config.video.samples,
            videoSampleSize: Int(config.video.sampleSize),
            audioSamples: config.audioSamples,
            audioSampleSize: Int(config.audioSampleSize)
        )
        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = buildAVMoov(
            config: config, vidDuration: vidDuration,
            audDuration: audDuration,
            videoStcoOffset: 0, audioStcoOffset: 0
        )
        let mdatHeaderSize = 8
        let base = UInt32(
            ftypData.count + moov0.count + mdatHeaderSize
        )
        let moov = buildAVMoov(
            config: config, vidDuration: vidDuration,
            audDuration: audDuration,
            videoStcoOffset: base,
            audioStcoOffset: base + UInt32(videoMdatSize)
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
}

// MARK: - mdat Builders

extension TSTestDataBuilder {

    /// Build video mdat with length-prefixed NAL units.
    static func buildVideoMdat(
        sampleCount: Int, sampleSize: Int
    ) -> Data {
        var payload = Data()
        for i in 0..<sampleCount {
            let nalSize = UInt32(sampleSize - 4)
            appendUInt32(to: &payload, value: nalSize)
            let nalType: UInt8 = (i % 30 == 0) ? 0x65 : 0x41
            payload.append(nalType)
            payload.append(
                Data(
                    repeating: UInt8(i & 0xFF),
                    count: sampleSize - 5
                )
            )
        }
        return payload
    }

    private static func buildAVMdat(
        videoSamples: Int, videoSampleSize: Int,
        audioSamples: Int, audioSampleSize: Int
    ) -> Data {
        var payload = buildVideoMdat(
            sampleCount: videoSamples,
            sampleSize: videoSampleSize
        )
        for i in 0..<audioSamples {
            payload.append(
                Data(
                    repeating: UInt8((i + 0x80) & 0xFF),
                    count: audioSampleSize
                )
            )
        }
        return payload
    }
}

// MARK: - moov Builders

extension TSTestDataBuilder {

    static func buildVideoMoov(
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
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: duration,
                    width: 1920, height: 1080
                ),
                mdiaBox
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: config.timescale,
                    duration: duration
                ),
                trakBox
            ]
        )
    }

    static func buildVideoStblWithAvcC(
        config: VideoConfig,
        stcoOffset: UInt32
    ) -> Data {
        let stsdBox = buildVideoStsd()
        let syncSamples = MP4TestDataBuilder.buildSyncSamples(
            count: config.samples,
            interval: config.keyframeInterval
        )
        let sizes = [UInt32](
            repeating: config.sampleSize,
            count: config.samples
        )
        let sttsBox = MP4TestDataBuilder.stts(
            entries: [
                (UInt32(config.samples), config.sampleDelta)
            ]
        )
        let stscBox = MP4TestDataBuilder.stsc(
            entries: [
                MP4TestDataBuilder.StscEntry(
                    firstChunk: 1,
                    samplesPerChunk: UInt32(config.samples),
                    descIndex: 1
                )
            ]
        )
        let stszBox = MP4TestDataBuilder.stsz(sizes: sizes)
        let stcoBox = MP4TestDataBuilder.stco(
            offsets: [stcoOffset]
        )
        let stssBox = MP4TestDataBuilder.stss(
            syncSamples: syncSamples
        )
        return MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                stsdBox, sttsBox, stscBox, stszBox,
                stcoBox, stssBox
            ]
        )
    }
}

// MARK: - Codec Boxes

extension TSTestDataBuilder {

    /// Minimal avcC with SPS and PPS.
    static func buildMinimalAvcC() -> Data {
        var data = Data()
        data.append(1)  // configurationVersion
        data.append(0x42)  // AVCProfileIndication
        data.append(0xC0)  // profile_compatibility
        data.append(0x1E)  // AVCLevelIndication
        data.append(0xFF)  // lengthSizeMinusOne = 3

        let sps = Data([
            0x67, 0x42, 0xC0, 0x1E, 0xD9, 0x00, 0xA0, 0x47,
            0xFE, 0x6C
        ])
        data.append(0xE1)  // numSPS = 1
        appendUInt16(to: &data, value: UInt16(sps.count))
        data.append(sps)

        let pps = Data([0x68, 0xCE, 0x38, 0x80])
        data.append(1)  // numPPS = 1
        appendUInt16(to: &data, value: UInt16(pps.count))
        data.append(pps)

        return data
    }

    /// Minimal esds for AAC-LC 44100 stereo.
    static func buildMinimalEsds() -> Data {
        let audioSpecificConfig = Data([0x12, 0x10])
        var data = Data()

        data.append(0x03)  // ES_Descriptor tag
        let esLen =
            3 + 2 + 13 + 2 + audioSpecificConfig.count
        data.append(UInt8(esLen))
        data.append(contentsOf: [0x00, 0x01])  // ES_ID
        data.append(0x00)  // priority

        data.append(0x04)  // DecoderConfigDescriptor tag
        let decLen = 13 + 2 + audioSpecificConfig.count
        data.append(UInt8(decLen))
        data.append(0x40)  // objectTypeIndication
        data.append(0x15)  // streamType
        data.append(contentsOf: [0x00, 0x00, 0x00])
        data.append(contentsOf: [0x00, 0x01, 0xF4, 0x00])
        data.append(contentsOf: [0x00, 0x01, 0xF4, 0x00])

        data.append(0x05)  // DecoderSpecificInfo tag
        data.append(UInt8(audioSpecificConfig.count))
        data.append(audioSpecificConfig)

        return data
    }
}

// MARK: - Binary Helpers

extension TSTestDataBuilder {

    static func appendUInt16(
        to data: inout Data, value: UInt16
    ) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    static func appendUInt32(
        to data: inout Data, value: UInt32
    ) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    static func appendFourCC(
        to data: inout Data, value: String
    ) {
        for char in value.prefix(4) {
            data.append(char.asciiValue ?? 0x20)
        }
    }
}
