// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - HDRVariantGenerator — Generation

@Suite("HDRVariantGenerator — Generation")
struct HDRVariantGeneratorTests {

    let generator = HDRVariantGenerator()

    @Test("HDR10 with 2 resolutions produces 4 variants (2 HDR + 2 SDR)")
    func hdr10TwoResolutions() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.fullHD1080p, .uhd4K]
        )
        #expect(variants.count == 4)
    }

    @Test("HDR variants have PQ video range for HDR10")
    func hdr10VideoRange() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.fullHD1080p]
        )
        let hdrVariants = variants.filter { !$0.isSDRFallback }
        for variant in hdrVariants {
            #expect(variant.videoRange == .pq)
        }
    }

    @Test("SDR fallback variants have SDR video range")
    func sdrFallbackRange() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.fullHD1080p]
        )
        let sdrVariants = variants.filter(\.isSDRFallback)
        for variant in sdrVariants {
            #expect(variant.videoRange == .sdr)
        }
    }

    @Test("DV profile 8 includes SUPPLEMENTAL-CODECS")
    func dvSupplementalCodecs() {
        let variants = generator.generateVariants(
            hdrConfig: .dolbyVisionProfile8,
            resolutions: [.uhd4K]
        )
        let hdrVariant = variants.first { !$0.isSDRFallback }
        #expect(hdrVariant?.supplementalCodecs == "dvh1.08.01")
    }

    @Test("SDR fallback has no supplemental codecs")
    func sdrNoSupplemental() {
        let variants = generator.generateVariants(
            hdrConfig: .dolbyVisionProfile8,
            resolutions: [.uhd4K]
        )
        let sdrVariant = variants.first(where: \.isSDRFallback)
        #expect(sdrVariant?.supplementalCodecs == nil)
    }

    @Test("HLG produces HLG video range")
    func hlgVideoRange() {
        let variants = generator.generateVariants(
            hdrConfig: .hlgDefault,
            resolutions: [.hd720p]
        )
        let hdrVariant = variants.first { !$0.isSDRFallback }
        #expect(hdrVariant?.videoRange == .hlg)
    }

    @Test("No SDR fallback when disabled")
    func noSDRFallback() {
        let config = HDRConfig(type: .hdr10, generateSDRFallback: false)
        let variants = generator.generateVariants(
            hdrConfig: config,
            resolutions: [.fullHD1080p, .uhd4K]
        )
        #expect(variants.count == 2)
        #expect(variants.allSatisfy { !$0.isSDRFallback })
    }

    @Test("Frame rate is included when specified")
    func frameRateIncluded() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.uhd4K],
            frameRate: 60
        )
        #expect(variants[0].frameRate == 60)
    }

    @Test("Codec is H.265 by default")
    func defaultCodec() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.fullHD1080p]
        )
        #expect(variants[0].codecs.contains("hvc1"))
    }

    @Test("AV1 codec produces av01 string")
    func av1Codec() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.fullHD1080p],
            codec: .av1
        )
        #expect(variants[0].codecs.contains("av01"))
    }

    @Test("Bandwidth is positive for all variants")
    func positiveBandwidth() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.sd480p, .uhd4K]
        )
        for variant in variants {
            #expect(variant.bandwidth > 0)
        }
    }

    @Test("Resolution is preserved on variant")
    func resolutionPreserved() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.uhd4K]
        )
        #expect(variants[0].resolution == .uhd4K)
    }
}

// MARK: - Adaptive Ladder

@Suite("HDRVariantGenerator — Adaptive Ladder")
struct HDRVariantGeneratorLadderTests {

    let generator = HDRVariantGenerator()

    @Test("H.265 ladder includes 6 resolutions + SDR fallbacks")
    func h265Ladder() {
        let variants = generator.generateAdaptiveLadder(
            hdrConfig: .hdr10Default
        )
        let hdrCount = variants.filter { !$0.isSDRFallback }.count
        #expect(hdrCount == 6)
        let sdrCount = variants.filter(\.isSDRFallback).count
        #expect(sdrCount == 6)
    }

    @Test("H.264 ladder includes 5 resolutions (no 8K)")
    func h264Ladder() {
        let config = HDRConfig(type: .hdr10, generateSDRFallback: false)
        let variants = generator.generateAdaptiveLadder(
            hdrConfig: config,
            codec: .h264
        )
        #expect(variants.count == 5)
    }

    @Test("AV1 ladder includes 6 resolutions")
    func av1Ladder() {
        let config = HDRConfig(type: .hdr10, generateSDRFallback: false)
        let variants = generator.generateAdaptiveLadder(
            hdrConfig: config,
            codec: .av1
        )
        #expect(variants.count == 6)
    }

    @Test("Ladder frame rate is applied to all variants")
    func ladderFrameRate() {
        let variants = generator.generateAdaptiveLadder(
            hdrConfig: .hdr10Default,
            frameRate: 24
        )
        for variant in variants {
            #expect(variant.frameRate == 24)
        }
    }
}

// MARK: - formatAttributes

@Suite("HDRVariantGenerator — formatAttributes")
struct HDRVariantGeneratorFormatTests {

    let generator = HDRVariantGenerator()

    @Test("formatAttributes contains BANDWIDTH")
    func containsBandwidth() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.uhd4K]
        )
        let attrs = variants[0].formatAttributes()
        #expect(attrs.contains("BANDWIDTH="))
    }

    @Test("formatAttributes contains RESOLUTION")
    func containsResolution() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.uhd4K]
        )
        let attrs = variants[0].formatAttributes()
        #expect(attrs.contains("RESOLUTION=3840x2160"))
    }

    @Test("formatAttributes contains VIDEO-RANGE")
    func containsVideoRange() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.uhd4K]
        )
        let attrs = variants[0].formatAttributes()
        #expect(attrs.contains("VIDEO-RANGE=PQ"))
    }

    @Test("formatAttributes contains SUPPLEMENTAL-CODECS for DV")
    func containsSupplemental() {
        let variants = generator.generateVariants(
            hdrConfig: .dolbyVisionProfile8,
            resolutions: [.uhd4K]
        )
        let hdrVariant = variants.first { !$0.isSDRFallback }
        let attrs = hdrVariant?.formatAttributes() ?? ""
        #expect(attrs.contains("SUPPLEMENTAL-CODECS=\"dvh1.08.01\""))
    }

    @Test("formatAttributes contains FRAME-RATE when set")
    func containsFrameRate() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.uhd4K],
            frameRate: 30
        )
        let attrs = variants[0].formatAttributes()
        #expect(attrs.contains("FRAME-RATE=30.000"))
    }

    @Test("formatAttributes omits SUPPLEMENTAL-CODECS for HDR10")
    func omitsSupplementalHDR10() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.uhd4K]
        )
        let attrs = variants[0].formatAttributes()
        #expect(!attrs.contains("SUPPLEMENTAL-CODECS"))
    }
}

// MARK: - Validation

@Suite("HDRVariantGenerator — Validation")
struct HDRVariantGeneratorValidationTests {

    let generator = HDRVariantGenerator()

    @Test("Valid ladder produces no warnings")
    func validLadder() {
        let variants = generator.generateVariants(
            hdrConfig: .hdr10Default,
            resolutions: [.hd720p, .fullHD1080p, .uhd4K]
        )
        let hdrVariants = variants.filter { !$0.isSDRFallback }
        let warnings = generator.validateLadder(hdrVariants)
        #expect(warnings.isEmpty)
    }

    @Test("Mixed VIDEO-RANGE produces warning")
    func mixedVideoRange() {
        let v1 = HDRVariantGenerator.VariantDescriptor(
            resolution: .fullHD1080p, videoRange: .pq,
            codecs: "hvc1.2.4.L150.B0", supplementalCodecs: nil,
            bandwidth: 6_000_000, frameRate: nil, isSDRFallback: false
        )
        let v2 = HDRVariantGenerator.VariantDescriptor(
            resolution: .uhd4K, videoRange: .hlg,
            codecs: "hvc1.2.4.L150.B0", supplementalCodecs: nil,
            bandwidth: 15_000_000, frameRate: nil, isSDRFallback: false
        )
        let warnings = generator.validateLadder([v1, v2])
        #expect(warnings.contains { $0.contains("Mixed VIDEO-RANGE") })
    }

    @Test("Decreasing bandwidth produces warning")
    func decreasingBandwidth() {
        let v1 = HDRVariantGenerator.VariantDescriptor(
            resolution: .uhd4K, videoRange: .pq,
            codecs: "hvc1.2.4.L150.B0", supplementalCodecs: nil,
            bandwidth: 20_000_000, frameRate: nil, isSDRFallback: false
        )
        let v2 = HDRVariantGenerator.VariantDescriptor(
            resolution: .fullHD1080p, videoRange: .pq,
            codecs: "hvc1.2.4.L150.B0", supplementalCodecs: nil,
            bandwidth: 5_000_000, frameRate: nil, isSDRFallback: false
        )
        let warnings = generator.validateLadder([v1, v2])
        #expect(warnings.contains { $0.contains("Bandwidth not ascending") })
    }

    @Test("Inconsistent codecs produces warning")
    func inconsistentCodecs() {
        let v1 = HDRVariantGenerator.VariantDescriptor(
            resolution: .fullHD1080p, videoRange: .pq,
            codecs: "hvc1.2.4.L150.B0", supplementalCodecs: nil,
            bandwidth: 6_000_000, frameRate: nil, isSDRFallback: false
        )
        let v2 = HDRVariantGenerator.VariantDescriptor(
            resolution: .uhd4K, videoRange: .pq,
            codecs: "av01.0.09M.10", supplementalCodecs: nil,
            bandwidth: 15_000_000, frameRate: nil, isSDRFallback: false
        )
        let warnings = generator.validateLadder([v1, v2])
        #expect(warnings.contains { $0.contains("Inconsistent CODECS") })
    }
}
