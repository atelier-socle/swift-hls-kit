// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CodecConfigExtraction")
struct CodecConfigExtractionTests {

    // MARK: - SPS/PPS Extraction

    @Test("Extract SPS/PPS from synthetic avcC in stsd")
    func extractSPSPPSFromAvcC() throws {
        let stsd = buildVideoStsdWithAvcC()
        let segmenter = TSSegmenter()
        let avcCData = try segmenter.extractAvcC(from: stsd)
        let converter = AnnexBConverter()
        let params = try converter.extractParameterSets(
            from: avcCData
        )
        #expect(!params.sps.isEmpty)
        #expect(!params.pps.isEmpty)
    }

    @Test("Extract AAC config from synthetic esds in stsd")
    func extractAACConfigFromEsds() throws {
        let stsd = buildAudioStsdWithEsds()
        let segmenter = TSSegmenter()
        let esdsData = try segmenter.extractEsds(from: stsd)
        let adtsConverter = ADTSConverter()
        let ascData =
            try adtsConverter.extractAudioSpecificConfig(
                from: esdsData
            )
        let config = try adtsConverter.extractConfig(
            from: ascData
        )
        #expect(config.profile == 1)
        #expect(config.channelConfig == 2)
    }

    // MARK: - Video-Only

    @Test("Video-only: no audio config")
    func videoOnlyNoAudioConfig() throws {
        let stsd = buildVideoStsdWithAvcC()
        let videoAnalysis = buildMockVideoAnalysis(
            stsdPayload: stsd
        )
        let segmenter = TSSegmenter()
        let config = try segmenter.extractCodecConfig(
            videoAnalysis: videoAnalysis,
            audioAnalysis: nil,
            sourceBoxes: []
        )
        #expect(config.sps != nil)
        #expect(config.pps != nil)
        #expect(config.aacConfig == nil)
        #expect(config.videoStreamType == .h264)
        #expect(config.audioStreamType == nil)
    }

    // MARK: - Audio-Only

    @Test("Audio-only: no video config")
    func audioOnlyNoVideoConfig() throws {
        let stsd = buildAudioStsdWithEsds()
        let audioAnalysis = buildMockAudioAnalysis(
            stsdPayload: stsd
        )
        let segmenter = TSSegmenter()
        let config = try segmenter.extractCodecConfig(
            videoAnalysis: nil,
            audioAnalysis: audioAnalysis,
            sourceBoxes: []
        )
        #expect(config.sps == nil)
        #expect(config.pps == nil)
        #expect(config.aacConfig != nil)
        #expect(config.videoStreamType == nil)
        #expect(config.audioStreamType == .aac)
    }

    // MARK: - Unsupported Codec

    @Test("Unsupported video codec → TransportError")
    func unsupportedVideoCodec() {
        let stsd = buildVideoStsdWithAvcC(codec: "hvc1")
        let videoAnalysis = buildMockVideoAnalysis(
            stsdPayload: stsd, codec: "hvc1"
        )
        let segmenter = TSSegmenter()
        #expect(throws: TransportError.self) {
            try segmenter.extractCodecConfig(
                videoAnalysis: videoAnalysis,
                audioAnalysis: nil,
                sourceBoxes: []
            )
        }
    }

    @Test("Unsupported audio codec → TransportError")
    func unsupportedAudioCodec() {
        let stsd = Data(repeating: 0, count: 20)
        let audioAnalysis = buildMockAudioAnalysis(
            stsdPayload: stsd, codec: "ac-3"
        )
        let segmenter = TSSegmenter()
        #expect(throws: TransportError.self) {
            try segmenter.extractCodecConfig(
                videoAnalysis: nil,
                audioAnalysis: audioAnalysis,
                sourceBoxes: []
            )
        }
    }

    // MARK: - Invalid Data

    @Test("Short stsd for avcC → error")
    func shortStsdForAvcC() {
        let segmenter = TSSegmenter()
        #expect(throws: TransportError.self) {
            try segmenter.extractAvcC(from: Data([0x00]))
        }
    }

    @Test("Short stsd for esds → error")
    func shortStsdForEsds() {
        let segmenter = TSSegmenter()
        #expect(throws: TransportError.self) {
            try segmenter.extractEsds(from: Data([0x00]))
        }
    }
}

// MARK: - Test Data Builders

extension CodecConfigExtractionTests {

    /// Build a synthetic stsd payload with an avc1 entry
    /// containing an avcC box.
    private func buildVideoStsdWithAvcC(
        codec: String = "avc1"
    ) -> Data {
        var stsd = Data()
        // version(1) + flags(3) + entryCount(4)
        stsd.append(contentsOf: [0, 0, 0, 0])  // version+flags
        appendUInt32(to: &stsd, value: 1)  // entryCount

        // avc1 entry
        var entry = Data()
        // reserved(6) + dataRefIndex(2) = 8
        entry.append(Data(repeating: 0, count: 6))
        appendUInt16(to: &entry, value: 1)  // dataRefIndex
        // pre_defined(2) + reserved(2) + pre_defined(12) = 16
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
            to: &avcCBox, value: UInt32(8 + avcCPayload.count)
        )
        appendFourCC(to: &avcCBox, value: "avcC")
        avcCBox.append(avcCPayload)
        entry.append(avcCBox)

        // Wrap entry with size + codec
        let entrySize = UInt32(8 + entry.count)
        appendUInt32(to: &stsd, value: entrySize)
        appendFourCC(to: &stsd, value: codec)
        stsd.append(entry)

        return stsd
    }

    /// Build a minimal avcC payload with SPS and PPS.
    private func buildMinimalAvcC() -> Data {
        var data = Data()
        data.append(1)  // configurationVersion
        data.append(0x42)  // AVCProfileIndication (Baseline)
        data.append(0xC0)  // profile_compatibility
        data.append(0x1E)  // AVCLevelIndication (3.0)
        data.append(0xFF)  // lengthSizeMinusOne = 3 (4 bytes)

        // SPS
        let sps = Data([
            0x67, 0x42, 0xC0, 0x1E, 0xD9, 0x00, 0xA0, 0x47,
            0xFE, 0x6C
        ])
        data.append(0xE1)  // numSPS = 1
        appendUInt16(to: &data, value: UInt16(sps.count))
        data.append(sps)

        // PPS
        let pps = Data([0x68, 0xCE, 0x38, 0x80])
        data.append(1)  // numPPS = 1
        appendUInt16(to: &data, value: UInt16(pps.count))
        data.append(pps)

        return data
    }

    /// Build a synthetic stsd payload with an mp4a entry
    /// containing an esds box.
    private func buildAudioStsdWithEsds(
        codec: String = "mp4a"
    ) -> Data {
        var stsd = Data()
        // version(1) + flags(3) + entryCount(4)
        stsd.append(contentsOf: [0, 0, 0, 0])
        appendUInt32(to: &stsd, value: 1)

        // mp4a entry
        var entry = Data()
        // reserved(6) + dataRefIndex(2)
        entry.append(Data(repeating: 0, count: 6))
        appendUInt16(to: &entry, value: 1)
        // reserved(8)
        entry.append(Data(repeating: 0, count: 8))
        // channelCount(2)
        appendUInt16(to: &entry, value: 2)
        // sampleSize(2)
        appendUInt16(to: &entry, value: 16)
        // pre_defined(2) + reserved(2)
        entry.append(Data(repeating: 0, count: 4))
        // sampleRate(4) - 44100 as 16.16 fixed point
        appendUInt32(to: &entry, value: 44100 << 16)

        // esds box
        let esdsPayload = buildMinimalEsds()
        var esdsBox = Data()
        // esds has version(4) before descriptor data
        appendUInt32(
            to: &esdsBox,
            value: UInt32(12 + esdsPayload.count)
        )
        appendFourCC(to: &esdsBox, value: "esds")
        appendUInt32(to: &esdsBox, value: 0)  // version + flags
        esdsBox.append(esdsPayload)
        entry.append(esdsBox)

        let entrySize = UInt32(8 + entry.count)
        appendUInt32(to: &stsd, value: entrySize)
        appendFourCC(to: &stsd, value: codec)
        stsd.append(entry)

        return stsd
    }

    /// Build a minimal esds descriptor for AAC-LC 44100 stereo.
    private func buildMinimalEsds() -> Data {
        // AudioSpecificConfig: AAC-LC(2) + 44100(4) + stereo(2)
        let audioSpecificConfig = Data([0x12, 0x10])

        var data = Data()
        // ES_Descriptor (tag 0x03)
        data.append(0x03)
        let esLen = 3 + 2 + 13 + 2 + audioSpecificConfig.count
        data.append(UInt8(esLen))
        // ES_ID (2 bytes)
        data.append(contentsOf: [0x00, 0x01])
        // stream priority
        data.append(0x00)

        // DecoderConfigDescriptor (tag 0x04)
        data.append(0x04)
        let decLen = 13 + 2 + audioSpecificConfig.count
        data.append(UInt8(decLen))
        data.append(0x40)  // objectTypeIndication
        data.append(0x15)  // streamType
        data.append(contentsOf: [0x00, 0x00, 0x00])  // bufferSizeDB
        data.append(contentsOf: [0x00, 0x01, 0xF4, 0x00])  // max
        data.append(contentsOf: [0x00, 0x01, 0xF4, 0x00])  // avg

        // DecoderSpecificInfo (tag 0x05)
        data.append(0x05)
        data.append(UInt8(audioSpecificConfig.count))
        data.append(audioSpecificConfig)

        return data
    }

    private func buildMockVideoAnalysis(
        stsdPayload: Data,
        codec: String = "avc1"
    ) -> MP4TrackAnalysis {
        let info = TrackInfo(
            trackId: 1, mediaType: .video,
            timescale: 90000, duration: 270000,
            codec: codec, dimensions: nil,
            language: nil,
            sampleDescriptionData: stsdPayload,
            hasSyncSamples: true
        )
        let table = SampleTable(
            timeToSample: [], compositionOffsets: nil,
            sampleToChunk: [], sampleSizes: [],
            uniformSampleSize: 0,
            chunkOffsets: [], syncSamples: nil
        )
        return MP4TrackAnalysis(info: info, sampleTable: table)
    }

    private func buildMockAudioAnalysis(
        stsdPayload: Data,
        codec: String = "mp4a"
    ) -> MP4TrackAnalysis {
        let info = TrackInfo(
            trackId: 2, mediaType: .audio,
            timescale: 44100, duration: 132300,
            codec: codec, dimensions: nil,
            language: nil,
            sampleDescriptionData: stsdPayload,
            hasSyncSamples: false
        )
        let table = SampleTable(
            timeToSample: [], compositionOffsets: nil,
            sampleToChunk: [], sampleSizes: [],
            uniformSampleSize: 0,
            chunkOffsets: [], syncSamples: nil
        )
        return MP4TrackAnalysis(info: info, sampleTable: table)
    }

    // MARK: - Binary Helpers

    private func appendUInt16(
        to data: inout Data, value: UInt16
    ) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func appendUInt32(
        to data: inout Data, value: UInt32
    ) {
        data.append(UInt8((value >> 24) & 0xFF))
        data.append(UInt8((value >> 16) & 0xFF))
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }

    private func appendFourCC(
        to data: inout Data, value: String
    ) {
        for char in value.prefix(4) {
            data.append(char.asciiValue ?? 0x20)
        }
    }
}
