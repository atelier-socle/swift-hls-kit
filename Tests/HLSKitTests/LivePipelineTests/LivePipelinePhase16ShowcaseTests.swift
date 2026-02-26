// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Phase 16 Showcase", .timeLimit(.minutes(1)))
struct LivePipelinePhase16ShowcaseTests {

    // MARK: - Helpers

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xCC, count: size)
    }

    // MARK: - Production Podcast Studio

    @Test("Production podcast: applePodcastLive with statistics monitoring")
    func productionPodcast() async throws {
        let pipeline = LivePipeline()
        let config = LivePipelineConfiguration.applePodcastLive
        #expect(config.targetLoudness == -16.0)
        #expect(config.containerFormat == .fmp4)

        try await pipeline.start(configuration: config)
        for i in 0..<10 {
            await pipeline.processSegment(
                data: segmentData(size: 1500), duration: 6.0,
                filename: "apple_seg\(i).m4s"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 10)
        #expect(stats.totalBytes == 15000)
        try await pipeline.stop()
    }

    // MARK: - Music Festival DJ Set

    @Test("Festival DJ set: djMixWithDVR with high segment count")
    func festivalDJSet() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: .djMixWithDVR)
        for i in 0..<100 {
            await pipeline.processSegment(
                data: segmentData(size: 4000), duration: 4.0,
                filename: "festival_seg\(i).m4s"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 100)
        #expect(stats.totalBytes == 400000)
        #expect(stats.recordingActive == true)
        #expect(stats.recordedSegments == 100)
        try await pipeline.stop()
    }

    // MARK: - Sports Broadcast

    @Test("Sports broadcast: EBU R 128, DVR, recording")
    func sportsBroadcast() async throws {
        let config = LivePipelineConfiguration.broadcast
        #expect(config.targetLoudness == -23.0)
        #expect(config.enableDVR == true)
        #expect(config.enableRecording == true)

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        for i in 0..<5 {
            await pipeline.processSegment(
                data: segmentData(size: 2000), duration: 6.0,
                filename: "sports_seg\(i).m4s"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.recordingActive == true)
        #expect(stats.recordedSegments == 5)
        try await pipeline.stop()
    }

    // MARK: - Low-Latency Esports

    @Test("Esports: lowLatencyVideo with 0.33s parts")
    func esportsLowLatency() async throws {
        let config = LivePipelineConfiguration.lowLatencyVideo
        #expect(config.lowLatency?.partTargetDuration == 0.33)

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        for i in 0..<3 {
            await pipeline.processSegment(
                data: segmentData(size: 3000), duration: 4.0,
                filename: "esports_seg\(i).m4s"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 3)
        try await pipeline.stop()
    }

    // MARK: - Multi-Platform Simulcast

    @Test("Simulcast: videoSimulcast with 3 destinations")
    func multiPlatformSimulcast() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: .videoSimulcast)
        await pipeline.addDestination(
            .http(url: "rtmp://youtube.com/live"), id: "youtube"
        )
        await pipeline.addDestination(
            .http(url: "rtmp://twitch.tv/live"), id: "twitch"
        )
        await pipeline.addDestination(
            .http(url: "https://cdn.example.com"), id: "hls-cdn"
        )
        let stats = await pipeline.statistics
        #expect(stats.activeDestinations == 3)
        try await pipeline.stop()
    }

    // MARK: - Conference With Chapters

    @Test("Conference: segments with discontinuity markers at topic changes")
    func conferenceWithChapters() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: .conferenceStream)

        for i in 0..<3 {
            await pipeline.processSegment(
                data: segmentData(), duration: 6.0, filename: "intro\(i).m4s"
            )
        }
        await pipeline.insertDiscontinuity()
        for i in 0..<3 {
            await pipeline.processSegment(
                data: segmentData(), duration: 6.0, filename: "topic1_\(i).m4s"
            )
        }
        await pipeline.insertDiscontinuity()

        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 6)
        #expect(stats.discontinuities == 2)
        try await pipeline.stop()
    }

    // MARK: - Preset Customization

    @Test("Customization: modify podcastLive bitrate → validate → use")
    func presetCustomization() async throws {
        var config = LivePipelineConfiguration.podcastLive
        config.audioBitrate = 192_000
        #expect(config.validate() == nil)

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "custom_seg0.ts"
        )
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 1)
    }

    // MARK: - All Presets Run

    @Test("All 16 presets: start → 1 segment → stats → stop")
    func allPresetsRun() async throws {
        let presets: [LivePipelineConfiguration] = [
            .podcastLive, .webradio, .djMix, .lowBandwidth,
            .videoLive, .lowLatencyVideo, .videoSimulcast,
            .applePodcastLive, .broadcast, .eventRecording,
            .video4K, .video4KLowLatency, .podcastVideo,
            .videoLiveWithDVR, .djMixWithDVR, .conferenceStream
        ]
        for preset in presets {
            let pipeline = LivePipeline()
            try await pipeline.start(configuration: preset)
            await pipeline.processSegment(
                data: segmentData(), duration: 6.0, filename: "test.m4s"
            )
            let stats = await pipeline.statistics
            #expect(stats.segmentsProduced == 1)
            try await pipeline.stop()
        }
    }
}
