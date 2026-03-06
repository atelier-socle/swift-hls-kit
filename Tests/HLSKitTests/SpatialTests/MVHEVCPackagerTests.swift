// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MVHEVCPackager")
struct MVHEVCPackagerTests {

    let packager = MVHEVCPackager()
    let config = SpatialVideoConfiguration.visionProStandard

    /// Minimal valid parameter sets for testing.
    var testParameterSets: HEVCParameterSets {
        // Minimal VPS (type 32 = 0x40)
        let vps = Data([0x40, 0x01, 0xAA, 0xBB])
        // Minimal SPS (type 33 = 0x42) with profile_tier_level
        var sps = Data(count: 15)
        sps[0] = 0x42
        sps[1] = 0x01
        sps[2] = 0x01
        sps[3] = 0x42  // space=0, tier=1, profile=2
        sps[4] = 0x20
        sps[5] = 0x00
        sps[6] = 0x00
        sps[7] = 0x00
        sps[8] = 0x00
        sps[9] = 0x00
        sps[10] = 0x00
        sps[11] = 0x00
        sps[12] = 0x00
        sps[13] = 0x00
        sps[14] = 123
        // Minimal PPS (type 34 = 0x44)
        let pps = Data([0x44, 0x01, 0xCC])
        return HEVCParameterSets(vps: vps, sps: sps, pps: pps)
    }

    // MARK: - Init Segment

    @Test("Init segment is non-empty")
    func initSegmentNonEmpty() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        #expect(!data.isEmpty)
    }

    @Test("Init segment starts with ftyp box")
    func initSegmentStartsWithFtyp() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        // ftyp box type at offset 4
        let boxType = String(
            data: data[4..<8],
            encoding: .ascii
        )
        #expect(boxType == "ftyp")
    }

    @Test("Init segment contains moov box")
    func initSegmentContainsMoov() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        #expect(containsFourCC(data, "moov"))
    }

    @Test("Init segment contains hvc1 sample entry")
    func initSegmentContainsHvc1() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        #expect(containsFourCC(data, "hvc1"))
    }

    @Test("Init segment contains hvcC box")
    func initSegmentContainsHvcC() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        #expect(containsFourCC(data, "hvcC"))
    }

    @Test("Init segment contains vexu box")
    func initSegmentContainsVexu() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        #expect(containsFourCC(data, "vexu"))
    }

    @Test("Init segment contains stri box")
    func initSegmentContainsStri() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        #expect(containsFourCC(data, "stri"))
    }

    @Test("Init segment contains hero box")
    func initSegmentContainsHero() {
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: testParameterSets
        )
        #expect(containsFourCC(data, "hero"))
    }

    // MARK: - Media Segment

    @Test("Media segment contains moof and mdat")
    func mediaSegmentContainsMoofAndMdat() {
        let sampleData = Data(repeating: 0xAA, count: 100)
        let data = packager.createMediaSegment(
            nalus: sampleData,
            configuration: config,
            sequenceNumber: 1,
            baseDecodeTime: 0,
            sampleDurations: [3000]
        )
        #expect(containsFourCC(data, "moof"))
        #expect(containsFourCC(data, "mdat"))
    }

    @Test("Multiple media segments with incrementing sequence")
    func multipleMediaSegments() {
        let sampleData = Data(repeating: 0xBB, count: 50)
        let seg1 = packager.createMediaSegment(
            nalus: sampleData,
            configuration: config,
            sequenceNumber: 1,
            baseDecodeTime: 0,
            sampleDurations: [3000]
        )
        let seg2 = packager.createMediaSegment(
            nalus: sampleData,
            configuration: config,
            sequenceNumber: 2,
            baseDecodeTime: 3000,
            sampleDurations: [3000]
        )
        #expect(!seg1.isEmpty)
        #expect(!seg2.isEmpty)
        #expect(seg1 != seg2)
    }

    // MARK: - Configuration Variants

    @Test("Mono channel layout produces valid init segment")
    func monoChannelLayout() {
        let monoConfig = SpatialVideoConfiguration(
            baseLayerCodec: "hvc1.2.4.L123.B0",
            channelLayout: .mono,
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )
        let data = packager.createInitSegment(
            configuration: monoConfig,
            parameterSets: testParameterSets
        )
        #expect(!data.isEmpty)
        #expect(containsFourCC(data, "stri"))
    }

    @Test("Dolby Vision config produces valid init segment")
    func dolbyVisionConfig() {
        let dvConfig = SpatialVideoConfiguration.dolbyVisionStereo
        let data = packager.createInitSegment(
            configuration: dvConfig,
            parameterSets: testParameterSets
        )
        #expect(!data.isEmpty)
        #expect(containsFourCC(data, "vexu"))
    }

    // MARK: - Timescale

    @Test(
        "Timescale for various frame rates",
        arguments: [
            (60.0, UInt32(90000)),
            (24.0, UInt32(48000)),
            (25.0, UInt32(50000)),
            (29.97, UInt32(29970))
        ]
    )
    func timescaleFrameRates(frameRate: Double, expected: UInt32) {
        let result = packager.timescaleFromFrameRate(frameRate)
        #expect(result == expected)
    }

    // MARK: - Multi-Sample Media Segments

    @Test("Media segment with multiple sample durations")
    func multiSampleMediaSegment() {
        let sampleData = Data(repeating: 0xCC, count: 200)
        let data = packager.createMediaSegment(
            nalus: sampleData,
            configuration: config,
            sequenceNumber: 1,
            baseDecodeTime: 0,
            sampleDurations: [1500, 1500]
        )
        #expect(!data.isEmpty)
        #expect(containsFourCC(data, "trun"))
    }

    @Test("Sample sizes distribute with remainder")
    func sampleSizesRemainder() {
        let data = Data(repeating: 0xDD, count: 101)
        let sizes = packager.computeSampleSizes(from: data, count: 3)
        #expect(sizes.count == 3)
        let total = sizes.reduce(0, +)
        #expect(total == 101)
    }

    @Test("Sample sizes for empty data")
    func sampleSizesEmpty() {
        let sizes = packager.computeSampleSizes(from: Data(), count: 0)
        #expect(sizes.count == 1)
        #expect(sizes[0] == 0)
    }

    // MARK: - hvcC Fallback Branch

    @Test("Init segment with minimal SPS uses hvcC fallback")
    func hvcCFallbackBranch() {
        // SPS too short to parse profile — triggers fallback
        let minimalSets = HEVCParameterSets(
            vps: Data([0x40, 0x01]),
            sps: Data([0x42, 0x01]),
            pps: Data([0x44, 0x01])
        )
        let data = packager.createInitSegment(
            configuration: config,
            parameterSets: minimalSets
        )
        #expect(!data.isEmpty)
        #expect(containsFourCC(data, "hvcC"))
        #expect(containsFourCC(data, "vexu"))
    }

    // MARK: - Helpers

    private func containsFourCC(_ data: Data, _ fourCC: String) -> Bool {
        let target = Data(fourCC.utf8)
        guard target.count == 4, data.count >= 4 else { return false }
        return (0...(data.count - 4)).contains { i in
            data[data.startIndex + i..<data.startIndex + i + 4] == target
        }
    }
}
