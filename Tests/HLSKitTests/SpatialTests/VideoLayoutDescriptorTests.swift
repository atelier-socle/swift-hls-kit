// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("VideoLayoutDescriptor")
struct VideoLayoutDescriptorTests {

    // MARK: - attributeValue

    @Test("Channel layout only produces correct attribute value")
    func channelLayoutOnly() {
        let descriptor = VideoLayoutDescriptor(channelLayout: .stereoLeftRight)
        #expect(descriptor.attributeValue == "CH-STEREO")
    }

    @Test("Projection only produces correct attribute value")
    func projectionOnly() {
        let descriptor = VideoLayoutDescriptor(projection: .equirectangular)
        #expect(descriptor.attributeValue == "PROJ-EQUI")
    }

    @Test("Both channel layout and projection produces comma-separated value")
    func bothLayoutAndProjection() {
        let descriptor = VideoLayoutDescriptor(
            channelLayout: .stereoLeftRight,
            projection: .halfEquirectangular
        )
        #expect(descriptor.attributeValue == "CH-STEREO,PROJ-HEQU")
    }

    @Test("Nil/nil produces empty string")
    func nilNilProducesEmpty() {
        let descriptor = VideoLayoutDescriptor()
        #expect(descriptor.attributeValue == "")
    }

    // MARK: - parse

    @Test("Parse CH-STEREO")
    func parseStereo() {
        let descriptor = VideoLayoutDescriptor.parse("CH-STEREO")
        #expect(descriptor.channelLayout == .stereoLeftRight)
        #expect(descriptor.projection == nil)
    }

    @Test("Parse PROJ-EQUI")
    func parseEqui() {
        let descriptor = VideoLayoutDescriptor.parse("PROJ-EQUI")
        #expect(descriptor.channelLayout == nil)
        #expect(descriptor.projection == .equirectangular)
    }

    @Test("Parse CH-STEREO,PROJ-HEQU")
    func parseStereoHequ() {
        let descriptor = VideoLayoutDescriptor.parse("CH-STEREO,PROJ-HEQU")
        #expect(descriptor.channelLayout == .stereoLeftRight)
        #expect(descriptor.projection == .halfEquirectangular)
    }

    @Test("Parse CH-STEREO,PROJ-AIV")
    func parseStereoAiv() {
        let descriptor = VideoLayoutDescriptor.parse("CH-STEREO,PROJ-AIV")
        #expect(descriptor.channelLayout == .stereoLeftRight)
        #expect(descriptor.projection == .appleImmersiveVideo)
    }

    @Test("Parse CH-MONO")
    func parseMono() {
        let descriptor = VideoLayoutDescriptor.parse("CH-MONO")
        #expect(descriptor.channelLayout == .mono)
        #expect(descriptor.projection == nil)
    }

    @Test("Parse unknown string results in empty descriptor")
    func parseUnknown() {
        let descriptor = VideoLayoutDescriptor.parse("UNKNOWN-VALUE")
        #expect(descriptor.channelLayout == nil)
        #expect(descriptor.projection == nil)
    }

    // MARK: - Round-trip

    @Test("Round-trip: descriptor -> attributeValue -> parse -> equal")
    func roundTrip() {
        let original = VideoLayoutDescriptor(
            channelLayout: .stereoLeftRight,
            projection: .halfEquirectangular
        )
        let parsed = VideoLayoutDescriptor.parse(original.attributeValue)
        #expect(parsed == original)
    }

    // MARK: - Presets

    @Test("Preset .stereo values")
    func presetStereo() {
        let preset = VideoLayoutDescriptor.stereo
        #expect(preset.channelLayout == .stereoLeftRight)
        #expect(preset.projection == nil)
    }

    @Test("Preset .video360 values")
    func presetVideo360() {
        let preset = VideoLayoutDescriptor.video360
        #expect(preset.channelLayout == nil)
        #expect(preset.projection == .equirectangular)
    }

    @Test("Preset .immersive180 values")
    func presetImmersive180() {
        let preset = VideoLayoutDescriptor.immersive180
        #expect(preset.channelLayout == .stereoLeftRight)
        #expect(preset.projection == .halfEquirectangular)
    }

    @Test("Preset .appleImmersive values")
    func presetAppleImmersive() {
        let preset = VideoLayoutDescriptor.appleImmersive
        #expect(preset.channelLayout == .stereoLeftRight)
        #expect(preset.projection == .appleImmersiveVideo)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatable() {
        let a = VideoLayoutDescriptor.immersive180
        let b = VideoLayoutDescriptor(
            channelLayout: .stereoLeftRight,
            projection: .halfEquirectangular
        )
        #expect(a == b)
        #expect(a != VideoLayoutDescriptor.stereo)
    }
}
