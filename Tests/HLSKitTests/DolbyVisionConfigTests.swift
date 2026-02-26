// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - DolbyVisionProfile

@Suite("DolbyVisionProfile — Properties")
struct DolbyVisionProfileTests {

    @Test("Init with profile and level")
    func initCustom() {
        let profile = DolbyVisionProfile(profile: 7, level: 3)
        #expect(profile.profile == 7)
        #expect(profile.level == 3)
    }

    @Test("Profile 5 supplemental codecs string")
    func profile5Codecs() {
        #expect(DolbyVisionProfile.profile5.supplementalCodecsString == "dvh1.05.06")
    }

    @Test("Profile 8.1 supplemental codecs string")
    func profile81Codecs() {
        #expect(DolbyVisionProfile.profile8_1.supplementalCodecsString == "dvh1.08.01")
    }

    @Test("Profile 8.4 supplemental codecs string")
    func profile84Codecs() {
        #expect(DolbyVisionProfile.profile8_4.supplementalCodecsString == "dvh1.08.04")
    }

    @Test("Profile 9 supplemental codecs string uses dav1 prefix")
    func profile9Codecs() {
        #expect(DolbyVisionProfile.profile9.supplementalCodecsString == "dav1.09.01")
    }

    @Test("AVC-based profile uses dva1 prefix")
    func avcProfile() {
        let profile = DolbyVisionProfile(profile: 4, level: 2)
        #expect(profile.supplementalCodecsString == "dva1.04.02")
    }

    @Test("Profile 5 is HEVC-based")
    func profile5IsHEVC() {
        #expect(DolbyVisionProfile.profile5.isHEVCBased == true)
    }

    @Test("Profile 8 is HEVC-based")
    func profile8IsHEVC() {
        #expect(DolbyVisionProfile.profile8_1.isHEVCBased == true)
    }

    @Test("Profile 9 is not HEVC-based")
    func profile9NotHEVC() {
        #expect(DolbyVisionProfile.profile9.isHEVCBased == false)
    }

    @Test("Profile 9 is AV1-based")
    func profile9IsAV1() {
        #expect(DolbyVisionProfile.profile9.isAV1Based == true)
    }

    @Test("Profile 4 is not HEVC-based and not AV1-based")
    func profile4IsAVC() {
        let profile = DolbyVisionProfile(profile: 4, level: 1)
        #expect(profile.isHEVCBased == false)
        #expect(profile.isAV1Based == false)
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(DolbyVisionProfile.profile5 == DolbyVisionProfile(profile: 5, level: 6))
        #expect(DolbyVisionProfile.profile5 != DolbyVisionProfile.profile8_1)
    }

    @Test("Hashable conformance")
    func hashable() {
        let set: Set<DolbyVisionProfile> = [.profile5, .profile8_1, .profile8_4, .profile9]
        #expect(set.count == 4)
    }
}

// MARK: - HDR10StaticMetadata

@Suite("HDR10StaticMetadata — Properties")
struct HDR10StaticMetadataTests {

    @Test("Init with light levels")
    func initLightLevels() {
        let metadata = HDR10StaticMetadata(
            maxContentLightLevel: 1000,
            maxFrameAverageLightLevel: 400
        )
        #expect(metadata.maxContentLightLevel == 1000)
        #expect(metadata.maxFrameAverageLightLevel == 400)
        #expect(metadata.masteringDisplayPrimaries == nil)
        #expect(metadata.masteringDisplayLuminance == nil)
    }

    @Test("Init with full metadata")
    func initFull() {
        let metadata = HDR10StaticMetadata(
            maxContentLightLevel: 4000,
            maxFrameAverageLightLevel: 800,
            masteringDisplayPrimaries: .bt2020,
            masteringDisplayLuminance: .premium4000nits
        )
        #expect(metadata.masteringDisplayPrimaries == .bt2020)
        #expect(metadata.masteringDisplayLuminance == .premium4000nits)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = HDR10StaticMetadata(maxContentLightLevel: 1000, maxFrameAverageLightLevel: 400)
        let b = HDR10StaticMetadata(maxContentLightLevel: 1000, maxFrameAverageLightLevel: 400)
        #expect(a == b)
    }
}

// MARK: - MasteringDisplayPrimaries

@Suite("MasteringDisplayPrimaries — Presets")
struct MasteringDisplayPrimariesTests {

    @Test("BT.2020 preset values")
    func bt2020() {
        let p = MasteringDisplayPrimaries.bt2020
        #expect(p.redX == 0.708)
        #expect(p.greenY == 0.797)
        #expect(p.blueX == 0.131)
        #expect(p.whitePointX == 0.3127)
    }

    @Test("Display P3 preset values")
    func displayP3() {
        let p = MasteringDisplayPrimaries.displayP3
        #expect(p.redX == 0.680)
        #expect(p.greenX == 0.265)
        #expect(p.blueY == 0.060)
        #expect(p.whitePointY == 0.3290)
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(MasteringDisplayPrimaries.bt2020 == MasteringDisplayPrimaries.bt2020)
        #expect(MasteringDisplayPrimaries.bt2020 != MasteringDisplayPrimaries.displayP3)
    }
}

// MARK: - MasteringDisplayLuminance

@Suite("MasteringDisplayLuminance — Presets")
struct MasteringDisplayLuminanceTests {

    @Test("Standard 1000 nits preset")
    func standard() {
        let l = MasteringDisplayLuminance.standard1000nits
        #expect(l.minLuminance == 0.0001)
        #expect(l.maxLuminance == 1000)
    }

    @Test("Premium 4000 nits preset")
    func premium() {
        let l = MasteringDisplayLuminance.premium4000nits
        #expect(l.maxLuminance == 4000)
    }

    @Test("Reference 10000 nits preset")
    func reference() {
        let l = MasteringDisplayLuminance.reference10000nits
        #expect(l.minLuminance == 0.00001)
        #expect(l.maxLuminance == 10000)
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(
            MasteringDisplayLuminance.standard1000nits
                == MasteringDisplayLuminance.standard1000nits
        )
        #expect(
            MasteringDisplayLuminance.standard1000nits
                != MasteringDisplayLuminance.premium4000nits
        )
    }
}
