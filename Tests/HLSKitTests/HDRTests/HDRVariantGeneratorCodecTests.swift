// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "HDRVariantGenerator — Codec Coverage",
    .timeLimit(.minutes(1))
)
struct HDRVariantGeneratorCodecTests {

    private let generator = HDRVariantGenerator()

    @Test("VP9 HDR variant generates vp09 codec string")
    func vp9HDRCodec() {
        let variants = generator.generateVariants(
            hdrConfig: HDRConfig(type: .hdr10),
            resolutions: [.fullHD1080p],
            codec: .vp9
        )
        #expect(!variants.isEmpty)
        #expect(variants[0].codecs.hasPrefix("vp09"))
    }

    @Test("VP9 SDR variant generates vp09 codec string")
    func vp9SDRCodec() {
        let variants = generator.generateVariants(
            hdrConfig: HDRConfig(
                type: .hdr10, generateSDRFallback: true
            ),
            resolutions: [.fullHD1080p],
            codec: .vp9
        )
        let sdr = variants.filter {
            $0.videoRange == .sdr
        }
        #expect(!sdr.isEmpty)
        #expect(sdr[0].codecs.hasPrefix("vp09"))
    }

    @Test("H.264 HDR variant generates avc1 codec string")
    func h264HDRCodec() {
        let variants = generator.generateVariants(
            hdrConfig: HDRConfig(type: .hdr10),
            resolutions: [.fullHD1080p],
            codec: .h264
        )
        #expect(!variants.isEmpty)
        #expect(variants[0].codecs.hasPrefix("avc1"))
    }

    @Test("H.264 SDR variant generates avc1.640028")
    func h264SDRCodec() {
        let variants = generator.generateVariants(
            hdrConfig: HDRConfig(
                type: .hdr10, generateSDRFallback: true
            ),
            resolutions: [.fullHD1080p],
            codec: .h264
        )
        let sdr = variants.filter {
            $0.videoRange == .sdr
        }
        #expect(!sdr.isEmpty)
        #expect(sdr[0].codecs == "avc1.640028")
    }
}
