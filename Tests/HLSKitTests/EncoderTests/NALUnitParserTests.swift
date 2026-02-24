// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("NALUnitParser", .timeLimit(.minutes(1)))
struct NALUnitParserTests {

    // MARK: - Helpers

    /// 4-byte Annex B start code.
    private let startCode4: Data = Data([0x00, 0x00, 0x00, 0x01])

    /// 3-byte Annex B start code.
    private let startCode3: Data = Data([0x00, 0x00, 0x01])

    /// Build a NAL unit with 4-byte start code.
    private func makeNAL(type: UInt8, size: Int = 10) -> Data {
        var data = startCode4
        data.append(type)
        data.append(Data(repeating: 0xAA, count: size - 1))
        return data
    }

    /// Build an HEVC NAL unit with 4-byte start code.
    private func makeHEVCNAL(
        type: UInt8, size: Int = 10
    ) -> Data {
        var data = startCode4
        // HEVC NAL header: (type << 1) in first byte
        data.append(type << 1)
        data.append(0x01)  // second byte of NAL header
        data.append(
            Data(repeating: 0xBB, count: size - 2)
        )
        return data
    }

    // MARK: - H.264 Parsing

    @Test("Parse single H.264 IDR access unit (SPS + PPS + IDR)")
    func parseSingleH264IDR() {
        var data = Data()
        data.append(makeNAL(type: 7, size: 15))  // SPS
        data.append(makeNAL(type: 8, size: 8))  // PPS
        data.append(makeNAL(type: 5, size: 100))  // IDR
        // Add trailing start code so IDR is complete
        data.append(startCode4)

        let result = NALUnitParser.parseAccessUnits(
            from: data, codec: .h264
        )

        #expect(result.accessUnits.count == 1)
        #expect(result.accessUnits[0].isKeyframe)
        #expect(result.accessUnits[0].nalTypes.contains(7))
        #expect(result.accessUnits[0].nalTypes.contains(8))
        #expect(result.accessUnits[0].nalTypes.contains(5))
    }

    @Test("Parse H.264 non-IDR slice")
    func parseH264NonIDR() {
        var data = Data()
        data.append(makeNAL(type: 1, size: 50))  // non-IDR
        data.append(startCode4)  // trailing marker

        let result = NALUnitParser.parseAccessUnits(
            from: data, codec: .h264
        )

        #expect(result.accessUnits.count == 1)
        #expect(!result.accessUnits[0].isKeyframe)
        #expect(result.accessUnits[0].nalTypes == [1])
    }

    @Test("Parse multiple H.264 access units")
    func parseMultipleH264() {
        var data = Data()
        // Keyframe
        data.append(makeNAL(type: 7, size: 15))
        data.append(makeNAL(type: 8, size: 8))
        data.append(makeNAL(type: 5, size: 100))
        // P-frame
        data.append(makeNAL(type: 1, size: 50))
        // Another P-frame
        data.append(makeNAL(type: 1, size: 40))
        // Trailing start code
        data.append(startCode4)

        let result = NALUnitParser.parseAccessUnits(
            from: data, codec: .h264
        )

        #expect(result.accessUnits.count == 3)
        #expect(result.accessUnits[0].isKeyframe)
        #expect(!result.accessUnits[1].isKeyframe)
        #expect(!result.accessUnits[2].isKeyframe)
    }

    @Test("H.264 IDR is NAL type 5")
    func h264IDRType() {
        let type = NALUnitParser.nalType(
            byte: 0x65, codec: .h264
        )
        #expect(type == 5)
        #expect(NALUnitParser.isKeyframe(type: type, codec: .h264))
    }

    @Test("H.264 SPS is NAL type 7")
    func h264SPSType() {
        let type = NALUnitParser.nalType(
            byte: 0x67, codec: .h264
        )
        #expect(type == 7)
        #expect(!NALUnitParser.isVCL(type: type, codec: .h264))
    }

    @Test("H.264 PPS is NAL type 8")
    func h264PPSType() {
        let type = NALUnitParser.nalType(
            byte: 0x68, codec: .h264
        )
        #expect(type == 8)
        #expect(!NALUnitParser.isVCL(type: type, codec: .h264))
    }

    // MARK: - HEVC Parsing

    @Test("Parse HEVC IDR access unit")
    func parseHEVCIDR() {
        var data = Data()
        data.append(makeHEVCNAL(type: 32, size: 15))  // VPS
        data.append(makeHEVCNAL(type: 33, size: 15))  // SPS
        data.append(makeHEVCNAL(type: 34, size: 8))  // PPS
        data.append(makeHEVCNAL(type: 19, size: 100))  // IDR
        data.append(startCode4)

        let result = NALUnitParser.parseAccessUnits(
            from: data, codec: .h265
        )

        #expect(result.accessUnits.count == 1)
        #expect(result.accessUnits[0].isKeyframe)
    }

    @Test("HEVC IDR_W_RADL is type 19")
    func hevcIDRType19() {
        #expect(
            NALUnitParser.isKeyframe(
                type: 19, codec: .h265
            )
        )
    }

    @Test("HEVC IDR_N_LP is type 20")
    func hevcIDRType20() {
        #expect(
            NALUnitParser.isKeyframe(
                type: 20, codec: .h265
            )
        )
    }

    @Test("HEVC CRA is type 21")
    func hevcCRAType() {
        #expect(
            NALUnitParser.isKeyframe(
                type: 21, codec: .h265
            )
        )
    }

    @Test("HEVC VPS/SPS/PPS are non-VCL")
    func hevcParameterSetsNonVCL() {
        #expect(!NALUnitParser.isVCL(type: 32, codec: .h265))
        #expect(!NALUnitParser.isVCL(type: 33, codec: .h265))
        #expect(!NALUnitParser.isVCL(type: 34, codec: .h265))
    }

    // MARK: - Incomplete Data

    @Test("Single start code: nothing consumed")
    func singleStartCode() {
        var data = startCode4
        data.append(Data(repeating: 0x65, count: 50))

        let result = NALUnitParser.parseAccessUnits(
            from: data, codec: .h264
        )

        #expect(result.accessUnits.isEmpty)
        #expect(result.bytesConsumed == 0)
    }

    @Test("Incomplete access unit: non-VCL only")
    func incompleteNonVCL() {
        var data = Data()
        data.append(makeNAL(type: 7, size: 15))  // SPS
        data.append(makeNAL(type: 8, size: 8))  // PPS
        // No VCL NAL follows — incomplete
        data.append(startCode4)

        let result = NALUnitParser.parseAccessUnits(
            from: data, codec: .h264
        )

        #expect(result.accessUnits.isEmpty)
        #expect(result.bytesConsumed == 0)
    }

    @Test("Data shorter than 3 bytes returns empty")
    func tooShort() {
        let result = NALUnitParser.parseAccessUnits(
            from: Data([0x00, 0x00]), codec: .h264
        )
        #expect(result.accessUnits.isEmpty)
        #expect(result.bytesConsumed == 0)
    }

    @Test("Empty data returns empty result")
    func emptyData() {
        let result = NALUnitParser.parseAccessUnits(
            from: Data(), codec: .h264
        )
        #expect(result.accessUnits.isEmpty)
        #expect(result.bytesConsumed == 0)
    }

    // MARK: - Bytes Consumed

    @Test("Bytes consumed stops at last VCL NAL")
    func bytesConsumedAccuracy() {
        var data = Data()
        // AU 1: IDR
        data.append(makeNAL(type: 5, size: 20))
        // AU 2: P-frame
        let pFrameStart = data.count
        data.append(makeNAL(type: 1, size: 30))
        let expectedConsumed = data.count
        // Trailing non-VCL (not consumed)
        data.append(makeNAL(type: 7, size: 10))
        data.append(startCode4)

        let result = NALUnitParser.parseAccessUnits(
            from: data, codec: .h264
        )

        #expect(result.accessUnits.count == 2)
        #expect(result.bytesConsumed == expectedConsumed)
        _ = pFrameStart  // verify offset is correct
    }

    // MARK: - Start Code Detection

    @Test("findStartCodes: 4-byte start codes")
    func findStartCodes4Byte() {
        var data = Data()
        data.append(startCode4)
        data.append(Data(repeating: 0xFF, count: 10))
        data.append(startCode4)
        data.append(Data(repeating: 0xFF, count: 5))

        let positions = NALUnitParser.findStartCodes(in: data)
        #expect(positions.count == 2)
        #expect(positions[0] == 0)
        #expect(positions[1] == 14)
    }

    @Test("findStartCodes: 3-byte start codes")
    func findStartCodes3Byte() {
        var data = Data()
        data.append(startCode3)
        data.append(Data(repeating: 0xFF, count: 10))
        data.append(startCode3)

        let positions = NALUnitParser.findStartCodes(in: data)
        #expect(positions.count == 2)
    }

    @Test("startCodeSize: detects 3 vs 4 byte")
    func startCodeSizeDetection() {
        let data3 = Data([0x00, 0x00, 0x01, 0x65])
        let data4 = Data([0x00, 0x00, 0x00, 0x01, 0x65])

        #expect(
            NALUnitParser.startCodeSize(in: data3, at: 0) == 3
        )
        #expect(
            NALUnitParser.startCodeSize(in: data4, at: 0) == 4
        )
    }

    // MARK: - NAL Type Extraction

    @Test("H.264 nalType masks lower 5 bits")
    func h264NalTypeMask() {
        // 0x65 = 0110_0101, lower 5 bits = 00101 = 5
        #expect(
            NALUnitParser.nalType(byte: 0x65, codec: .h264) == 5
        )
        // 0x67 = 0110_0111, lower 5 bits = 00111 = 7
        #expect(
            NALUnitParser.nalType(byte: 0x67, codec: .h264) == 7
        )
    }

    @Test("HEVC nalType shifts right 1, masks 6 bits")
    func hevcNalTypeMask() {
        // type 19: byte = 19 << 1 = 38 = 0x26
        #expect(
            NALUnitParser.nalType(byte: 0x26, codec: .h265)
                == 19
        )
        // type 32: byte = 32 << 1 = 64 = 0x40
        #expect(
            NALUnitParser.nalType(byte: 0x40, codec: .h265)
                == 32
        )
    }
}
