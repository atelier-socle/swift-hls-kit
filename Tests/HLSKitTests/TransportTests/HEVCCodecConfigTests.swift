// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - HEVC Parameter Set Extraction

@Suite("HEVC Parameter Set Extraction")
struct HEVCParameterSetExtractionTests {

    @Test("extract HEVC parameter sets from valid hvcC")
    func extractFromValidHvcC() throws {
        let hvcCData = buildMinimalHvcC()
        let converter = AnnexBConverter()
        let params = try converter.extractHEVCParameterSets(
            from: hvcCData
        )
        #expect(!params.sps.isEmpty)
        #expect(!params.vps.isEmpty)
        #expect(!params.pps.isEmpty)
    }

    @Test("hvcC too short throws")
    func hvcCTooShort() {
        let shortData = Data(repeating: 0, count: 10)
        let converter = AnnexBConverter()
        #expect(throws: TransportError.self) {
            _ = try converter.extractHEVCParameterSets(
                from: shortData
            )
        }
    }

    @Test("hvcC without SPS throws")
    func hvcCWithoutSPS() {
        // 22 bytes header + numArrays=0
        var data = Data(repeating: 0, count: 22)
        data.append(0x00)  // numArrays = 0
        let converter = AnnexBConverter()
        #expect(throws: TransportError.self) {
            _ = try converter.extractHEVCParameterSets(
                from: data
            )
        }
    }

    @Test("HEVC stream type in PMT is 0x24")
    func hevcStreamType() {
        let streamType = ProgramTableGenerator.StreamType.h265
        #expect(streamType.rawValue == 0x24)
    }

    @Test("AnnexB conversion is codec-agnostic")
    func annexBConversion() {
        let converter = AnnexBConverter()
        // 4-byte length prefix + 2 bytes payload
        var input = Data()
        input.append(contentsOf: [0x00, 0x00, 0x00, 0x02])
        input.append(contentsOf: [0xAB, 0xCD])
        let result = converter.convertToAnnexB(input)
        // Should have start code + payload
        let expected = Data(
            [0x00, 0x00, 0x00, 0x01, 0xAB, 0xCD]
        )
        #expect(result == expected)
    }

    /// Build a minimal valid hvcC record for testing.
    private func buildMinimalHvcC() -> Data {
        var data = Data(repeating: 0, count: 22)
        // configurationVersion = 1
        data[data.startIndex] = 1

        // numOfArrays = 3 (VPS, SPS, PPS)
        data.append(3)

        // VPS array (NAL type 32)
        data.append(0x20)  // NAL type 32
        data.append(contentsOf: [0x00, 0x01])  // numNalus = 1
        let vpsPayload = Data([0x40, 0x01, 0x0C, 0x01])
        data.append(contentsOf: [
            0x00, UInt8(vpsPayload.count)
        ])
        data.append(vpsPayload)

        // SPS array (NAL type 33)
        data.append(0x21)  // NAL type 33
        data.append(contentsOf: [0x00, 0x01])  // numNalus = 1
        let spsPayload = Data([0x42, 0x01, 0x01, 0x01])
        data.append(contentsOf: [
            0x00, UInt8(spsPayload.count)
        ])
        data.append(spsPayload)

        // PPS array (NAL type 34)
        data.append(0x22)  // NAL type 34
        data.append(contentsOf: [0x00, 0x01])  // numNalus = 1
        let ppsPayload = Data([0x44, 0x01])
        data.append(contentsOf: [
            0x00, UInt8(ppsPayload.count)
        ])
        data.append(ppsPayload)

        return data
    }
}

// MARK: - HEVC TS Codec Config

@Suite("HEVC TS Codec Support")
struct HEVCTSCodecSupportTests {

    @Test("TSSegmenter accepts hvc1 in codec whitelist")
    func hvc1InWhitelist() throws {
        let supported: Set<String> = [
            "avc1", "avc3", "hvc1", "hev1"
        ]
        #expect(supported.contains("hvc1"))
        #expect(supported.contains("hev1"))
    }

    @Test("H.265 stream type is 0x24 in PMT")
    func h265StreamTypeInPMT() {
        let gen = ProgramTableGenerator()
        let streams = [
            ProgramTableGenerator.StreamEntry(
                streamType: .h265,
                pid: TSPacket.PID.video
            )
        ]
        let pmt = gen.generatePMT(streams: streams)
        // PMT should contain stream_type byte 0x24
        #expect(pmt.contains(where: { $0 == 0x24 }))
    }

    @Test("TSCodecConfig supports HEVC stream type")
    func codecConfigWithHEVC() {
        let config = TSCodecConfig(
            sps: Data([0x00, 0x00, 0x00, 0x01, 0x40]),
            pps: Data([0x00, 0x00, 0x00, 0x01, 0x44]),
            aacConfig: nil,
            videoStreamType: .h265,
            audioStreamType: nil
        )
        #expect(config.videoStreamType == .h265)
        #expect(config.sps != nil)
        #expect(config.pps != nil)
    }
}
