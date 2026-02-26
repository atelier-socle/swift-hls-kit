// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - New Component Groups — Defaults

@Suite("LivePipelineComponents — New Groups Defaults")
struct ComponentsNewGroupDefaultTests {

    @Test("Default components have all new groups nil")
    func defaultComponents() {
        let components = LivePipelineComponents()
        #expect(components.spatialAudio == nil)
        #expect(components.hdr == nil)
        #expect(components.drm == nil)
        #expect(components.accessibility == nil)
        #expect(components.resilience == nil)
    }
}

// MARK: - SpatialAudioComponents

@Suite("SpatialAudioComponents — Init")
struct SpatialAudioComponentsTests {

    @Test("Default init has nil fields")
    func defaultInit() {
        let components = SpatialAudioComponents()
        #expect(components.encoder == nil)
        #expect(components.renditionGenerator == nil)
    }

    @Test("Init with rendition generator")
    func withGenerator() {
        let components = SpatialAudioComponents(
            renditionGenerator: SpatialRenditionGenerator()
        )
        #expect(components.renditionGenerator != nil)
    }
}

// MARK: - HDRComponents

@Suite("HDRComponents — Init")
struct HDRComponentsTests {

    @Test("Default init has nil fields")
    func defaultInit() {
        let components = HDRComponents()
        #expect(components.rangeMapper == nil)
        #expect(components.variantGenerator == nil)
    }

    @Test("Init with variant generator")
    func withGenerator() {
        let components = HDRComponents(
            variantGenerator: HDRVariantGenerator()
        )
        #expect(components.variantGenerator != nil)
    }

    @Test("Init with range mapper")
    func withMapper() {
        let components = HDRComponents(
            rangeMapper: VideoRangeMapper()
        )
        #expect(components.rangeMapper != nil)
    }
}

// MARK: - DRMComponents

@Suite("DRMComponents — Init")
struct DRMComponentsTests {

    @Test("Default init has nil session key manager")
    func defaultInit() {
        let components = DRMComponents()
        #expect(components.sessionKeyManager == nil)
    }

    @Test("Init with session key manager")
    func withManager() {
        let components = DRMComponents(
            sessionKeyManager: SessionKeyManager()
        )
        #expect(components.sessionKeyManager != nil)
    }
}

// MARK: - AccessibilityComponents

@Suite("AccessibilityComponents — Init")
struct AccessibilityComponentsTests {

    @Test("Default init has nil fields")
    func defaultInit() {
        let components = AccessibilityComponents()
        #expect(components.renditionGenerator == nil)
        #expect(components.webVTTSegmentDuration == nil)
    }

    @Test("Init with rendition generator")
    func withGenerator() {
        let components = AccessibilityComponents(
            renditionGenerator: AccessibilityRenditionGenerator()
        )
        #expect(components.renditionGenerator != nil)
    }

    @Test("Init with WebVTT segment duration")
    func withWebVTT() {
        let components = AccessibilityComponents(
            webVTTSegmentDuration: 6.0
        )
        #expect(components.webVTTSegmentDuration == 6.0)
    }
}

// MARK: - ResilienceComponents

@Suite("ResilienceComponents — Init")
struct ResilienceComponentsTests {

    @Test("Default init has nil fields")
    func defaultInit() {
        let components = ResilienceComponents()
        #expect(components.gapHandler == nil)
        #expect(components.failoverManager == nil)
    }

    @Test("Init with gap handler")
    func withGapHandler() {
        let components = ResilienceComponents(
            gapHandler: GapHandler()
        )
        #expect(components.gapHandler != nil)
    }

    @Test("Init with failover manager")
    func withFailover() {
        let config = RedundantStreamConfig(backups: [
            .init(primaryURI: "a.m3u8", backupURIs: ["b.m3u8"])
        ])
        let components = ResilienceComponents(
            failoverManager: FailoverManager(config: config)
        )
        #expect(components.failoverManager != nil)
    }
}

// MARK: - LivePipelineComponents — Setting Groups

@Suite("LivePipelineComponents — Setting New Groups")
struct LivePipelineComponentsSetGroupTests {

    @Test("Set spatial audio components")
    func setSpatialAudio() {
        var components = LivePipelineComponents()
        components.spatialAudio = SpatialAudioComponents(
            renditionGenerator: SpatialRenditionGenerator()
        )
        #expect(components.spatialAudio != nil)
    }

    @Test("Set HDR components")
    func setHDR() {
        var components = LivePipelineComponents()
        components.hdr = HDRComponents(
            variantGenerator: HDRVariantGenerator()
        )
        #expect(components.hdr != nil)
    }

    @Test("Set DRM components")
    func setDRM() {
        var components = LivePipelineComponents()
        components.drm = DRMComponents(
            sessionKeyManager: SessionKeyManager()
        )
        #expect(components.drm != nil)
    }

    @Test("Set accessibility components")
    func setAccessibility() {
        var components = LivePipelineComponents()
        components.accessibility = AccessibilityComponents(
            renditionGenerator: AccessibilityRenditionGenerator()
        )
        #expect(components.accessibility != nil)
    }

    @Test("Set resilience components")
    func setResilience() {
        var components = LivePipelineComponents()
        components.resilience = ResilienceComponents(
            gapHandler: GapHandler()
        )
        #expect(components.resilience != nil)
    }
}
