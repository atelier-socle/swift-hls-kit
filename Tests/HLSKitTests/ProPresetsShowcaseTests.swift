// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

// MARK: - Pro Presets Showcase

@Suite("Pro Presets — Showcase")
struct ProPresetsShowcaseTests {

    @Test("Spatial audio podcast: Atmos 5.1 with stereo fallback config")
    func spatialAudioPodcast() {
        let config = LivePipelineConfiguration.spatialAudioLive
        #expect(config.spatialAudio?.format == .dolbyAtmos)
        #expect(config.spatialAudio?.channelLayout == .surround5_1)
        #expect(config.audioBitrate == 128_000)

        let generator = SpatialRenditionGenerator()
        let renditions = generator.generateRenditions(
            config: config.spatialAudio ?? .atmos5_1,
            language: "en",
            name: "English (Atmos)"
        )
        #expect(renditions.count >= 2)
    }

    @Test("Hi-Res audiophile stream: 96kHz ALAC lossless")
    func hiResAudiophile() {
        let config = LivePipelineConfiguration.hiResLive
        #expect(config.hiResAudio?.sampleRate == .rate96kHz)
        #expect(config.hiResAudio?.bitDepth == .depth24)
        #expect(config.audioBitrate == 256_000)
    }

    @Test("Netflix-style HDR10 adaptive stream")
    func netflixHDR10() {
        let config = LivePipelineConfiguration.videoHDR
        #expect(config.hdr?.type == .hdr10)
        #expect(config.resolution == .fullHD1080p)
        #expect(config.videoEnabled)

        let mapper = VideoRangeMapper()
        let attrs = mapper.mapToHLSAttributes(config: config.hdr ?? .hdr10Default)
        #expect(attrs.videoRange == .pq)
    }

    @Test("Apple TV+ Dolby Vision live event")
    func appleTVDolbyVision() {
        let config = LivePipelineConfiguration.videoDolbyVision
        #expect(config.hdr?.type == .dolbyVisionWithHDR10Fallback)
        #expect(config.resolution == .uhd4K)
        #expect(config.resolution?.width == 3840)
        #expect(config.resolution?.height == 2160)
    }

    @Test("Premium 8K demo stream")
    func premium8K() {
        let config = LivePipelineConfiguration.video8K
        #expect(config.resolution == .uhd8K)
        #expect(config.resolution?.width == 7680)
        #expect(config.resolution?.height == 4320)
        #expect(config.videoEnabled)
    }

    @Test("Secure podcast: FairPlay with key rotation")
    func securePodcast() {
        let config = LivePipelineConfiguration.drmProtectedLive
        #expect(config.drm?.isEnabled == true)
        #expect(config.drm?.fairPlay != nil)
        #expect(config.drm?.rotationPolicy == .everyNSegments(10))
        #expect(config.drm?.isMultiDRM == false)
    }

    @Test("Global platform: multi-DRM for all devices")
    func globalMultiDRM() {
        let config = LivePipelineConfiguration.multiDRMLive
        #expect(config.drm?.isMultiDRM == true)
        #expect(config.drm?.cenc?.systems.contains(.widevine) == true)
        #expect(config.drm?.cenc?.systems.contains(.playReady) == true)
        #expect(config.drm?.fairPlay != nil)
    }

    @Test("Accessible broadcast: CC + audio description")
    func accessibleBroadcast() {
        let config = LivePipelineConfiguration.accessibleLive
        #expect(config.closedCaptions != nil)
        #expect(config.audioDescriptions?.count == 1)
        #expect(config.subtitlesEnabled)

        let generator = AccessibilityRenditionGenerator()
        let entries = generator.generateAll(
            captions: config.closedCaptions,
            audioDescriptions: config.audioDescriptions?.map {
                (config: $0, uri: "ad/\($0.language).m3u8")
            } ?? []
        )
        #expect(!entries.isEmpty)
    }

    @Test("Broadcast pro: everything enabled — the ultimate preset")
    func broadcastProUltimate() {
        let config = LivePipelineConfiguration.broadcastPro
        // Audio
        #expect(config.spatialAudio != nil)
        #expect(config.audioBitrate == 256_000)
        // Video
        #expect(config.videoEnabled)
        #expect(config.hdr != nil)
        #expect(config.resolution == .uhd4K)
        // DRM
        #expect(config.drm?.isEnabled == true)
        // Accessibility
        #expect(config.closedCaptions != nil)
        #expect(config.audioDescriptions != nil)
        #expect(config.subtitlesEnabled)
        // Recording
        #expect(config.enableRecording)
    }

    @Test("Custom preset: cherry-pick features from multiple presets")
    func customPreset() {
        var config = LivePipelineConfiguration()
        // Take spatial from spatialAudioLive
        config.spatialAudio = LivePipelineConfiguration.spatialAudioLive.spatialAudio
        // Take HDR from videoHDR
        config.hdr = LivePipelineConfiguration.videoHDR.hdr
        config.videoEnabled = true
        // Take DRM from drmProtectedLive
        config.drm = LivePipelineConfiguration.drmProtectedLive.drm
        // Add accessibility
        config.closedCaptions = .englishOnly608

        #expect(config.spatialAudio != nil)
        #expect(config.hdr?.type == .hdr10)
        #expect(config.drm?.isEnabled == true)
        #expect(config.closedCaptions?.standard == .cea608)
    }
}
