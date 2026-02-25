// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipelinePresets Showcase", .timeLimit(.minutes(1)))
struct LivePipelinePresetsShowcaseTests {

    // MARK: - Helpers

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xAA, count: size)
    }

    // MARK: - Podcast Workflow

    @Test("Podcast workflow: start with podcastLive → process segments → verify loudness config")
    func podcastWorkflow() async throws {
        let pipeline = LivePipeline()
        let config = LivePipelineConfiguration.podcastLive
        #expect(config.targetLoudness == -16.0)
        #expect(config.containerFormat == .mpegts)

        try await pipeline.start(configuration: config)
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "podcast_seg0.ts"
        )
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 1)
    }

    // MARK: - Music Station

    @Test("Music station: webradio preset with LL-HLS")
    func musicStation() async throws {
        let pipeline = LivePipeline()
        let config = LivePipelineConfiguration.webradio
        #expect(config.lowLatency != nil)
        #expect(config.audioBitrate == 256_000)

        try await pipeline.start(configuration: config)
        for i in 0..<3 {
            await pipeline.processSegment(
                data: segmentData(size: 2048), duration: 4.0,
                filename: "radio_seg\(i).m4s"
            )
        }
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 3)
    }

    // MARK: - DJ Set Recording

    @Test("DJ set recording: djMix preset with recording enabled")
    func djSetRecording() async throws {
        let pipeline = LivePipeline()
        let config = LivePipelineConfiguration.djMix
        #expect(config.enableRecording == true)
        #expect(config.audioBitrate == 320_000)

        try await pipeline.start(configuration: config)
        for i in 0..<5 {
            await pipeline.processSegment(
                data: segmentData(size: 4096), duration: 4.0,
                filename: "dj_seg\(i).m4s"
            )
        }
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 5)
        #expect(summary.totalBytes == 5 * 4096)
    }

    // MARK: - Apple Compliance

    @Test("Apple compliance: applePodcastLive with fMP4, -16 LUFS")
    func appleCompliance() async throws {
        let config = LivePipelineConfiguration.applePodcastLive
        #expect(config.containerFormat == .fmp4)
        #expect(config.targetLoudness == -16.0)
        #expect(config.enableProgramDateTime == true)
        #expect(config.playlistType == .slidingWindow(windowSize: 6))

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        try await pipeline.stop()
    }

    // MARK: - Broadcast Compliance

    @Test("Broadcast compliance: -23 LUFS (EBU R 128), DVR, recording")
    func broadcastCompliance() async throws {
        let config = LivePipelineConfiguration.broadcast
        #expect(config.targetLoudness == -23.0)
        #expect(config.enableDVR == true)
        #expect(config.dvrWindowDuration == 7200)
        #expect(config.enableRecording == true)

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        try await pipeline.stop()
    }

    // MARK: - Low-Bandwidth Adaptation

    @Test("Low-bandwidth: mono, low bitrate, longer segments")
    func lowBandwidthAdaptation() async throws {
        let config = LivePipelineConfiguration.lowBandwidth
        #expect(config.audioChannels == 1)
        #expect(config.audioBitrate == 48_000)
        #expect(config.audioSampleRate == 22_050)
        #expect(config.segmentDuration == 10.0)

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        await pipeline.processSegment(
            data: segmentData(size: 512), duration: 10.0, filename: "low_seg0.ts"
        )
        try await pipeline.stop()
    }

    // MARK: - Preset Customization

    @Test("Preset customization: modify podcastLive targetLoudness")
    func presetCustomization() async throws {
        var config = LivePipelineConfiguration.podcastLive
        config.targetLoudness = -14.0
        #expect(config.validate() == nil)

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        try await pipeline.stop()
    }

    // MARK: - Video Simulcast

    @Test("Video simulcast: add destination after preset")
    func videoSimulcast() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: .videoSimulcast)
        await pipeline.addDestination(
            .http(url: "https://rtmp.youtube.com/live"), id: "youtube"
        )
        let dests = await pipeline.activeDestinations
        #expect(dests == ["youtube"])
        try await pipeline.stop()
    }
}
