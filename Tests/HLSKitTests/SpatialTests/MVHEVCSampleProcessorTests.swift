// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MVHEVCSampleProcessor")
struct MVHEVCSampleProcessorTests {

    let processor = MVHEVCSampleProcessor()

    // MARK: - extractNALUs

    @Test("Extract NALUs from empty data returns empty array")
    func extractNALUsEmpty() {
        let result = processor.extractNALUs(from: Data())
        #expect(result.isEmpty)
    }

    @Test("Extract NALUs with 4-byte start codes")
    func extractNALUs4ByteStartCode() {
        // Two NALUs with 4-byte start codes
        var data = Data()
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        data.append(contentsOf: [0x40, 0x01, 0xAA, 0xBB])  // VPS NALU
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        data.append(contentsOf: [0x42, 0x01, 0xCC])  // SPS NALU
        let nalus = processor.extractNALUs(from: data)
        #expect(nalus.count == 2)
        #expect(nalus[0].count == 4)
        #expect(nalus[1].count == 3)
    }

    @Test("Extract NALUs with 3-byte start codes")
    func extractNALUs3ByteStartCode() {
        var data = Data()
        data.append(contentsOf: [0x00, 0x00, 0x01])
        data.append(contentsOf: [0x40, 0x01, 0xFF])
        data.append(contentsOf: [0x00, 0x00, 0x01])
        data.append(contentsOf: [0x42, 0x01, 0xEE])
        let nalus = processor.extractNALUs(from: data)
        #expect(nalus.count == 2)
    }

    @Test("Extract single NALU")
    func extractSingleNALU() {
        var data = Data()
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        data.append(contentsOf: [0x40, 0x01, 0xAA, 0xBB, 0xCC])
        let nalus = processor.extractNALUs(from: data)
        #expect(nalus.count == 1)
        #expect(nalus[0].count == 5)
    }

    // MARK: - annexBToLengthPrefixed

    @Test("Convert Annex B to length-prefixed format")
    func annexBToLengthPrefixed() {
        var data = Data()
        data.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        data.append(contentsOf: [0x40, 0x01, 0xAA])
        let result = processor.annexBToLengthPrefixed(data)
        // 4-byte length (0x00000003) + 3 bytes NALU
        #expect(result.count == 7)
        #expect(result[0] == 0x00)
        #expect(result[1] == 0x00)
        #expect(result[2] == 0x00)
        #expect(result[3] == 0x03)
        #expect(result[4] == 0x40)
    }

    // MARK: - naluType

    @Test("Identify VPS NAL unit type")
    func naluTypeVPS() {
        // VPS: type 32 = (byte >> 1) & 0x3F where byte = 0x40
        let nalu = Data([0x40, 0x01])
        #expect(processor.naluType(nalu) == .vps)
    }

    @Test("Identify SPS NAL unit type")
    func naluTypeSPS() {
        // SPS: type 33 = (byte >> 1) & 0x3F where byte = 0x42
        let nalu = Data([0x42, 0x01])
        #expect(processor.naluType(nalu) == .sps)
    }

    @Test("Identify PPS NAL unit type")
    func naluTypePPS() {
        // PPS: type 34 = (byte >> 1) & 0x3F where byte = 0x44
        let nalu = Data([0x44, 0x01])
        #expect(processor.naluType(nalu) == .pps)
    }

    @Test("Identify IDR NAL unit type")
    func naluTypeIDR() {
        // IDR W RADL: type 19 = (byte >> 1) & 0x3F where byte = 0x26
        let nalu = Data([0x26, 0x01])
        #expect(processor.naluType(nalu) == .idrWRadl)
    }

    @Test("Empty data returns nil type")
    func naluTypeEmpty() {
        #expect(processor.naluType(Data()) == nil)
    }

    // MARK: - HEVCNALUType

    @Test("HEVCNALUType raw values")
    func naluTypeRawValues() {
        #expect(HEVCNALUType.trailN.rawValue == 0)
        #expect(HEVCNALUType.trailR.rawValue == 1)
        #expect(HEVCNALUType.idrWRadl.rawValue == 19)
        #expect(HEVCNALUType.idrNLP.rawValue == 20)
        #expect(HEVCNALUType.vps.rawValue == 32)
        #expect(HEVCNALUType.sps.rawValue == 33)
        #expect(HEVCNALUType.pps.rawValue == 34)
        #expect(HEVCNALUType.prefixSEI.rawValue == 39)
        #expect(HEVCNALUType.suffixSEI.rawValue == 40)
    }

    // MARK: - extractParameterSets

    @Test("Extract parameter sets from NALU array")
    func extractParameterSets() {
        let vps = Data([0x40, 0x01, 0xAA, 0xBB])  // type 32
        let sps = Data([0x42, 0x01, 0xCC, 0xDD])  // type 33
        let pps = Data([0x44, 0x01, 0xEE])  // type 34
        let idr = Data([0x26, 0x01, 0xFF])  // type 19

        let params = processor.extractParameterSets(from: [vps, sps, pps, idr])
        #expect(params != nil)
        #expect(params?.vps == vps)
        #expect(params?.sps == sps)
        #expect(params?.pps == pps)
    }

    @Test("Extract parameter sets returns nil when incomplete")
    func extractParameterSetsIncomplete() {
        let vps = Data([0x40, 0x01, 0xAA])
        let sps = Data([0x42, 0x01, 0xBB])
        // Missing PPS
        let params = processor.extractParameterSets(from: [vps, sps])
        #expect(params == nil)
    }

    // MARK: - parseSPSProfile

    @Test("Parse SPS profile from minimal SPS")
    func parseSPSProfile() {
        // Build a minimal SPS:
        // Byte 0-1: NAL header (SPS type 33 = 0x42, 0x01)
        // Byte 2: vps_id(4b) + max_sub_layers(3b) + nesting(1b)
        // Byte 3: profile_space(2b) + tier_flag(1b) + profile_idc(5b)
        // Bytes 4-7: profile_compatibility_flags
        // Bytes 8-13: constraint_indicator_flags
        // Byte 14: level_idc
        var sps = Data(count: 15)
        sps[0] = 0x42  // NAL type = SPS
        sps[1] = 0x01  // temporal_id
        sps[2] = 0x01  // vps_id=0, max_sub_layers=0, nesting=1
        sps[3] = 0x02  // space=0, tier=0, profile=2 (Main10)
        sps[4] = 0x20  // compat flags
        sps[5] = 0x00
        sps[6] = 0x00
        sps[7] = 0x00
        // constraint indicator flags (6 bytes)
        sps[8] = 0x00
        sps[9] = 0x00
        sps[10] = 0x00
        sps[11] = 0x00
        sps[12] = 0x00
        sps[13] = 0x00
        sps[14] = 123  // level 4.1

        let profile = processor.parseSPSProfile(sps)
        #expect(profile != nil)
        #expect(profile?.profileSpace == 0)
        #expect(profile?.tierFlag == false)
        #expect(profile?.profileIDC == 2)
        #expect(profile?.levelIDC == 123)
        #expect(profile?.bitDepthLuma == 10)  // Main10
        #expect(profile?.bitDepthChroma == 10)
    }

    @Test("Parse SPS profile returns nil for short data")
    func parseSPSProfileTooShort() {
        let sps = Data([0x42, 0x01])
        #expect(processor.parseSPSProfile(sps) == nil)
    }
}
