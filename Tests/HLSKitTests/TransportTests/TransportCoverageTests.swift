// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Transport Coverage")
struct TransportCoverageTests {

    // MARK: - extractAvcC error paths

    @Test("extractAvcC: stsd too short for avcC")
    func avcCStsdTooShort() {
        let segmenter = TSSegmenter()
        // Build stsd payload that's long enough to pass
        // initial check but too short for avcC offset
        var payload = Data(repeating: 0, count: 80)
        // Set entry count to 1
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractAvcC(from: payload)
        }
    }

    @Test("extractAvcC: cannot read avcC type")
    func avcCCannotReadType() {
        let segmenter = TSSegmenter()
        // Build payload that reaches avcC offset but is
        // too short to read the type field
        // avcCOffset = 8 + 8 + 78 = 94, need 94+8 = 102
        // But for "cannot read type": need >= 94+4 but < 94+8
        var payload = Data(repeating: 0, count: 97)
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractAvcC(from: payload)
        }
    }

    @Test("extractAvcC: expected avcC but found wrong type")
    func avcCWrongType() {
        let segmenter = TSSegmenter()
        // Build payload with wrong type at avcC position
        // avcCOffset = 94, type at 98
        var payload = Data(repeating: 0, count: 110)
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        // Set size at offset 94
        payload[94] = 0
        payload[95] = 0
        payload[96] = 0
        payload[97] = 16  // size = 16
        // Set wrong type at offset 98
        let wrongType = "XXXX"
        for (i, c) in wrongType.utf8.enumerated() {
            payload[98 + i] = c
        }
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractAvcC(from: payload)
        }
    }

    @Test("extractAvcC: payload extends beyond stsd")
    func avcCPayloadExtends() {
        let segmenter = TSSegmenter()
        // avcCOffset=94, size claims more data than available
        var payload = Data(repeating: 0, count: 110)
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        // Set large size at offset 94
        payload[94] = 0
        payload[95] = 0
        payload[96] = 1
        payload[97] = 0  // size = 256 (way too large)
        // Set correct type "avcC"
        let avcC = "avcC"
        for (i, c) in avcC.utf8.enumerated() {
            payload[98 + i] = c
        }
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractAvcC(from: payload)
        }
    }

    // MARK: - extractEsds error paths

    @Test("extractEsds: stsd too short for esds")
    func esdsStsdTooShort() {
        let segmenter = TSSegmenter()
        // esdsOffset = 8 + 8 + 28 = 44, need 44+8 = 52
        var payload = Data(repeating: 0, count: 40)
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractEsds(from: payload)
        }
    }

    @Test("extractEsds: cannot read esds type")
    func esdsCannotReadType() {
        let segmenter = TSSegmenter()
        // esdsOffset=44, need >= 44+4 but < 44+8
        var payload = Data(repeating: 0, count: 47)
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractEsds(from: payload)
        }
    }

    @Test("extractEsds: expected esds but found wrong type")
    func esdsWrongType() {
        let segmenter = TSSegmenter()
        // esdsOffset=44, type at 48
        var payload = Data(repeating: 0, count: 60)
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        // Set size at offset 44
        payload[44] = 0
        payload[45] = 0
        payload[46] = 0
        payload[47] = 16
        // Set wrong type at offset 48
        let wrongType = "YYYY"
        for (i, c) in wrongType.utf8.enumerated() {
            payload[48 + i] = c
        }
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractEsds(from: payload)
        }
    }

    @Test("extractEsds: payload extends beyond stsd")
    func esdsPayloadExtends() {
        let segmenter = TSSegmenter()
        // esdsOffset=44, size claims more than available
        var payload = Data(repeating: 0, count: 60)
        payload[4] = 0
        payload[5] = 0
        payload[6] = 0
        payload[7] = 1
        // Set large size at offset 44
        payload[44] = 0
        payload[45] = 0
        payload[46] = 1
        payload[47] = 0  // size = 256
        // Set correct type "esds"
        let esds = "esds"
        for (i, c) in esds.utf8.enumerated() {
            payload[48 + i] = c
        }
        #expect(throws: TransportError.self) {
            _ = try segmenter.extractEsds(from: payload)
        }
    }

    // MARK: - AnnexBConverter edge cases

    @Test("AnnexBConverter: multiple SPS in avcC")
    func multipleSPS() throws {
        let converter = AnnexBConverter()
        var avcCData = Data()
        avcCData.append(1)  // configVersion
        avcCData.append(0x42)
        avcCData.append(0xC0)
        avcCData.append(0x1E)
        avcCData.append(0xFF)
        // 2 SPS entries
        avcCData.append(0xE2)
        let sps1 = Data([0x67, 0x42, 0xC0, 0x1E])
        appendUInt16(to: &avcCData, value: UInt16(sps1.count))
        avcCData.append(sps1)
        let sps2 = Data([0x67, 0x42, 0xC0, 0x28])
        appendUInt16(to: &avcCData, value: UInt16(sps2.count))
        avcCData.append(sps2)
        // 1 PPS
        avcCData.append(1)
        let pps = Data([0x68, 0xCE, 0x38, 0x80])
        appendUInt16(to: &avcCData, value: UInt16(pps.count))
        avcCData.append(pps)
        let params = try converter.extractParameterSets(
            from: avcCData
        )
        // SPS should contain both entries
        #expect(params.sps.count > sps1.count + 4)
        #expect(params.pps.count > 0)
    }

    @Test("ADTSConverter: unusual sample rate indices")
    func unusualSampleRates() throws {
        let converter = ADTSConverter()
        // Sample rate index 6 = 32kHz
        let ascData = Data([0x14, 0x08])
        let config = try converter.extractConfig(
            from: ascData
        )
        #expect(config.sampleRateIndex == 8)
        // Generate a header with this config
        let header = converter.generateADTSHeader(
            frameSize: 100, config: config
        )
        #expect(header.count == 7)
        #expect(header[0] == 0xFF)
    }

    @Test("ADTSConverter: mono channel config")
    func monoChannel() throws {
        let converter = ADTSConverter()
        // Build ASC: objectType=2, freq=4(44100), ch=1(mono)
        // byte0 = (2 << 3) | (4 >> 1) = 0x12
        // byte1 = (4 << 7) | (1 << 3) = 0x08
        let ascData = Data([0x12, 0x08])
        let config = try converter.extractConfig(
            from: ascData
        )
        #expect(config.channelConfig == 1)
        let frame = Data(repeating: 0xAA, count: 100)
        let adts = converter.wrapWithADTS(
            frame: frame, config: config
        )
        #expect(adts.count == 107)
    }

    @Test("PES: large timestamp near 33-bit max")
    func largeTimestamp() {
        let maxTS: UInt64 = (1 << 33) - 1
        let encoded = encodePTSDTS(maxTS, marker: 0x20)
        #expect(encoded.count == 5)
        // Verify marker bits are present
        #expect((encoded[0] & 0xF0) == 0x20)
        #expect((encoded[0] & 0x01) == 0x01)
        #expect((encoded[2] & 0x01) == 0x01)
        #expect((encoded[4] & 0x01) == 0x01)
    }

    @Test("CRC-32 MPEG-2: known vector")
    func crc32KnownVector() {
        // CRC of "123456789" is well-known
        let data = Data("123456789".utf8)
        let crc = crc32MPEG2(data)
        #expect(crc == 0x0376_E6E7)
    }

    // MARK: - Helpers

    private func appendUInt16(
        to data: inout Data, value: UInt16
    ) {
        data.append(UInt8((value >> 8) & 0xFF))
        data.append(UInt8(value & 0xFF))
    }
}
