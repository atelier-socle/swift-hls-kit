// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - LiveDRMPipelineConfig

@Suite("LiveDRMPipelineConfig — Configuration")
struct LiveDRMPipelineConfigTests {

    @Test("Default init has no DRM configured")
    func defaultInit() {
        let config = LiveDRMPipelineConfig()
        #expect(config.fairPlay == nil)
        #expect(config.rotationPolicy == .everyNSegments(10))
        #expect(config.cenc == nil)
        #expect(!config.isEnabled)
        #expect(!config.isMultiDRM)
    }

    @Test("FairPlay only is enabled but not multi-DRM")
    func fairPlayOnly() {
        let config = LiveDRMPipelineConfig(fairPlay: .modern)
        #expect(config.isEnabled)
        #expect(!config.isMultiDRM)
    }

    @Test("CENC only is both enabled and multi-DRM")
    func cencOnly() {
        let config = LiveDRMPipelineConfig(
            cenc: CENCConfig(systems: [.widevine], defaultKeyID: "key1")
        )
        #expect(config.isEnabled)
        #expect(config.isMultiDRM)
    }

    @Test("Custom rotation policy")
    func customRotation() {
        let config = LiveDRMPipelineConfig(
            fairPlay: .modern,
            rotationPolicy: .everySegment
        )
        #expect(config.rotationPolicy == .everySegment)
    }
}

// MARK: - Presets

@Suite("LiveDRMPipelineConfig — Presets")
struct LiveDRMPipelineConfigPresetTests {

    @Test("fairPlayModern preset has FairPlay and rotation")
    func fairPlayModern() {
        let config = LiveDRMPipelineConfig.fairPlayModern
        #expect(config.fairPlay != nil)
        #expect(config.rotationPolicy == .everyNSegments(10))
        #expect(config.cenc == nil)
        #expect(config.isEnabled)
        #expect(!config.isMultiDRM)
    }

    @Test("multiDRM preset has FairPlay and CENC")
    func multiDRM() {
        let config = LiveDRMPipelineConfig.multiDRM
        #expect(config.fairPlay != nil)
        #expect(config.cenc != nil)
        #expect(config.isEnabled)
        #expect(config.isMultiDRM)
    }

    @Test("multiDRM has Widevine and PlayReady systems")
    func multiDRMSystems() {
        let config = LiveDRMPipelineConfig.multiDRM
        #expect(config.cenc?.systems.contains(.widevine) == true)
        #expect(config.cenc?.systems.contains(.playReady) == true)
    }
}

// MARK: - Equatable

@Suite("LiveDRMPipelineConfig — Equatable")
struct LiveDRMPipelineConfigEquatableTests {

    @Test("Identical configs are equal")
    func identical() {
        let a = LiveDRMPipelineConfig.fairPlayModern
        let b = LiveDRMPipelineConfig.fairPlayModern
        #expect(a == b)
    }

    @Test("Different configs are not equal")
    func different() {
        let a = LiveDRMPipelineConfig.fairPlayModern
        let b = LiveDRMPipelineConfig.multiDRM
        #expect(a != b)
    }
}
