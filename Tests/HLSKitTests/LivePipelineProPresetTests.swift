// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - Pro Presets — Defaults

@Suite("LivePipelineConfiguration Pro Presets — Defaults")
struct LivePipelineProPresetDefaultTests {

    @Test("Default config has all new properties nil/false")
    func defaultConfig() {
        let config = LivePipelineConfiguration()
        #expect(config.spatialAudio == nil)
        #expect(config.hiResAudio == nil)
        #expect(config.hdr == nil)
        #expect(config.resolution == nil)
        #expect(config.drm == nil)
        #expect(config.closedCaptions == nil)
        #expect(config.audioDescriptions == nil)
        #expect(!config.subtitlesEnabled)
        #expect(config.redundancy == nil)
        #expect(config.contentSteering == nil)
        #expect(config.sessionData == nil)
    }
}

// MARK: - Pro Presets — Spatial Audio

@Suite("LivePipelineConfiguration Pro Presets — Spatial Audio")
struct LivePipelineProPresetSpatialTests {

    @Test("spatialAudioLive has spatial audio configured")
    func spatialAudioLive() {
        let config = LivePipelineConfiguration.spatialAudioLive
        #expect(config.spatialAudio != nil)
        #expect(config.hiResAudio == nil)
        #expect(config.audioBitrate == 128_000)
    }

    @Test("spatialAudioLive uses Atmos 5.1")
    func spatialAudioLiveAtmos() {
        let config = LivePipelineConfiguration.spatialAudioLive
        #expect(config.spatialAudio?.format == .dolbyAtmos)
    }

    @Test("hiResLive has hi-res audio configured")
    func hiResLive() {
        let config = LivePipelineConfiguration.hiResLive
        #expect(config.hiResAudio != nil)
        #expect(config.spatialAudio == nil)
        #expect(config.audioBitrate == 256_000)
    }

    @Test("hiResLive uses studio hi-res config")
    func hiResLiveStudio() {
        let config = LivePipelineConfiguration.hiResLive
        #expect(config.hiResAudio?.sampleRate == .rate96kHz)
    }
}

// MARK: - Pro Presets — HDR Video

@Suite("LivePipelineConfiguration Pro Presets — HDR Video")
struct LivePipelineProPresetHDRTests {

    @Test("videoHDR has HDR10 and video enabled")
    func videoHDR() {
        let config = LivePipelineConfiguration.videoHDR
        #expect(config.videoEnabled)
        #expect(config.hdr != nil)
        #expect(config.hdr?.type == .hdr10)
    }

    @Test("videoHDR uses 1080p resolution")
    func videoHDRResolution() {
        let config = LivePipelineConfiguration.videoHDR
        #expect(config.resolution == .fullHD1080p)
    }

    @Test("videoDolbyVision has DV Profile 8")
    func videoDolbyVision() {
        let config = LivePipelineConfiguration.videoDolbyVision
        #expect(config.videoEnabled)
        #expect(config.hdr?.type == .dolbyVisionWithHDR10Fallback)
    }

    @Test("videoDolbyVision uses 4K resolution")
    func videoDolbyVisionResolution() {
        let config = LivePipelineConfiguration.videoDolbyVision
        #expect(config.resolution == .uhd4K)
    }

    @Test("video8K uses 8K resolution")
    func video8K() {
        let config = LivePipelineConfiguration.video8K
        #expect(config.videoEnabled)
        #expect(config.resolution == .uhd8K)
    }

    @Test("video8K has 7680x4320 dimensions")
    func video8KDimensions() {
        let config = LivePipelineConfiguration.video8K
        #expect(config.resolution?.width == 7680)
        #expect(config.resolution?.height == 4320)
    }
}

// MARK: - Pro Presets — DRM

@Suite("LivePipelineConfiguration Pro Presets — DRM")
struct LivePipelineProPresetDRMTests {

    @Test("drmProtectedLive has DRM enabled")
    func drmProtectedLive() {
        let config = LivePipelineConfiguration.drmProtectedLive
        #expect(config.drm != nil)
        #expect(config.drm?.isEnabled == true)
        #expect(config.drm?.isMultiDRM == false)
    }

    @Test("drmProtectedLive uses FairPlay modern")
    func drmProtectedLiveFairPlay() {
        let config = LivePipelineConfiguration.drmProtectedLive
        #expect(config.drm?.fairPlay != nil)
        #expect(config.drm?.rotationPolicy == .everyNSegments(10))
    }

    @Test("multiDRMLive has multi-DRM enabled")
    func multiDRMLive() {
        let config = LivePipelineConfiguration.multiDRMLive
        #expect(config.drm != nil)
        #expect(config.drm?.isMultiDRM == true)
    }

    @Test("multiDRMLive has CENC with Widevine and PlayReady")
    func multiDRMLiveCENC() {
        let config = LivePipelineConfiguration.multiDRMLive
        #expect(config.drm?.cenc != nil)
        #expect(config.drm?.cenc?.systems.contains(.widevine) == true)
        #expect(config.drm?.cenc?.systems.contains(.playReady) == true)
    }
}

// MARK: - Pro Presets — Accessibility

@Suite("LivePipelineConfiguration Pro Presets — Accessibility")
struct LivePipelineProPresetAccessibilityTests {

    @Test("accessibleLive has closed captions")
    func accessibleLiveCaptions() {
        let config = LivePipelineConfiguration.accessibleLive
        #expect(config.closedCaptions != nil)
        #expect(config.closedCaptions == .englishSpanish708)
    }

    @Test("accessibleLive has audio descriptions")
    func accessibleLiveAudioDesc() {
        let config = LivePipelineConfiguration.accessibleLive
        #expect(config.audioDescriptions != nil)
        #expect(config.audioDescriptions?.count == 1)
    }

    @Test("accessibleLive has subtitles enabled")
    func accessibleLiveSubtitles() {
        let config = LivePipelineConfiguration.accessibleLive
        #expect(config.subtitlesEnabled)
    }
}

// MARK: - Pro Presets — Broadcast Pro

@Suite("LivePipelineConfiguration Pro Presets — Broadcast Pro")
struct LivePipelineProPresetBroadcastTests {

    @Test("broadcastPro has spatial audio")
    func broadcastProSpatial() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.spatialAudio != nil)
        #expect(config.spatialAudio?.format == .dolbyAtmos)
    }

    @Test("broadcastPro has HDR")
    func broadcastProHDR() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.hdr != nil)
        #expect(config.hdr?.type == .dolbyVisionWithHDR10Fallback)
    }

    @Test("broadcastPro has DRM")
    func broadcastProDRM() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.drm != nil)
        #expect(config.drm?.isEnabled == true)
    }

    @Test("broadcastPro has closed captions")
    func broadcastProCaptions() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.closedCaptions == .broadcast708)
    }

    @Test("broadcastPro has audio descriptions")
    func broadcastProAudioDesc() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.audioDescriptions?.count == 3)
    }

    @Test("broadcastPro has recording enabled")
    func broadcastProRecording() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.enableRecording)
        #expect(config.recordingDirectory == "recordings")
    }

    @Test("broadcastPro has video enabled with 4K")
    func broadcastProVideo() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.videoEnabled)
        #expect(config.resolution == .uhd4K)
    }

    @Test("broadcastPro has 256 kbps audio")
    func broadcastProAudio() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.audioBitrate == 256_000)
    }

    @Test("broadcastPro has subtitles enabled")
    func broadcastProSubtitles() {
        let config = LivePipelineConfiguration.broadcastPro
        #expect(config.subtitlesEnabled)
    }
}

// MARK: - Pro Presets — Equatable

@Suite("LivePipelineConfiguration Pro Presets — Equatable")
struct LivePipelineProPresetEquatableTests {

    @Test("Same preset is equal to itself")
    func samePreset() {
        let a = LivePipelineConfiguration.spatialAudioLive
        let b = LivePipelineConfiguration.spatialAudioLive
        #expect(a == b)
    }

    @Test("Different presets are not equal")
    func differentPresets() {
        let a = LivePipelineConfiguration.spatialAudioLive
        let b = LivePipelineConfiguration.videoHDR
        #expect(a != b)
    }
}
