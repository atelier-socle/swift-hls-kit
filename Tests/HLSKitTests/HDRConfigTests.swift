// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - HDRConfig

@Suite("HDRConfig — Properties & Mapping")
struct HDRConfigTests {

    @Test("Init with hdr10 type")
    func initHDR10() {
        let config = HDRConfig(type: .hdr10)
        #expect(config.type == .hdr10)
        #expect(config.generateSDRFallback == true)
        #expect(config.staticMetadata == nil)
        #expect(config.dolbyVisionProfile == nil)
    }

    @Test("Init with dolbyVision and profile")
    func initDolbyVision() {
        let config = HDRConfig(
            type: .dolbyVision,
            dolbyVisionProfile: .profile5
        )
        #expect(config.type == .dolbyVision)
        #expect(config.dolbyVisionProfile == .profile5)
    }

    @Test("Init with static metadata")
    func initWithMetadata() {
        let metadata = HDR10StaticMetadata(
            maxContentLightLevel: 1000,
            maxFrameAverageLightLevel: 400
        )
        let config = HDRConfig(type: .hdr10, staticMetadata: metadata)
        #expect(config.staticMetadata?.maxContentLightLevel == 1000)
    }

    @Test("generateSDRFallback can be disabled")
    func noSDRFallback() {
        let config = HDRConfig(type: .hdr10, generateSDRFallback: false)
        #expect(config.generateSDRFallback == false)
    }

    // MARK: - videoRange

    @Test("hdr10 maps to VIDEO-RANGE PQ")
    func videoRangeHDR10() {
        #expect(HDRConfig(type: .hdr10).videoRange == .pq)
    }

    @Test("hdr10Plus maps to VIDEO-RANGE PQ")
    func videoRangeHDR10Plus() {
        #expect(HDRConfig(type: .hdr10Plus).videoRange == .pq)
    }

    @Test("dolbyVision maps to VIDEO-RANGE PQ")
    func videoRangeDV() {
        #expect(HDRConfig(type: .dolbyVision).videoRange == .pq)
    }

    @Test("dolbyVisionWithHDR10Fallback maps to VIDEO-RANGE PQ")
    func videoRangeDVFallback() {
        #expect(HDRConfig(type: .dolbyVisionWithHDR10Fallback).videoRange == .pq)
    }

    @Test("hlg maps to VIDEO-RANGE HLG")
    func videoRangeHLG() {
        #expect(HDRConfig(type: .hlg).videoRange == .hlg)
    }

    // MARK: - supplementalCodecs

    @Test("hdr10 has no supplemental codecs")
    func supplementalHDR10() {
        #expect(HDRConfig(type: .hdr10).supplementalCodecs == nil)
    }

    @Test("hlg has no supplemental codecs")
    func supplementalHLG() {
        #expect(HDRConfig(type: .hlg).supplementalCodecs == nil)
    }

    @Test("dolbyVision with profile returns supplemental codecs string")
    func supplementalDV() {
        let config = HDRConfig(
            type: .dolbyVision,
            dolbyVisionProfile: .profile8_1
        )
        #expect(config.supplementalCodecs == "dvh1.08.01")
    }

    @Test("dolbyVisionWithHDR10Fallback returns supplemental codecs")
    func supplementalDVFallback() {
        let config = HDRConfig(
            type: .dolbyVisionWithHDR10Fallback,
            dolbyVisionProfile: .profile8_4
        )
        #expect(config.supplementalCodecs == "dvh1.08.04")
    }

    @Test("dolbyVision without profile returns nil supplemental codecs")
    func supplementalDVNoProfile() {
        let config = HDRConfig(type: .dolbyVision)
        #expect(config.supplementalCodecs == nil)
    }

    // MARK: - requiredColorSpace

    @Test("hdr10 requires BT.2020 + PQ color space")
    func colorSpaceHDR10() {
        #expect(HDRConfig(type: .hdr10).requiredColorSpace == .hdr10)
    }

    @Test("hlg requires BT.2020 + HLG color space")
    func colorSpaceHLG() {
        #expect(HDRConfig(type: .hlg).requiredColorSpace == .hlg)
    }

    @Test("dolbyVision requires BT.2020 + PQ color space")
    func colorSpaceDV() {
        #expect(HDRConfig(type: .dolbyVision).requiredColorSpace == .hdr10)
    }

    // MARK: - minimumBitDepth

    @Test("hdr10 minimum bit depth is 10")
    func bitDepthHDR10() {
        #expect(HDRConfig(type: .hdr10).minimumBitDepth == 10)
    }

    @Test("hlg minimum bit depth is 10")
    func bitDepthHLG() {
        #expect(HDRConfig(type: .hlg).minimumBitDepth == 10)
    }

    @Test("DV profile 8.4 minimum bit depth is 12")
    func bitDepthDV84() {
        let config = HDRConfig(
            type: .dolbyVision,
            dolbyVisionProfile: .profile8_4
        )
        #expect(config.minimumBitDepth == 12)
    }

    @Test("DV profile 8.1 minimum bit depth is 10")
    func bitDepthDV81() {
        let config = HDRConfig(
            type: .dolbyVision,
            dolbyVisionProfile: .profile8_1
        )
        #expect(config.minimumBitDepth == 10)
    }

    // MARK: - Presets

    @Test("hdr10Default preset")
    func presetHDR10() {
        let config = HDRConfig.hdr10Default
        #expect(config.type == .hdr10)
        #expect(config.generateSDRFallback == true)
    }

    @Test("hdr10PlusDefault preset")
    func presetHDR10Plus() {
        #expect(HDRConfig.hdr10PlusDefault.type == .hdr10Plus)
    }

    @Test("dolbyVisionProfile5 preset")
    func presetDVP5() {
        let config = HDRConfig.dolbyVisionProfile5
        #expect(config.type == .dolbyVision)
        #expect(config.dolbyVisionProfile == .profile5)
    }

    @Test("dolbyVisionProfile8 preset")
    func presetDVP8() {
        let config = HDRConfig.dolbyVisionProfile8
        #expect(config.type == .dolbyVisionWithHDR10Fallback)
        #expect(config.dolbyVisionProfile == .profile8_1)
    }

    @Test("hlgDefault preset")
    func presetHLG() {
        #expect(HDRConfig.hlgDefault.type == .hlg)
    }

    // MARK: - Conformances

    @Test("HDRType has 5 cases")
    func hdrTypeCaseIterable() {
        #expect(HDRConfig.HDRType.allCases.count == 5)
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(HDRConfig.hdr10Default == HDRConfig.hdr10Default)
        #expect(HDRConfig.hdr10Default != HDRConfig.hlgDefault)
    }

    @Test("Hashable conformance")
    func hashable() {
        let set: Set<HDRConfig> = [.hdr10Default, .hlgDefault, .dolbyVisionProfile5]
        #expect(set.count == 3)
    }
}
