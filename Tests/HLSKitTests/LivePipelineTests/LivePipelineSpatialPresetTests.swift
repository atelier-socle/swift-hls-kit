// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("LivePipelineConfiguration Spatial Video Presets")
struct LivePipelineSpatialPresetTests {

    @Test("spatialVideo default has video enabled")
    func defaultVideoEnabled() {
        let config = LivePipelineConfiguration.spatialVideo()
        #expect(config.videoEnabled)
    }

    @Test("spatialVideo default uses 10 Mbps bitrate")
    func defaultBitrate() {
        let config = LivePipelineConfiguration.spatialVideo()
        #expect(config.videoBitrate == 10_000_000)
    }

    @Test("spatialVideo default uses fullHD1080p resolution")
    func defaultResolution() {
        let config = LivePipelineConfiguration.spatialVideo()
        #expect(config.resolution == .fullHD1080p)
    }

    @Test("spatialVideo with dolbyVision uses 15 Mbps and 4K")
    func dolbyVisionPreset() {
        let config = LivePipelineConfiguration.spatialVideo(
            dolbyVision: true
        )
        #expect(config.videoBitrate == 15_000_000)
        #expect(config.resolution == .uhd4K)
        #expect(config.hdr == .dolbyVisionProfile8)
    }

    @Test("spatialVideo with mono layout still enables video")
    func monoLayout() {
        let config = LivePipelineConfiguration.spatialVideo(
            channelLayout: .mono
        )
        #expect(config.videoEnabled)
        #expect(config.videoBitrate == 10_000_000)
    }
}
