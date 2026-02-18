// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AnnexBConverter")
struct AnnexBConverterTests {

    // MARK: - NAL unit conversion

    @Test("Convert single NAL unit: length prefix → start code")
    func convertSingleNAL() {
        let converter = AnnexBConverter()
        let nalData = Data([0x65, 0xAA, 0xBB, 0xCC])
        var input = Data()
        // 4-byte length prefix (big-endian)
        input.append(contentsOf: [0x00, 0x00, 0x00, 0x04])
        input.append(nalData)

        let result = converter.convertToAnnexB(input)

        // Should have start code + NAL data
        let expected = Data(
            [0x00, 0x00, 0x00, 0x01, 0x65, 0xAA, 0xBB, 0xCC]
        )
        #expect(result == expected)
    }

    @Test("Convert multiple NAL units in sequence")
    func convertMultipleNALs() {
        let converter = AnnexBConverter()
        var input = Data()
        // First NAL: 2 bytes
        input.append(contentsOf: [0x00, 0x00, 0x00, 0x02])
        input.append(contentsOf: [0x67, 0xAA])
        // Second NAL: 3 bytes
        input.append(contentsOf: [0x00, 0x00, 0x00, 0x03])
        input.append(contentsOf: [0x68, 0xBB, 0xCC])

        let result = converter.convertToAnnexB(input)

        var expected = Data()
        expected.append(
            contentsOf: [0x00, 0x00, 0x00, 0x01, 0x67, 0xAA]
        )
        expected.append(
            contentsOf: [
                0x00, 0x00, 0x00, 0x01, 0x68, 0xBB, 0xCC
            ]
        )
        #expect(result == expected)
    }

    @Test("Convert empty data returns empty")
    func convertEmptyData() {
        let converter = AnnexBConverter()
        let result = converter.convertToAnnexB(Data())
        #expect(result.isEmpty)
    }

    // MARK: - avcC parameter set extraction

    @Test("Extract SPS/PPS from avcC data")
    func extractParameterSets() throws {
        let converter = AnnexBConverter()
        let avcC = buildTestAvcC(
            sps: [Data([0x67, 0x42, 0xC0, 0x1E])],
            pps: [Data([0x68, 0xCE, 0x38, 0x80])]
        )
        let (sps, pps) = try converter.extractParameterSets(
            from: avcC
        )

        // SPS should be start code + SPS NAL
        let expectedSPS = Data([
            0x00, 0x00, 0x00, 0x01,
            0x67, 0x42, 0xC0, 0x1E
        ])
        #expect(sps == expectedSPS)

        // PPS should be start code + PPS NAL
        let expectedPPS = Data([
            0x00, 0x00, 0x00, 0x01,
            0x68, 0xCE, 0x38, 0x80
        ])
        #expect(pps == expectedPPS)
    }

    @Test("avcC with multiple SPS entries")
    func extractMultipleSPS() throws {
        let converter = AnnexBConverter()
        let avcC = buildTestAvcC(
            sps: [
                Data([0x67, 0x42, 0xC0, 0x1E]),
                Data([0x67, 0x64, 0x00, 0x28])
            ],
            pps: [Data([0x68, 0xCE, 0x38, 0x80])]
        )
        let (sps, _) = try converter.extractParameterSets(
            from: avcC
        )
        // Should contain two start codes
        var startCodeCount = 0
        let startCode = Data([0x00, 0x00, 0x00, 0x01])
        var searchOffset = sps.startIndex
        while searchOffset + 4 <= sps.endIndex {
            if sps[searchOffset..<(searchOffset + 4)]
                == startCode
            {
                startCodeCount += 1
            }
            searchOffset += 1
        }
        #expect(startCodeCount == 2)
    }

    @Test("Invalid avcC → error")
    func invalidAvcCThrows() {
        let converter = AnnexBConverter()
        let tooShort = Data([0x01, 0x42])
        #expect(throws: TransportError.self) {
            try converter.extractParameterSets(from: tooShort)
        }
    }

    @Test("avcC with wrong version → error")
    func wrongVersionThrows() {
        let converter = AnnexBConverter()
        // Version 2 instead of 1
        var avcC = Data(repeating: 0, count: 8)
        avcC[0] = 2  // wrong version
        #expect(throws: TransportError.self) {
            try converter.extractParameterSets(from: avcC)
        }
    }

    @Test("Truncated avcC missing SPS count → error")
    func truncatedMissingSPSCount() {
        let converter = AnnexBConverter()
        // Version 1, profile, compat, level, lengthSize — but no SPS count
        let avcC = Data([0x01, 0x42, 0xC0, 0x1E, 0xFF])
        #expect(throws: TransportError.self) {
            try converter.extractParameterSets(from: avcC)
        }
    }

    @Test("Truncated avcC missing PPS count → error")
    func truncatedMissingPPSCount() {
        let converter = AnnexBConverter()
        // avcC with 0 SPS entries but missing PPS byte
        var avcC = Data([0x01, 0x42, 0xC0, 0x1E, 0xFF])
        avcC.append(0xE0)  // numSPS = 0
        #expect(throws: TransportError.self) {
            try converter.extractParameterSets(from: avcC)
        }
    }

    @Test("Truncated SPS data → error")
    func truncatedSPSData() {
        let converter = AnnexBConverter()
        var avcC = Data([0x01, 0x42, 0xC0, 0x1E, 0xFF])
        avcC.append(0xE1)  // numSPS = 1
        avcC.append(contentsOf: [0x00, 0x10])  // SPS len=16
        avcC.append(contentsOf: [0x67])  // only 1 byte
        #expect(throws: TransportError.self) {
            try converter.extractParameterSets(from: avcC)
        }
    }

    @Test("Truncated PPS data → error")
    func truncatedPPSData() {
        let converter = AnnexBConverter()
        var avcC = Data([0x01, 0x42, 0xC0, 0x1E, 0xFF])
        avcC.append(0xE0)  // numSPS = 0
        avcC.append(0x01)  // numPPS = 1
        avcC.append(contentsOf: [0x00, 0x10])  // PPS len=16
        avcC.append(contentsOf: [0x68])  // only 1 byte
        #expect(throws: TransportError.self) {
            try converter.extractParameterSets(from: avcC)
        }
    }

    // MARK: - Keyframe access unit

    @Test("Build keyframe access unit: SPS + PPS + NAL units")
    func buildKeyframeAccessUnit() {
        let converter = AnnexBConverter()
        let sps = Data([0x00, 0x00, 0x00, 0x01, 0x67, 0x42])
        let pps = Data([0x00, 0x00, 0x00, 0x01, 0x68, 0xCE])

        var sampleData = Data()
        sampleData.append(
            contentsOf: [0x00, 0x00, 0x00, 0x03]
        )
        sampleData.append(contentsOf: [0x65, 0xAA, 0xBB])

        let result = converter.buildKeyframeAccessUnit(
            sampleData: sampleData,
            sps: sps,
            pps: pps
        )

        // Should start with SPS
        #expect(
            Data(result[0..<6]) == sps
        )
        // Then PPS
        #expect(
            Data(result[6..<12]) == pps
        )
        // Then converted NAL data
        let expectedNAL = Data([
            0x00, 0x00, 0x00, 0x01, 0x65, 0xAA, 0xBB
        ])
        #expect(
            Data(result[12..<19]) == expectedNAL
        )
    }
}

// MARK: - Test Helpers

extension AnnexBConverterTests {

    /// Build a test avcC box payload.
    private func buildTestAvcC(
        sps: [Data],
        pps: [Data]
    ) -> Data {
        var data = Data()
        // configurationVersion = 1
        data.append(1)
        // AVCProfileIndication
        data.append(0x42)
        // profile_compatibility
        data.append(0xC0)
        // AVCLevelIndication
        data.append(0x1E)
        // lengthSizeMinusOne (0xFF = 3+reserved)
        data.append(0xFF)

        // numSPS (0xE0 | count) — high 3 bits reserved
        data.append(UInt8(0xE0 | (sps.count & 0x1F)))
        for spsNal in sps {
            let length = UInt16(spsNal.count)
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
            data.append(spsNal)
        }

        // numPPS
        data.append(UInt8(pps.count))
        for ppsNal in pps {
            let length = UInt16(ppsNal.count)
            data.append(UInt8((length >> 8) & 0xFF))
            data.append(UInt8(length & 0xFF))
            data.append(ppsNal)
        }

        return data
    }
}
