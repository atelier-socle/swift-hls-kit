// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("VideoLayout Validation")
struct VideoLayoutValidationTests {

    // MARK: - Helpers

    private func masterPlaylist(
        with variants: [Variant]
    ) -> MasterPlaylist {
        MasterPlaylist(
            variants: variants,
            iFrameVariants: [],
            renditions: [],
            independentSegments: true
        )
    }

    // MARK: - PROJ-AIV without CH-STEREO

    @Test("PROJ-AIV without CH-STEREO produces warning")
    func projAivWithoutStereo() {
        let variant = Variant(
            bandwidth: 10_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "immersive/playlist.m3u8",
            videoLayoutDescriptor: VideoLayoutDescriptor(
                projection: .appleImmersiveVideo
            )
        )
        let playlist = masterPlaylist(with: [variant])
        let results = AppleHLSRules.validate(playlist)
        let layoutWarnings = results.filter {
            $0.ruleId == "APPLE-2.9-video-layout"
                && $0.message.contains("PROJ-AIV")
        }
        #expect(!layoutWarnings.isEmpty)
    }

    // MARK: - PROJ-HEQU without channel layout

    @Test("PROJ-HEQU without channel layout produces warning")
    func projHequWithoutChannel() {
        let variant = Variant(
            bandwidth: 8_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "hequ/playlist.m3u8",
            videoLayoutDescriptor: VideoLayoutDescriptor(
                projection: .halfEquirectangular
            )
        )
        let playlist = masterPlaylist(with: [variant])
        let results = AppleHLSRules.validate(playlist)
        let layoutWarnings = results.filter {
            $0.ruleId == "APPLE-2.9-video-layout"
                && $0.message.contains("PROJ-HEQU")
        }
        #expect(!layoutWarnings.isEmpty)
    }

    // MARK: - Valid stereo + projection

    @Test("Valid CH-STEREO,PROJ-HEQU with supplemental codecs passes")
    func validStereoHequ() {
        let variant = Variant(
            bandwidth: 12_000_000,
            resolution: Resolution(width: 3840, height: 2160),
            uri: "immersive/playlist.m3u8",
            supplementalCodecs: "dvh1.20.09/db4h",
            videoLayoutDescriptor: .immersive180
        )
        let playlist = masterPlaylist(with: [variant])
        let results = AppleHLSRules.validate(playlist)
        let layoutWarnings = results.filter {
            $0.ruleId == "APPLE-2.9-video-layout"
        }
        #expect(layoutWarnings.isEmpty)
    }

    // MARK: - Stereo without SUPPLEMENTAL-CODECS

    @Test("CH-STEREO without SUPPLEMENTAL-CODECS produces warning")
    func stereoWithoutSupplemental() {
        let variant = Variant(
            bandwidth: 8_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "stereo/playlist.m3u8",
            videoLayoutDescriptor: .stereo
        )
        let playlist = masterPlaylist(with: [variant])
        let results = AppleHLSRules.validate(playlist)
        let layoutWarnings = results.filter {
            $0.ruleId == "APPLE-2.9-video-layout"
                && $0.message.contains("SUPPLEMENTAL-CODECS")
        }
        #expect(!layoutWarnings.isEmpty)
    }

    // MARK: - No REQ-VIDEO-LAYOUT

    @Test("No REQ-VIDEO-LAYOUT produces no layout warnings")
    func noVideoLayout() {
        let variant = Variant(
            bandwidth: 2_000_000,
            resolution: Resolution(width: 1920, height: 1080),
            uri: "video/playlist.m3u8"
        )
        let playlist = masterPlaylist(with: [variant])
        let results = AppleHLSRules.validate(playlist)
        let layoutWarnings = results.filter {
            $0.ruleId == "APPLE-2.9-video-layout"
        }
        #expect(layoutWarnings.isEmpty)
    }
}
