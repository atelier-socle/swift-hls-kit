// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - VideoRangeMapper

@Suite("VideoRangeMapper — Basic Mapping")
struct VideoRangeMapperBasicTests {

    let mapper = VideoRangeMapper()

    @Test("HDR10 maps to PQ video range")
    func hdr10VideoRange() {
        let attrs = mapper.mapToHLSAttributes(config: .hdr10Default)
        #expect(attrs.videoRange == .pq)
    }

    @Test("HLG maps to HLG video range")
    func hlgVideoRange() {
        let attrs = mapper.mapToHLSAttributes(config: .hlgDefault)
        #expect(attrs.videoRange == .hlg)
    }

    @Test("DV profile 8 maps to PQ with supplemental codecs")
    func dvProfile8() {
        let attrs = mapper.mapToHLSAttributes(config: .dolbyVisionProfile8)
        #expect(attrs.videoRange == .pq)
        #expect(attrs.supplementalCodecs == "dvh1.08.01")
    }

    @Test("HDR10 has no supplemental codecs")
    func hdr10NoSupplemental() {
        let attrs = mapper.mapToHLSAttributes(config: .hdr10Default)
        #expect(attrs.supplementalCodecs == nil)
    }

    @Test("Minimum bit depth is 10 for HDR10")
    func bitDepthHDR10() {
        let attrs = mapper.mapToHLSAttributes(config: .hdr10Default)
        #expect(attrs.minimumBitDepth == 10)
    }

    @Test("Minimum bit depth is 12 for DV 8.4")
    func bitDepthDV84() {
        let config = HDRConfig(
            type: .dolbyVision,
            dolbyVisionProfile: .profile8_4
        )
        let attrs = mapper.mapToHLSAttributes(config: config)
        #expect(attrs.minimumBitDepth == 12)
    }

    @Test("Color space is hdr10 for PQ types")
    func colorSpacePQ() {
        let attrs = mapper.mapToHLSAttributes(config: .hdr10Default)
        #expect(attrs.colorSpace == .hdr10)
    }

    @Test("Color space is hlg for HLG type")
    func colorSpaceHLG() {
        let attrs = mapper.mapToHLSAttributes(config: .hlgDefault)
        #expect(attrs.colorSpace == .hlg)
    }

    @Test("Recommended codecs is non-nil")
    func recommendedCodecs() {
        let attrs = mapper.mapToHLSAttributes(config: .hdr10Default)
        #expect(attrs.recommendedCodecs != nil)
    }
}

@Suite("VideoRangeMapper — Resolution + Codec Mapping")
struct VideoRangeMapperResolutionTests {

    let mapper = VideoRangeMapper()

    @Test("4K H.265 HDR10 produces correct attributes")
    func uhd4kH265() {
        let attrs = mapper.mapToHLSAttributes(
            config: .hdr10Default,
            resolution: .uhd4K,
            codec: .h265
        )
        #expect(attrs.videoRange == .pq)
        #expect(attrs.recommendedCodecs?.contains("hvc1") == true)
    }

    @Test("1080p AV1 produces AV1 codec string")
    func fullHDAV1() {
        let attrs = mapper.mapToHLSAttributes(
            config: .hdr10Default,
            resolution: .fullHD1080p,
            codec: .av1
        )
        #expect(attrs.recommendedCodecs?.contains("av01") == true)
    }

    @Test("720p H.264 produces AVC codec string")
    func hdH264() {
        let attrs = mapper.mapToHLSAttributes(
            config: .hlgDefault,
            resolution: .hd720p,
            codec: .h264
        )
        #expect(attrs.recommendedCodecs?.contains("avc1") == true)
    }
}

// MARK: - Variant Validation

@Suite("VideoRangeMapper — Variant Validation")
struct VideoRangeMapperValidationTests {

    let mapper = VideoRangeMapper()

    @Test("Valid variant produces no warnings")
    func validVariant() {
        let variant = Variant(
            bandwidth: 15_000_000,
            uri: "video/hdr10.m3u8",
            videoRange: .pq,
            supplementalCodecs: nil
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: .hdr10Default)
        #expect(warnings.isEmpty)
    }

    @Test("Mismatched VIDEO-RANGE produces warning")
    func mismatchedVideoRange() {
        let variant = Variant(
            bandwidth: 15_000_000,
            uri: "video/hdr.m3u8",
            videoRange: .hlg
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: .hdr10Default)
        #expect(warnings.count == 1)
        #expect(warnings[0].contains("VIDEO-RANGE mismatch"))
    }

    @Test("Missing VIDEO-RANGE produces warning")
    func missingVideoRange() {
        let variant = Variant(
            bandwidth: 15_000_000,
            uri: "video/hdr.m3u8"
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: .hdr10Default)
        #expect(warnings.count == 1)
        #expect(warnings[0].contains("VIDEO-RANGE missing"))
    }

    @Test("Missing SUPPLEMENTAL-CODECS for DV produces warning")
    func missingSupplemental() {
        let variant = Variant(
            bandwidth: 15_000_000,
            uri: "video/dv.m3u8",
            videoRange: .pq
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: .dolbyVisionProfile8)
        #expect(warnings.contains { $0.contains("SUPPLEMENTAL-CODECS missing") })
    }

    @Test("Mismatched SUPPLEMENTAL-CODECS produces warning")
    func mismatchedSupplemental() {
        let variant = Variant(
            bandwidth: 15_000_000,
            uri: "video/dv.m3u8",
            videoRange: .pq,
            supplementalCodecs: "dvh1.05.06"
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: .dolbyVisionProfile8)
        #expect(warnings.contains { $0.contains("SUPPLEMENTAL-CODECS mismatch") })
    }

    @Test("Correct DV variant produces no warnings")
    func validDVVariant() {
        let variant = Variant(
            bandwidth: 15_000_000,
            uri: "video/dv.m3u8",
            videoRange: .pq,
            supplementalCodecs: "dvh1.08.01"
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: .dolbyVisionProfile8)
        #expect(warnings.isEmpty)
    }

    @Test("HLG variant with SDR videoRange produces warning")
    func hlgWithSDR() {
        let variant = Variant(
            bandwidth: 10_000_000,
            uri: "video/hlg.m3u8",
            videoRange: .sdr
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: .hlgDefault)
        #expect(warnings.count == 1)
    }
}
