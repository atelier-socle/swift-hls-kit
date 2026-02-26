// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - HDR Showcase

@Suite("HDR & Ultra-Res — Showcase Scenarios")
struct HDRShowcaseTests {

    let generator = HDRVariantGenerator()
    let mapper = VideoRangeMapper()

    @Test("Netflix-style HDR10 adaptive ladder (720p to 4K)")
    func netflixHDR10() {
        let config = HDRConfig.hdr10Default
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.hd720p, .fullHD1080p, .uhd4K],
            codec: .h265,
            frameRate: 24
        )
        let hdrVariants = variants.filter { !$0.isSDRFallback }
        #expect(hdrVariants.count == 3)
        #expect(hdrVariants.allSatisfy { $0.videoRange == .pq })
        let warnings = generator.validateLadder(hdrVariants)
        #expect(warnings.isEmpty)
    }

    @Test("Apple TV+ Dolby Vision profile 8 with HDR10 fallback")
    func appleTVDolbyVision() {
        let config = HDRConfig.dolbyVisionProfile8
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.fullHD1080p, .uhd4K],
            codec: .h265
        )
        let dvVariants = variants.filter { !$0.isSDRFallback }
        #expect(dvVariants.allSatisfy { $0.supplementalCodecs == "dvh1.08.01" })
        let sdrVariants = variants.filter(\.isSDRFallback)
        #expect(sdrVariants.allSatisfy { $0.supplementalCodecs == nil })
        #expect(sdrVariants.allSatisfy { $0.videoRange == .sdr })
    }

    @Test("BBC iPlayer HLG content with SDR compatibility")
    func bbcHLG() {
        let config = HDRConfig.hlgDefault
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.hd720p, .fullHD1080p],
            codec: .h265
        )
        let hlgVariants = variants.filter { !$0.isSDRFallback }
        #expect(hlgVariants.allSatisfy { $0.videoRange == .hlg })
        #expect(config.requiredColorSpace == .hlg)
    }

    @Test("YouTube HDR10+ with AV1 codec")
    func youtubeHDR10Plus() {
        let config = HDRConfig.hdr10PlusDefault
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.fullHD1080p, .uhd4K],
            codec: .av1
        )
        #expect(variants[0].codecs.contains("av01"))
        #expect(variants[0].videoRange == .pq)
    }

    @Test("Cinema DCI 4K Dolby Vision profile 5")
    func cinemaDV5() {
        let config = HDRConfig.dolbyVisionProfile5
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.cinema4K],
            codec: .h265,
            frameRate: 24
        )
        let dv = variants.first { !$0.isSDRFallback }
        #expect(dv?.supplementalCodecs == "dvh1.05.06")
        #expect(dv?.resolution == .cinema4K)
        #expect(dv?.frameRate == 24)
    }

    @Test("8K HEVC demo content")
    func uhd8KDemo() {
        let config = HDRConfig(type: .hdr10, generateSDRFallback: false)
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.uhd8K],
            codec: .h265,
            frameRate: 30
        )
        #expect(variants.count == 1)
        #expect(variants[0].resolution == .uhd8K)
        #expect(variants[0].bandwidth > 0)
    }

    @Test("Multi-format ladder: DV + HDR10 + SDR variants")
    func multiFormatLadder() {
        let dvVariants = generator.generateVariants(
            hdrConfig: .dolbyVisionProfile8,
            resolutions: [.uhd4K]
        )
        let hdr10Config = HDRConfig(type: .hdr10, generateSDRFallback: false)
        let hdr10Variants = generator.generateVariants(
            hdrConfig: hdr10Config,
            resolutions: [.uhd4K]
        )
        let total = dvVariants + hdr10Variants
        let dvCount = total.filter { $0.supplementalCodecs != nil }.count
        let sdrCount = total.filter(\.isSDRFallback).count
        #expect(dvCount >= 1)
        #expect(sdrCount >= 1)
    }

    @Test("Mastering display metadata: 4000-nit HDR10 master")
    func masteringMetadata() {
        let metadata = HDR10StaticMetadata(
            maxContentLightLevel: 4000,
            maxFrameAverageLightLevel: 1000,
            masteringDisplayPrimaries: .bt2020,
            masteringDisplayLuminance: .premium4000nits
        )
        let config = HDRConfig(type: .hdr10, staticMetadata: metadata)
        #expect(config.staticMetadata?.maxContentLightLevel == 4000)
        #expect(config.staticMetadata?.masteringDisplayLuminance?.maxLuminance == 4000)
        #expect(config.staticMetadata?.masteringDisplayPrimaries == .bt2020)
    }

    @Test("Complete broadcast chain: config to mapper to variant to attributes")
    func broadcastChain() {
        let config = HDRConfig.dolbyVisionProfile8
        let attrs = mapper.mapToHLSAttributes(
            config: config,
            resolution: .uhd4K,
            codec: .h265
        )
        #expect(attrs.videoRange == .pq)
        #expect(attrs.supplementalCodecs == "dvh1.08.01")
        #expect(attrs.minimumBitDepth == 10)
        #expect(attrs.colorSpace == .hdr10)
        #expect(attrs.recommendedCodecs?.contains("hvc1") == true)

        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.uhd4K],
            codec: .h265,
            frameRate: 30
        )
        let hdrVariant = variants.first { !$0.isSDRFallback }
        let formatted = hdrVariant?.formatAttributes() ?? ""
        #expect(formatted.contains("BANDWIDTH="))
        #expect(formatted.contains("RESOLUTION=3840x2160"))
        #expect(formatted.contains("VIDEO-RANGE=PQ"))
        #expect(formatted.contains("SUPPLEMENTAL-CODECS=\"dvh1.08.01\""))
    }

    @Test("Round-trip: HDR config to variant descriptor to format to parse attributes")
    func roundTrip() {
        let config = HDRConfig.hdr10Default
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.fullHD1080p],
            codec: .h265,
            frameRate: 30
        )
        let hdrVariant = variants.first { !$0.isSDRFallback }
        let attrs = hdrVariant?.formatAttributes() ?? ""

        #expect(attrs.contains("VIDEO-RANGE=PQ"))
        #expect(!attrs.contains("SUPPLEMENTAL-CODECS"))
        #expect(attrs.contains("CODECS="))
        #expect(attrs.contains("FRAME-RATE=30.000"))

        let variant = Variant(
            bandwidth: hdrVariant?.bandwidth ?? 0,
            uri: "video/hdr10.m3u8",
            videoRange: .pq
        )
        let warnings = mapper.validateVariant(variant, expectedConfig: config)
        #expect(warnings.isEmpty)
    }
}
