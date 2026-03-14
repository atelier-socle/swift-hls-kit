// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - HEVC Init Segment (hev1 + hvcC)

@Suite(
    "HEVC codec config — hev1 + hvcC in init segment",
    .timeLimit(.minutes(1))
)
struct HEVCInitSegmentTests {

    let writer = CMAFWriter()

    // Minimal HEVC parameter sets for testing.
    // VPS: 2-byte NAL header + minimal payload
    private let testVPS = Data([
        0x40, 0x01, 0x0C, 0x01, 0xFF, 0xFF, 0x01, 0x60,
        0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00,
        0x03, 0x00, 0x00, 0x03, 0x00, 0x5D, 0xAC, 0x09
    ])

    // SPS: 2-byte NAL header + profile_tier_level + payload
    private let testSPS = Data([
        0x42, 0x01, 0x01, 0x01, 0x60, 0x00, 0x00, 0x03,
        0x00, 0x00, 0x03, 0x00, 0x00, 0x03, 0x00, 0x00,
        0x03, 0x00, 0x5D, 0xA0, 0x02, 0x80, 0x80, 0x2D
    ])

    // PPS: 2-byte NAL header + minimal payload
    private let testPPS = Data([
        0x44, 0x01, 0xC1, 0x72, 0xB4, 0x62, 0x40
    ])

    private func readBoxes(
        from data: Data
    ) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    private func hevcConfig(
        width: Int = 3840, height: Int = 2160
    ) -> CMAFWriter.VideoConfig {
        CMAFWriter.VideoConfig(
            codec: .h265,
            width: width, height: height,
            sps: testSPS, pps: testPPS, vps: testVPS
        )
    }

    private func containsFourCC(
        _ fourCC: String, in data: Data
    ) -> Bool {
        let pattern = Data(fourCC.utf8)
        guard pattern.count == 4, data.count >= 4 else {
            return false
        }
        let range = data.startIndex...(data.endIndex - 4)
        return range.contains {
            data[$0..<($0 + 4)] == pattern
        }
    }

    private func findFourCCOffset(
        _ fourCC: String, in data: Data
    ) -> Int? {
        let pattern = Data(fourCC.utf8)
        guard pattern.count == 4, data.count >= 4 else {
            return nil
        }
        for i in 0...(data.count - 4) {
            let start = data.startIndex + i
            if data[start..<(start + 4)] == pattern {
                return i
            }
        }
        return nil
    }

    private func stsdPayload(
        from config: CMAFWriter.VideoConfig
    ) throws -> Data {
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let trak = try #require(moov.findChild("trak"))
        let mdia = try #require(trak.findChild("mdia"))
        let minf = try #require(mdia.findChild("minf"))
        let stbl = try #require(minf.findChild("stbl"))
        let stsd = try #require(stbl.findChild("stsd"))
        return try #require(stsd.payload)
    }

    // MARK: - Structure Tests

    @Test("HEVC init segment starts with ftyp")
    func initSegmentStartsWithFtyp() throws {
        let data = writer.generateVideoInitSegment(
            config: hevcConfig()
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.first?.type == "ftyp")
    }

    @Test("HEVC init segment contains moov")
    func initSegmentContainsMoov() throws {
        let data = writer.generateVideoInitSegment(
            config: hevcConfig()
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.contains { $0.type == "moov" })
    }

    @Test("HEVC stsd contains hev1 fourCC")
    func stsdContainsHev1() throws {
        let payload = try stsdPayload(from: hevcConfig())
        #expect(containsFourCC("hev1", in: payload))
    }

    @Test("HEVC stsd does NOT contain avc1")
    func stsdDoesNotContainAvc1() throws {
        let payload = try stsdPayload(from: hevcConfig())
        #expect(!containsFourCC("avc1", in: payload))
    }

    @Test("HEVC stsd contains hvcC inside hev1")
    func stsdContainsHvcC() throws {
        let payload = try stsdPayload(from: hevcConfig())
        #expect(containsFourCC("hvcC", in: payload))
    }

    @Test("hev1 VisualSampleEntry is 78 bytes before hvcC")
    func hev1VisualSampleEntryLayout() throws {
        let payload = try stsdPayload(from: hevcConfig())
        let hev1Offset = try #require(
            findFourCCOffset("hev1", in: payload)
        )
        // hev1 box: 4 type + 78 VisualSampleEntry body
        // then hvcC box starts (4-byte size + "hvcC")
        let hvcCExpected = hev1Offset + 4 + 78
        let fourCCStart = payload.startIndex + hvcCExpected + 4
        let fourCCEnd = fourCCStart + 4
        #expect(fourCCEnd <= payload.endIndex)
        let fourCC = String(
            data: payload[fourCCStart..<fourCCEnd],
            encoding: .utf8
        )
        #expect(
            fourCC == "hvcC",
            "hvcC must start at offset 78 in hev1"
        )
    }

    @Test("hvcC configurationVersion is 1")
    func hvcCConfigVersion() throws {
        let payload = try stsdPayload(from: hevcConfig())
        let hvcCOffset = try #require(
            findFourCCOffset("hvcC", in: payload)
        )
        // After "hvcC" fourCC, payload starts
        let configVersion =
            payload[payload.startIndex + hvcCOffset + 4]
        #expect(configVersion == 1)
    }

    @Test("hvcC contains 3 NALU arrays (VPS+SPS+PPS)")
    func hvcCHasThreeArrays() throws {
        let payload = try stsdPayload(from: hevcConfig())
        let hvcCOffset = try #require(
            findFourCCOffset("hvcC", in: payload)
        )
        // numOfArrays at byte 22 after "hvcC" fourCC
        let numArraysIdx =
            payload.startIndex + hvcCOffset + 4 + 22
        #expect(numArraysIdx < payload.endIndex)
        #expect(payload[numArraysIdx] == 3)
    }

    @Test("hvcC level_idc extracted from SPS")
    func hvcCLevelFromSPS() throws {
        let payload = try stsdPayload(from: hevcConfig())
        let hvcCOffset = try #require(
            findFourCCOffset("hvcC", in: payload)
        )
        // level_idc at byte 12 after "hvcC" fourCC
        let levelIdx =
            payload.startIndex + hvcCOffset + 4 + 12
        #expect(levelIdx < payload.endIndex)
        // testSPS after NAL header: byte[0]=sps_header,
        // byte[1]=profile, byte[2..5]=compat,
        // byte[6..11]=constraint, byte[12]=level_idc
        // testSPS[14] = 0x00
        let expectedLevel = testSPS[testSPS.startIndex + 14]
        #expect(payload[levelIdx] == expectedLevel)
    }

    // MARK: - H.264 Backward Compatibility

    @Test("H.264 config still produces avc1")
    func h264StillProducesAvc1() throws {
        let config = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1920, height: 1080,
            sps: Data([
                0x67, 0x42, 0xC0, 0x1E, 0xD9, 0x00, 0xA0,
                0x47, 0xFE, 0xC8
            ]),
            pps: Data([0x68, 0xCE, 0x38, 0x80])
        )
        let payload = try stsdPayload(from: config)
        #expect(containsFourCC("avc1", in: payload))
        #expect(!containsFourCC("hev1", in: payload))
    }

    // MARK: - VideoConfig VPS Field

    @Test("VideoConfig vps defaults to nil")
    func vpsDefaultsToNil() {
        let config = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1920, height: 1080,
            sps: Data([0x67]), pps: Data([0x68])
        )
        #expect(config.vps == nil)
    }

    @Test("VideoConfig stores vps")
    func vpsStored() {
        let vps = Data([0x40, 0x01, 0x0C])
        let config = CMAFWriter.VideoConfig(
            codec: .h265,
            width: 3840, height: 2160,
            sps: Data([0x42]), pps: Data([0x44]),
            vps: vps
        )
        #expect(config.vps == vps)
    }

    @Test("HEVC without VPS produces 2 arrays")
    func hevcWithoutVPS() throws {
        let config = CMAFWriter.VideoConfig(
            codec: .h265,
            width: 1920, height: 1080,
            sps: testSPS, pps: testPPS
        )
        let payload = try stsdPayload(from: config)
        let hvcCOffset = try #require(
            findFourCCOffset("hvcC", in: payload)
        )
        let numArraysIdx =
            payload.startIndex + hvcCOffset + 4 + 22
        #expect(numArraysIdx < payload.endIndex)
        #expect(payload[numArraysIdx] == 2)
    }
}
