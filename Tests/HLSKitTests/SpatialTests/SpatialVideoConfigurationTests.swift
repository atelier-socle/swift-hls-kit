// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SpatialVideoConfiguration")
struct SpatialVideoConfigurationTests {

    @Test("Custom init sets all properties")
    func customInit() {
        let config = SpatialVideoConfiguration(
            baseLayerCodec: "hvc1.1.6.L93.B0",
            supplementalCodecs: "dvh1.20.09/db4h",
            channelLayout: .stereoLeftRight,
            dolbyVisionProfile: 20,
            width: 1920,
            height: 1080,
            frameRate: 24.0
        )
        #expect(config.baseLayerCodec == "hvc1.1.6.L93.B0")
        #expect(config.supplementalCodecs == "dvh1.20.09/db4h")
        #expect(config.channelLayout == .stereoLeftRight)
        #expect(config.dolbyVisionProfile == 20)
        #expect(config.width == 1920)
        #expect(config.height == 1080)
        #expect(config.frameRate == 24.0)
    }

    @Test("Default optional properties are nil")
    func defaultOptionals() {
        let config = SpatialVideoConfiguration(
            baseLayerCodec: "hvc1.2.4.L123.B0",
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )
        #expect(config.supplementalCodecs == nil)
        #expect(config.dolbyVisionProfile == nil)
        #expect(config.channelLayout == .stereoLeftRight)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = SpatialVideoConfiguration.visionProStandard
        let b = SpatialVideoConfiguration.visionProStandard
        #expect(a == b)
        #expect(a != SpatialVideoConfiguration.visionProHighQuality)
    }

    // MARK: - Presets

    @Test("visionProStandard preset values")
    func visionProStandard() {
        let config = SpatialVideoConfiguration.visionProStandard
        #expect(config.baseLayerCodec == "hvc1.2.4.L123.B0")
        #expect(config.supplementalCodecs == nil)
        #expect(config.channelLayout == .stereoLeftRight)
        #expect(config.width == 1920)
        #expect(config.height == 1080)
        #expect(config.frameRate == 30.0)
    }

    @Test("visionProHighQuality preset values")
    func visionProHighQuality() {
        let config = SpatialVideoConfiguration.visionProHighQuality
        #expect(config.baseLayerCodec == "hvc1.2.4.L153.B0")
        #expect(config.width == 3840)
        #expect(config.height == 2160)
        #expect(config.channelLayout == .stereoLeftRight)
    }

    @Test("dolbyVisionStereo preset values")
    func dolbyVisionStereo() {
        let config = SpatialVideoConfiguration.dolbyVisionStereo
        #expect(config.supplementalCodecs == "dvh1.20.09/db4h")
        #expect(config.dolbyVisionProfile == 20)
        #expect(config.width == 3840)
        #expect(config.height == 2160)
        #expect(config.channelLayout == .stereoLeftRight)
    }

    @Test("Mono layout configuration")
    func monoLayout() {
        let config = SpatialVideoConfiguration(
            baseLayerCodec: "hvc1.2.4.L123.B0",
            channelLayout: .mono,
            width: 1920,
            height: 1080,
            frameRate: 30.0
        )
        #expect(config.channelLayout == .mono)
    }
}
