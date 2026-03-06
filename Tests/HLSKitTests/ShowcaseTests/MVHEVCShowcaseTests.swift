// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - MV-HEVC Showcase

@Suite("MV-HEVC Showcase — Spatial Video Packaging & Configuration")
struct MVHEVCShowcaseTests {

    // MARK: - Presets

    @Test("SpatialVideoConfiguration presets — visionProStandard, visionProHighQuality, dolbyVisionStereo")
    func spatialVideoPresets() {
        let standard = SpatialVideoConfiguration.visionProStandard
        #expect(standard.width == 1920)
        #expect(standard.height == 1080)
        #expect(standard.frameRate == 30.0)
        #expect(standard.channelLayout == .stereoLeftRight)
        #expect(standard.dolbyVisionProfile == nil)

        let highQuality = SpatialVideoConfiguration.visionProHighQuality
        #expect(highQuality.width == 3840)
        #expect(highQuality.height == 2160)
        #expect(highQuality.frameRate == 30.0)
        #expect(highQuality.channelLayout == .stereoLeftRight)

        let dolby = SpatialVideoConfiguration.dolbyVisionStereo
        #expect(dolby.dolbyVisionProfile == 20)
        #expect(dolby.supplementalCodecs == "dvh1.20.09/db4h")
        #expect(dolby.width == 3840)
        #expect(dolby.height == 2160)
        #expect(dolby.channelLayout == .stereoLeftRight)
    }

    @Test("VideoChannelLayout raw values — stereoLeftRight and mono")
    func videoChannelLayoutRawValues() {
        #expect(VideoChannelLayout.stereoLeftRight.rawValue == "CH-STEREO")
        #expect(VideoChannelLayout.mono.rawValue == "CH-MONO")
    }

    // MARK: - Sample Processing

    @Test("MVHEVCSampleProcessor.extractNALUs from synthetic Annex B data")
    func extractNALUs() {
        let processor = MVHEVCSampleProcessor()

        var annexB = Data()
        // VPS NALU (type 32 = 0x40 >> 1 & 0x3F)
        annexB.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        annexB.append(contentsOf: [0x40, 0x01, 0xAA])
        // SPS NALU (type 33 = 0x42 >> 1 & 0x3F)
        annexB.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        annexB.append(contentsOf: [0x42, 0x01, 0xBB])
        // PPS NALU (type 34 = 0x44 >> 1 & 0x3F)
        annexB.append(contentsOf: [0x00, 0x00, 0x00, 0x01])
        annexB.append(contentsOf: [0x44, 0x01, 0xCC])

        let nalus = processor.extractNALUs(from: annexB)

        #expect(nalus.count == 3)
        #expect(nalus[0].count == 3)
        #expect(nalus[1].count == 3)
        #expect(nalus[2].count == 3)
    }

    @Test("MVHEVCSampleProcessor.naluType identifies VPS(32), SPS(33), PPS(34)")
    func naluTypeIdentification() {
        let processor = MVHEVCSampleProcessor()

        // VPS: first byte 0x40 -> (0x40 >> 1) & 0x3F = 32
        let vpsNalu = Data([0x40, 0x01, 0xAA])
        #expect(processor.naluType(vpsNalu) == .vps)

        // SPS: first byte 0x42 -> (0x42 >> 1) & 0x3F = 33
        let spsNalu = Data([0x42, 0x01, 0xBB])
        #expect(processor.naluType(spsNalu) == .sps)

        // PPS: first byte 0x44 -> (0x44 >> 1) & 0x3F = 34
        let ppsNalu = Data([0x44, 0x01, 0xCC])
        #expect(processor.naluType(ppsNalu) == .pps)

        // IDR W RADL: first byte 0x26 -> (0x26 >> 1) & 0x3F = 19
        let idrNalu = Data([0x26, 0x01])
        #expect(processor.naluType(idrNalu) == .idrWRadl)

        // TRAIL_R: first byte 0x02 -> (0x02 >> 1) & 0x3F = 1
        let trailNalu = Data([0x02, 0x01])
        #expect(processor.naluType(trailNalu) == .trailR)
    }

    @Test("MVHEVCPackager.createInitSegment — verify contains vexu, stri, hero boxes")
    func createInitSegmentWithSpatialBoxes() {
        let packager = MVHEVCPackager()

        // Build synthetic parameter sets
        let vps = Data([0x40, 0x01, 0x0C, 0x01, 0xFF, 0xFF])
        let sps = buildMinimalSPS()
        let pps = Data([0x44, 0x01, 0xC1, 0x73, 0xD0, 0x89])

        let parameterSets = HEVCParameterSets(
            vps: vps,
            sps: sps,
            pps: pps
        )
        let config = SpatialVideoConfiguration.visionProStandard
        let initSegment = packager.createInitSegment(
            configuration: config,
            parameterSets: parameterSets
        )

        #expect(initSegment.count > 0)
        #expect(containsFourCC(initSegment, "ftyp"))
        #expect(containsFourCC(initSegment, "moov"))
        #expect(containsFourCC(initSegment, "vexu"))
        #expect(containsFourCC(initSegment, "stri"))
        #expect(containsFourCC(initSegment, "hero"))
        #expect(containsFourCC(initSegment, "hvc1"))
        #expect(containsFourCC(initSegment, "hvcC"))
    }

    // MARK: - Supplemental Codecs

    @Test("SupplementalCodecs presets — dolbyVisionProfile20 and dolbyVisionProfile8")
    func supplementalCodecsPresets() {
        let dv20 = SupplementalCodecs.dolbyVisionProfile20
        #expect(dv20.value == "dvh1.20.09/db4h")
        #expect(dv20.description == "dvh1.20.09/db4h")

        let dv8 = SupplementalCodecs.dolbyVisionProfile8
        #expect(dv8.value == "dvh1.08.09/db4h")

        let custom = SupplementalCodecs("custom.codec/test")
        #expect(custom.value == "custom.codec/test")
    }

    @Test("Parse manifest with SUPPLEMENTAL-CODECS — verify variant.supplementalCodecs")
    func parseManifestWithSupplementalCodecs() throws {
        let m3u8 = """
            #EXTM3U
            #EXT-X-VERSION:7
            #EXT-X-STREAM-INF:BANDWIDTH=15000000,\
            CODECS="hvc1.2.4.L153.B0",\
            RESOLUTION=3840x2160,\
            SUPPLEMENTAL-CODECS="dvh1.20.09/db4h"
            spatial/4k_dv.m3u8
            """
        let parser = ManifestParser()
        let manifest = try parser.parse(m3u8)

        guard case .master(let playlist) = manifest else {
            Issue.record("Expected .master manifest")
            return
        }
        #expect(playlist.variants.count == 1)
        #expect(playlist.variants[0].supplementalCodecs == "dvh1.20.09/db4h")

        let typed = playlist.variants[0].supplementalCodecsValue
        #expect(typed?.value == "dvh1.20.09/db4h")
    }

    @Test("LivePipelineConfiguration.spatialVideo() — verify video enabled, resolution")
    func spatialVideoPipelinePreset() {
        let config = LivePipelineConfiguration.spatialVideo()
        #expect(config.videoEnabled == true)
        #expect(config.videoBitrate == 10_000_000)

        let dvConfig = LivePipelineConfiguration.spatialVideo(
            channelLayout: .stereoLeftRight,
            dolbyVision: true
        )
        #expect(dvConfig.videoEnabled == true)
        #expect(dvConfig.videoBitrate == 15_000_000)
    }

    // MARK: - Helpers

    private func containsFourCC(_ data: Data, _ fourCC: String) -> Bool {
        let target = Data(fourCC.utf8)
        guard target.count == 4, data.count >= 4 else { return false }
        return data.range(of: target) != nil
    }

    /// Builds a minimal SPS NAL unit with enough bytes for profile parsing.
    /// Layout: [NAL header (2 bytes)][vps_id+sublayers (1 byte)]
    ///         [PTL byte][compat flags (4)][constraint (6)][level]
    private func buildMinimalSPS() -> Data {
        var sps = Data()
        // NAL header: type 33 -> 0x42, 0x01
        sps.append(contentsOf: [0x42, 0x01])
        // Byte 2: vps_id(4b)=0, max_sub_layers(3b)=0, nesting(1b)=1
        sps.append(0x01)
        // Byte 3 (PTL): profile_space=0, tier=0, profile_idc=2 (Main10)
        sps.append(0x02)
        // Bytes 4-7: profile_compatibility_flags
        sps.append(contentsOf: [0x20, 0x00, 0x00, 0x00])
        // Bytes 8-13: constraint_indicator_flags (6 bytes)
        sps.append(contentsOf: [0x90, 0x00, 0x00, 0x00, 0x00, 0x00])
        // Byte 14: general_level_idc = 123 (Level 4.1)
        sps.append(123)
        return sps
    }
}
