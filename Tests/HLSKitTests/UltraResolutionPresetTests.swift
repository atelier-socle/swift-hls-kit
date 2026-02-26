// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - ResolutionPreset Dimensions

@Suite("ResolutionPreset — Dimensions")
struct ResolutionPresetDimensionTests {

    @Test("SD 480p dimensions")
    func sd480p() {
        #expect(ResolutionPreset.sd480p.width == 854)
        #expect(ResolutionPreset.sd480p.height == 480)
        #expect(ResolutionPreset.sd480p.name == "SD 480p")
    }

    @Test("HD 720p dimensions")
    func hd720p() {
        #expect(ResolutionPreset.hd720p.width == 1280)
        #expect(ResolutionPreset.hd720p.height == 720)
    }

    @Test("Full HD 1080p dimensions")
    func fullHD() {
        #expect(ResolutionPreset.fullHD1080p.width == 1920)
        #expect(ResolutionPreset.fullHD1080p.height == 1080)
    }

    @Test("QHD 1440p dimensions")
    func qhd() {
        #expect(ResolutionPreset.qhd1440p.width == 2560)
        #expect(ResolutionPreset.qhd1440p.height == 1440)
    }

    @Test("4K UHD dimensions")
    func uhd4K() {
        #expect(ResolutionPreset.uhd4K.width == 3840)
        #expect(ResolutionPreset.uhd4K.height == 2160)
    }

    @Test("Cinema 4K DCI dimensions")
    func cinema4K() {
        #expect(ResolutionPreset.cinema4K.width == 4096)
        #expect(ResolutionPreset.cinema4K.height == 2160)
    }

    @Test("8K UHD dimensions")
    func uhd8K() {
        #expect(ResolutionPreset.uhd8K.width == 7680)
        #expect(ResolutionPreset.uhd8K.height == 4320)
    }
}

// MARK: - Properties

@Suite("ResolutionPreset — Properties")
struct ResolutionPresetPropertyTests {

    @Test("resolutionString format")
    func resolutionString() {
        #expect(ResolutionPreset.uhd4K.resolutionString == "3840x2160")
        #expect(ResolutionPreset.fullHD1080p.resolutionString == "1920x1080")
    }

    @Test("aspectRatio for 16:9 presets")
    func aspectRatio16x9() {
        #expect(ResolutionPreset.fullHD1080p.aspectRatio == "16:9")
        #expect(ResolutionPreset.uhd4K.aspectRatio == "16:9")
        #expect(ResolutionPreset.uhd8K.aspectRatio == "16:9")
    }

    @Test("aspectRatio for Cinema 4K DCI")
    func aspectRatioDCI() {
        let ratio = ResolutionPreset.cinema4K.aspectRatio
        #expect(ratio == "256:135")
    }

    @Test("isUltraHighRes true for > 1080p")
    func ultraHighResTrue() {
        #expect(ResolutionPreset.qhd1440p.isUltraHighRes == true)
        #expect(ResolutionPreset.uhd4K.isUltraHighRes == true)
        #expect(ResolutionPreset.uhd8K.isUltraHighRes == true)
    }

    @Test("isUltraHighRes false for <= 1080p")
    func ultraHighResFalse() {
        #expect(ResolutionPreset.sd480p.isUltraHighRes == false)
        #expect(ResolutionPreset.hd720p.isUltraHighRes == false)
        #expect(ResolutionPreset.fullHD1080p.isUltraHighRes == false)
    }

    @Test("recommendedFrameRates for SD")
    func frameRatesSD() {
        #expect(ResolutionPreset.sd480p.recommendedFrameRates == [24, 25, 30])
    }

    @Test("recommendedFrameRates for HD include 60fps")
    func frameRatesHD() {
        #expect(ResolutionPreset.hd720p.recommendedFrameRates.contains(60))
    }

    @Test("recommendedFrameRates for 8K limited")
    func frameRates8K() {
        #expect(ResolutionPreset.uhd8K.recommendedFrameRates == [24, 25, 30])
    }
}

// MARK: - Bitrate

@Suite("ResolutionPreset — Bitrate Ranges")
struct ResolutionPresetBitrateTests {

    @Test("H.264 bitrate range increases with resolution")
    func h264BitrateAscending() {
        let sd = ResolutionPreset.sd480p.bitrateRange(for: .h264)
        let hd = ResolutionPreset.hd720p.bitrateRange(for: .h264)
        let fhd = ResolutionPreset.fullHD1080p.bitrateRange(for: .h264)
        #expect(sd.upperBound < hd.upperBound)
        #expect(hd.upperBound < fhd.upperBound)
    }

    @Test("H.265 needs less bitrate than H.264 at same resolution")
    func h265LowerThanH264() {
        let h264 = ResolutionPreset.fullHD1080p.bitrateRange(for: .h264)
        let h265 = ResolutionPreset.fullHD1080p.bitrateRange(for: .h265)
        #expect(h265.upperBound < h264.upperBound)
    }

    @Test("AV1 needs less bitrate than H.265 at same resolution")
    func av1LowerThanH265() {
        let h265 = ResolutionPreset.uhd4K.bitrateRange(for: .h265)
        let av1 = ResolutionPreset.uhd4K.bitrateRange(for: .av1)
        #expect(av1.upperBound < h265.upperBound)
    }

    @Test("HDR adds ~20% overhead to bitrate range")
    func hdrOverhead() {
        let sdr = ResolutionPreset.uhd4K.bitrateRange(for: .h265, hdr: false)
        let hdr = ResolutionPreset.uhd4K.bitrateRange(for: .h265, hdr: true)
        #expect(hdr.lowerBound > sdr.lowerBound)
        #expect(hdr.upperBound > sdr.upperBound)
    }

    @Test("recommendedBandwidth is midpoint of range")
    func recommendedBandwidthMidpoint() {
        let range = ResolutionPreset.fullHD1080p.bitrateRange(for: .h265)
        let bandwidth = ResolutionPreset.fullHD1080p.recommendedBandwidth(for: .h265)
        #expect(bandwidth == (range.lowerBound + range.upperBound) / 2)
    }

    @Test("8K H.265 bitrate range is valid")
    func uhd8KBitrate() {
        let range = ResolutionPreset.uhd8K.bitrateRange(for: .h265)
        #expect(range.lowerBound > 0)
        #expect(range.upperBound > range.lowerBound)
    }
}

// MARK: - allPresets

@Suite("ResolutionPreset — allPresets")
struct ResolutionPresetAllPresetsTests {

    @Test("allPresets has 7 entries")
    func count() {
        #expect(ResolutionPreset.allPresets.count == 7)
    }

    @Test("allPresets is ordered by resolution ascending")
    func ascending() {
        let widths = ResolutionPreset.allPresets.map(\.width)
        for i in 1..<widths.count {
            #expect(widths[i] >= widths[i - 1])
        }
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(ResolutionPreset.uhd4K == ResolutionPreset.uhd4K)
        #expect(ResolutionPreset.sd480p != ResolutionPreset.uhd8K)
    }

    @Test("Hashable conformance")
    func hashable() {
        let set: Set<ResolutionPreset> = [.sd480p, .hd720p, .fullHD1080p]
        #expect(set.count == 3)
    }
}
