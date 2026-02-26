// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - QuickTime Wave Box esds Fallback

@Suite("QuickTime Wave Box esds Fallback")
struct QuickTimeWaveEsdsTests {

    @Test("TS segmenter handles QuickTime V1 wave esds layout")
    func tsSegmenterHandlesQuickTimeWaveEsds() throws {
        let data = buildQuickTimeAudioOnlyMP4()
        let result = try TSSegmenter().segment(data: data)
        #expect(result.segmentCount > 0)
    }

    @Test("extractEsds falls back to wave box for esds (V1)")
    func fallsBackToWaveBoxForEsds() throws {
        let stsdPayload = buildStsdPayload(
            version: 1, wrapInWave: true
        )
        let config = try extractAACConfig(from: stsdPayload)
        #expect(config.profile == 1)
        #expect(config.sampleRateIndex == 4)
        #expect(config.channelConfig == 2)
    }

    @Test("extractEsds works with V0 direct esds")
    func directEsdsStillWorks() throws {
        let stsdPayload = buildStsdPayload(
            version: 0, wrapInWave: false
        )
        let config = try extractAACConfig(from: stsdPayload)
        #expect(config.profile == 1)
        #expect(config.sampleRateIndex == 4)
        #expect(config.channelConfig == 2)
    }

    @Test("extractEsds handles frma box before wave (V1)")
    func handlesBoxBeforeWave() throws {
        let stsdPayload = buildStsdWithFrmaAndWave()
        let segmenter = TSSegmenter()
        let esdsData = try segmenter.extractEsds(
            from: stsdPayload
        )
        #expect(!esdsData.isEmpty)
    }

    @Test("version 0 direct esds extraction succeeds")
    func version0DirectEsds() throws {
        let stsdPayload = buildStsdPayload(
            version: 0, wrapInWave: false
        )
        let config = try extractAACConfig(from: stsdPayload)
        // AAC-LC = objectType(2) - 1 = 1
        #expect(config.profile == 1)
        // 44100 Hz = frequency index 4
        #expect(config.sampleRateIndex == 4)
        // stereo = channel config 2
        #expect(config.channelConfig == 2)
    }

    @Test("version 1 with wave esds extraction succeeds")
    func version1WithWaveEsds() throws {
        let stsdPayload = buildStsdPayload(
            version: 1, wrapInWave: true
        )
        let config = try extractAACConfig(from: stsdPayload)
        #expect(config.profile == 1)
        #expect(config.sampleRateIndex == 4)
        #expect(config.channelConfig == 2)
    }

    @Test("version 2 with wave esds extraction succeeds")
    func version2WithWaveEsds() throws {
        let stsdPayload = buildStsdPayload(
            version: 2, wrapInWave: true
        )
        let config = try extractAACConfig(from: stsdPayload)
        #expect(config.profile == 1)
        #expect(config.sampleRateIndex == 4)
        #expect(config.channelConfig == 2)
    }
}

// MARK: - AAC Config Extraction Helper

extension QuickTimeWaveEsdsTests {

    /// Extract and parse AAC config from an stsd payload.
    private func extractAACConfig(
        from stsdPayload: Data
    ) throws -> ADTSConverter.AACConfig {
        let segmenter = TSSegmenter()
        let esdsData = try segmenter.extractEsds(
            from: stsdPayload
        )
        let adtsConverter = ADTSConverter()
        let ascData =
            try adtsConverter.extractAudioSpecificConfig(
                from: esdsData
            )
        return try adtsConverter.extractConfig(from: ascData)
    }
}

// MARK: - stsd Payload Builders

extension QuickTimeWaveEsdsTests {

    /// Build stsd payload with configurable version and layout.
    private func buildStsdPayload(
        version: UInt16,
        wrapInWave: Bool
    ) -> Data {
        let entry = buildMp4aEntry(
            version: version, wrapInWave: wrapInWave
        )
        return wrapEntry(entry)
    }

    /// Build stsd payload: V1 mp4a → frma + wave → esds.
    private func buildStsdWithFrmaAndWave() -> Data {
        var entry = buildMp4aHeader(version: 1)
        // frma box: size(4) + type(4) + data codec type(4)
        var frmaBox = Data()
        appendUInt32(to: &frmaBox, value: 12)
        appendFourCC(to: &frmaBox, value: "frma")
        appendFourCC(to: &frmaBox, value: "mp4a")
        entry.append(frmaBox)
        // wave box containing esds
        entry.append(buildWaveBox())
        return wrapEntry(entry)
    }
}

// MARK: - Full MP4 Builder

extension QuickTimeWaveEsdsTests {

    /// Build a complete audio-only MP4 with QuickTime V1 wave
    /// layout for end-to-end TS segmentation testing.
    private func buildQuickTimeAudioOnlyMP4() -> Data {
        let config = TSTestDataBuilder.AudioOnlyConfig()
        let duration =
            UInt32(config.samples) * config.sampleDelta
        let mdatPayload = buildAudioMdat(config: config)
        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = buildQTMoov(
            config: config, duration: duration,
            stcoOffset: 0
        )
        let base = UInt32(ftypData.count + moov0.count + 8)
        let moov = buildQTMoov(
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

    private func buildAudioMdat(
        config: TSTestDataBuilder.AudioOnlyConfig
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

    private func buildQTMoov(
        config: TSTestDataBuilder.AudioOnlyConfig,
        duration: UInt32,
        stcoOffset: UInt32
    ) -> Data {
        let stsdPayload = buildStsdPayload(
            version: 1, wrapInWave: true
        )
        let stsdBox = MP4TestDataBuilder.box(
            type: "stsd", payload: stsdPayload
        )
        let stblBox = buildStblBox(
            config: config, stsdBox: stsdBox,
            stcoOffset: stcoOffset
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
                MP4TestDataBuilder.hdlr(
                    handlerType: "soun"
                ),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: duration
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

    private func buildStblBox(
        config: TSTestDataBuilder.AudioOnlyConfig,
        stsdBox: Data,
        stcoOffset: UInt32
    ) -> Data {
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
        return MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                stsdBox, sttsBox, stscBox, stszBox, stcoBox
            ]
        )
    }
}

// MARK: - Shared Helpers

extension QuickTimeWaveEsdsTests {

    /// Build the mp4a audio sample entry header.
    ///
    /// - Parameter version: Sound Sample Description version
    ///   (0 = standard, 1 = QuickTime V1, 2 = QuickTime V2).
    private func buildMp4aHeader(
        version: UInt16 = 0
    ) -> Data {
        var entry = Data()
        // reserved(6) + dataRefIndex(2)
        entry.append(Data(repeating: 0, count: 6))
        appendUInt16(to: &entry, value: 1)
        // version(2) + revision(2) + vendor(4)
        appendUInt16(to: &entry, value: version)
        appendUInt16(to: &entry, value: 0)
        appendUInt32(to: &entry, value: 0)
        // channelCount(2) + sampleSize(2)
        appendUInt16(to: &entry, value: 2)
        appendUInt16(to: &entry, value: 16)
        // compressionID(2) + packetSize(2)
        entry.append(Data(repeating: 0, count: 4))
        // sampleRate(4) as 16.16 fixed-point
        appendUInt32(to: &entry, value: 44100 << 16)
        // Version-specific extra header fields
        switch version {
        case 1:
            // samplesPerPacket + bytesPerPacket
            // + bytesPerFrame + bytesPerSample (4 × 4)
            entry.append(Data(repeating: 0, count: 16))
        case 2:
            // QuickTime V2 extended fields (36 bytes)
            entry.append(Data(repeating: 0, count: 36))
        default:
            break
        }
        return entry
    }

    /// Build mp4a entry with esds either direct or in wave.
    private func buildMp4aEntry(
        version: UInt16 = 0,
        wrapInWave: Bool
    ) -> Data {
        var entry = buildMp4aHeader(version: version)
        if wrapInWave {
            entry.append(buildWaveBox())
        } else {
            entry.append(buildEsdsBox())
        }
        return entry
    }

    /// Build esds box: size(4) + "esds"(4) + version(4) + payload.
    private func buildEsdsBox() -> Data {
        let esdsPayload = TSTestDataBuilder.buildMinimalEsds()
        var box = Data()
        appendUInt32(
            to: &box,
            value: UInt32(12 + esdsPayload.count)
        )
        appendFourCC(to: &box, value: "esds")
        appendUInt32(to: &box, value: 0)
        box.append(esdsPayload)
        return box
    }

    /// Build wave box containing esds.
    private func buildWaveBox() -> Data {
        let esdsBox = buildEsdsBox()
        var box = Data()
        appendUInt32(
            to: &box, value: UInt32(8 + esdsBox.count)
        )
        appendFourCC(to: &box, value: "wave")
        box.append(esdsBox)
        return box
    }

    /// Wrap mp4a entry body into stsd payload.
    private func wrapEntry(_ entry: Data) -> Data {
        var payload = Data()
        // version(1) + flags(3) + entryCount(4)
        payload.append(contentsOf: [0, 0, 0, 0])
        appendUInt32(to: &payload, value: 1)
        // entry: size(4) + type(4) + body
        let entrySize = UInt32(8 + entry.count)
        appendUInt32(to: &payload, value: entrySize)
        appendFourCC(to: &payload, value: "mp4a")
        payload.append(entry)
        return payload
    }

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
