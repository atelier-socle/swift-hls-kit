// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ADTSConverter")
struct ADTSConverterTests {

    // MARK: - Extract config

    @Test("Extract config: AAC-LC 44100 stereo")
    func extractConfigAACLC44100Stereo() throws {
        let converter = ADTSConverter()
        // AudioSpecificConfig: AAC-LC(2) + 44100(4) + stereo(2)
        // objectType=2 → bits [7:3] = 00010
        // freqIndex=4 → bits [2:0]+[7] = 100
        // channelConfig=2 → bits [6:3] = 0010
        // Byte 0: 00010_100 = 0x14
        // Byte 1: 0_0010_000 = 0x10
        let config = try converter.extractConfig(
            from: Data([0x12, 0x10])
        )
        // profile = objectType - 1 = 1 (AAC-LC)
        #expect(config.profile == 1)
        #expect(config.sampleRateIndex == 4)
        #expect(config.channelConfig == 2)
    }

    @Test("Extract config: 48kHz mono")
    func extractConfig48kHzMono() throws {
        let converter = ADTSConverter()
        // objectType=2(AAC-LC), freqIndex=3(48kHz),
        // channelConfig=1(mono)
        // Byte 0: 00010_011 = 0x13
        // Byte 1: 0_0001_000 = 0x08
        let config = try converter.extractConfig(
            from: Data([0x11, 0x88])
        )
        #expect(config.profile == 1)
        #expect(config.sampleRateIndex == 3)
        #expect(config.channelConfig == 1)
    }

    @Test("Extract config: invalid data too short → error")
    func extractConfigTooShort() {
        let converter = ADTSConverter()
        #expect(throws: TransportError.self) {
            try converter.extractConfig(from: Data([0x12]))
        }
    }

    // MARK: - Extract AudioSpecificConfig from esds

    @Test("Extract AudioSpecificConfig from esds box")
    func extractAudioSpecificConfigFromEsds() throws {
        let converter = ADTSConverter()
        let esdsData = buildTestEsds(
            audioSpecificConfig: Data([0x12, 0x10])
        )
        let asc = try converter.extractAudioSpecificConfig(
            from: esdsData
        )
        #expect(asc.count >= 2)
        #expect(asc[asc.startIndex] == 0x12)
        #expect(asc[asc.startIndex + 1] == 0x10)
    }

    @Test("Extract from invalid esds → error")
    func extractFromInvalidEsds() {
        let converter = ADTSConverter()
        #expect(throws: TransportError.self) {
            try converter.extractAudioSpecificConfig(
                from: Data([0x00])
            )
        }
    }

    @Test("Extract from esds with wrong ES tag → error")
    func wrongESTag() {
        let converter = ADTSConverter()
        // Tag 0x04 instead of expected 0x03
        let badEsds = Data([0x04, 0x02, 0x00, 0x01])
        #expect(throws: TransportError.self) {
            try converter.extractAudioSpecificConfig(
                from: badEsds
            )
        }
    }

    @Test("Extract from truncated ES_Descriptor → error")
    func truncatedESDescriptor() {
        let converter = ADTSConverter()
        // ES_Descriptor tag + length but not enough data
        let truncated = Data([0x03, 0x02, 0x00])
        #expect(throws: TransportError.self) {
            try converter.extractAudioSpecificConfig(
                from: truncated
            )
        }
    }

    @Test("Extract from esds with wrong decoder config tag → error")
    func wrongDecoderConfigTag() {
        let converter = ADTSConverter()
        // Valid ES_Descriptor header but wrong inner tag
        var data = Data()
        data.append(0x03)  // ES_Descriptor tag
        data.append(0x10)  // length
        data.append(contentsOf: [0x00, 0x01, 0x00])  // ES_ID + priority
        data.append(0x06)  // Wrong tag (expected 0x04)
        #expect(throws: TransportError.self) {
            try converter.extractAudioSpecificConfig(from: data)
        }
    }

    @Test("Extract from esds with truncated decoder config → error")
    func truncatedDecoderConfig() {
        let converter = ADTSConverter()
        var data = Data()
        data.append(0x03)  // ES_Descriptor tag
        data.append(0x10)  // length
        data.append(contentsOf: [0x00, 0x01, 0x00])  // ES_ID + priority
        data.append(0x04)  // DecoderConfigDescriptor tag
        data.append(0x0D)  // length = 13
        // Only provide partial data (5 bytes instead of 13)
        data.append(contentsOf: [0x40, 0x15, 0x00, 0x00, 0x00])
        #expect(throws: TransportError.self) {
            try converter.extractAudioSpecificConfig(from: data)
        }
    }

    // MARK: - ADTS header generation

    @Test("Generate ADTS header: exactly 7 bytes")
    func adtsHeaderSize() {
        let converter = ADTSConverter()
        let config = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4, channelConfig: 2
        )
        let header = converter.generateADTSHeader(
            frameSize: 100, config: config
        )
        #expect(header.count == 7)
    }

    @Test("Generate ADTS header: correct sync word (0xFFF)")
    func adtsHeaderSyncWord() {
        let converter = ADTSConverter()
        let config = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4, channelConfig: 2
        )
        let header = converter.generateADTSHeader(
            frameSize: 100, config: config
        )
        #expect(header[0] == 0xFF)
        #expect(header[1] & 0xF0 == 0xF0)
    }

    @Test("Generate ADTS header: frame length includes header")
    func adtsHeaderFrameLength() {
        let converter = ADTSConverter()
        let config = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4, channelConfig: 2
        )
        let frameSize = 256
        let header = converter.generateADTSHeader(
            frameSize: frameSize, config: config
        )
        // frame_length is spread across bytes 3-5
        let totalLength = frameSize + 7
        let high = Int(header[3] & 0x03) << 11
        let mid = Int(header[4]) << 3
        let low = Int(header[5] >> 5) & 0x07
        let decodedLength = high | mid | low
        #expect(decodedLength == totalLength)
    }

    @Test("Wrap with ADTS: correct total size")
    func wrapWithADTSSize() {
        let converter = ADTSConverter()
        let config = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4, channelConfig: 2
        )
        let frame = Data(repeating: 0xAA, count: 100)
        let result = converter.wrapWithADTS(
            frame: frame, config: config
        )
        #expect(result.count == 107)  // 7 + 100
    }

    @Test("Known ADTS header bytes for AAC-LC 44100 stereo")
    func knownADTSHeaderBytes() {
        let converter = ADTSConverter()
        let config = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 4, channelConfig: 2
        )
        let header = converter.generateADTSHeader(
            frameSize: 0, config: config
        )
        // Byte 0: 0xFF (sync)
        #expect(header[0] == 0xFF)
        // Byte 1: 0xF1 (sync + MPEG-4 + no CRC)
        #expect(header[1] == 0xF1)
        // Byte 2: profile(01) + freq_index(0100) + private(0)
        //        + channel_high(0) = 01_0100_0_0 = 0x50
        #expect(header[2] == 0x50)
    }

    @Test("ADTS header: protection absent bit is set")
    func adtsHeaderProtectionAbsent() {
        let converter = ADTSConverter()
        let config = ADTSConverter.AACConfig(
            profile: 1, sampleRateIndex: 3, channelConfig: 2
        )
        let header = converter.generateADTSHeader(
            frameSize: 50, config: config
        )
        // Byte 1 bit 0 should be 1 (protection_absent)
        #expect(header[1] & 0x01 == 0x01)
    }
}

// MARK: - Test Helpers

extension ADTSConverterTests {

    /// Build a minimal esds box payload for testing.
    ///
    /// Structure: ES_Descriptor(0x03) → DecoderConfigDescriptor(0x04)
    /// → DecoderSpecificInfo(0x05) → AudioSpecificConfig
    private func buildTestEsds(
        audioSpecificConfig: Data
    ) -> Data {
        var data = Data()

        // ES_Descriptor (tag 0x03)
        data.append(0x03)
        let esDescContentLen =
            3 + 2 + 13 + 2
            + audioSpecificConfig.count
        data.append(UInt8(esDescContentLen))
        // ES_ID (2 bytes)
        data.append(contentsOf: [0x00, 0x01])
        // stream priority
        data.append(0x00)

        // DecoderConfigDescriptor (tag 0x04)
        data.append(0x04)
        let decConfigLen = 13 + 2 + audioSpecificConfig.count
        data.append(UInt8(decConfigLen))
        // objectTypeIndication = 0x40 (Audio ISO/IEC 14496-3)
        data.append(0x40)
        // streamType(6 bits=0x05 audio) + upstream(1) + reserved(1)
        data.append(0x15)
        // bufferSizeDB (3 bytes)
        data.append(contentsOf: [0x00, 0x00, 0x00])
        // maxBitrate (4 bytes)
        data.append(contentsOf: [0x00, 0x01, 0xF4, 0x00])
        // avgBitrate (4 bytes)
        data.append(contentsOf: [0x00, 0x01, 0xF4, 0x00])

        // DecoderSpecificInfo (tag 0x05)
        data.append(0x05)
        data.append(UInt8(audioSpecificConfig.count))
        data.append(audioSpecificConfig)

        return data
    }
}
