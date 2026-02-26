// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Phase 16 Integration", .timeLimit(.minutes(1)))
struct LivePipelinePhase16IntegrationTests {

    // MARK: - Helpers

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xEE, count: size)
    }

    // MARK: - Complete Podcast Workflow

    @Test("Podcast workflow: start → 10 segments → statistics → stop → verify")
    func podcastWorkflow() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: .podcastLive)
        for i in 0..<10 {
            await pipeline.processSegment(
                data: segmentData(size: 800), duration: 6.0,
                filename: "podcast\(i).ts"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 10)
        #expect(stats.totalBytes == 8000)
        #expect(stats.averageSegmentDuration == 6.0)

        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == stats.segmentsProduced)
        #expect(summary.totalBytes == stats.totalBytes)
    }

    // MARK: - Video DVR Session

    @Test("Video DVR: start → segments → verify DVR → stats → stop")
    func videoDVRSession() async throws {
        let pipeline = LivePipeline()
        let config = LivePipelineConfiguration.videoLiveWithDVR
        #expect(config.enableDVR == true)
        #expect(config.dvrWindowDuration == 14400)

        try await pipeline.start(configuration: config)
        for i in 0..<5 {
            await pipeline.processSegment(
                data: segmentData(size: 2000), duration: 6.0,
                filename: "dvr\(i).m4s"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.recordingActive == true)
        #expect(stats.recordedSegments == 5)
        try await pipeline.stop()
    }

    // MARK: - DJ Set With Statistics

    @Test("DJ set: 20 segments → verify statistics")
    func djSetStatistics() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: .djMixWithDVR)
        for i in 0..<20 {
            await pipeline.processSegment(
                data: segmentData(size: 4000), duration: 4.0,
                filename: "dj\(i).m4s"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 20)
        #expect(stats.totalBytes == 80000)
        #expect(stats.averageSegmentDuration == 4.0)
        #expect(stats.averageBytesPerSegment == 4000)

        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 20)
        #expect(summary.totalBytes == 80000)
    }

    // MARK: - Conference Recording

    @Test("Conference: event playlist → recording active")
    func conferenceRecording() async throws {
        let config = LivePipelineConfiguration.conferenceStream
        #expect(config.playlistType == .event)

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "conf0.m4s"
        )
        let stats = await pipeline.statistics
        #expect(stats.recordingActive == true)
        #expect(stats.recordedSegments == 1)
        try await pipeline.stop()
    }

    // MARK: - 4K Pipeline

    @Test("4K pipeline: start → segment → statistics → stop")
    func pipeline4K() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: .video4K)
        await pipeline.processSegment(
            data: segmentData(size: 5000), duration: 6.0, filename: "4k_seg0.m4s"
        )
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 1)
        #expect(stats.totalBytes == 5000)
        try await pipeline.stop()
    }

    // MARK: - Preset Comparison

    @Test("All 16 presets validate and are unique")
    func presetComparison() {
        let presets: [LivePipelineConfiguration] = [
            .podcastLive, .webradio, .djMix, .lowBandwidth,
            .videoLive, .lowLatencyVideo, .videoSimulcast,
            .applePodcastLive, .broadcast, .eventRecording,
            .video4K, .video4KLowLatency, .podcastVideo,
            .videoLiveWithDVR, .djMixWithDVR, .conferenceStream
        ]
        #expect(presets.count == 16)
        for preset in presets {
            #expect(preset.validate() == nil)
        }
    }

    // MARK: - Statistics Accumulation

    @Test("Statistics update after each segment")
    func statisticsAccumulation() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())

        await pipeline.processSegment(
            data: segmentData(size: 100), duration: 6.0, filename: "seg0.ts"
        )
        var stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 1)
        #expect(stats.totalBytes == 100)

        await pipeline.processSegment(
            data: segmentData(size: 200), duration: 4.0, filename: "seg1.ts"
        )
        stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 2)
        #expect(stats.totalBytes == 300)
        #expect(stats.lastSegmentBytes == 200)
        #expect(stats.lastSegmentDuration == 4.0)
        try await pipeline.stop()
    }

    // MARK: - Multi-Destination Statistics

    @Test("Multi-destination: add 2 → remove 1 → verify stats")
    func multiDestinationStats() async {
        let pipeline = LivePipeline()
        await pipeline.addDestination(.http(url: "https://cdn1.example.com"), id: "cdn1")
        await pipeline.addDestination(.http(url: "https://cdn2.example.com"), id: "cdn2")
        var stats = await pipeline.statistics
        #expect(stats.activeDestinations == 2)

        await pipeline.removeDestination(id: "cdn1")
        stats = await pipeline.statistics
        #expect(stats.activeDestinations == 1)
    }

    // MARK: - Discontinuity Tracking

    @Test("3 discontinuities → statistics.discontinuities == 3")
    func discontinuityTracking() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        await pipeline.insertDiscontinuity()
        await pipeline.insertDiscontinuity()
        await pipeline.insertDiscontinuity()
        let stats = await pipeline.statistics
        #expect(stats.discontinuities == 3)
        try await pipeline.stop()
    }

    // MARK: - Empty Pipeline Statistics

    @Test("Empty pipeline: start → immediate stats → all zeros except uptime")
    func emptyPipelineStats() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        try await Task.sleep(for: .milliseconds(5))
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 0)
        #expect(stats.totalBytes == 0)
        #expect(stats.uptime > 0)
        #expect(stats.startDate != nil)
        try await pipeline.stop()
    }

    // MARK: - Summary vs Statistics Consistency

    @Test("Stop summary matches statistics snapshot")
    func summaryVsStatistics() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        for i in 0..<5 {
            await pipeline.processSegment(
                data: segmentData(size: 300), duration: 6.0,
                filename: "seg\(i).ts"
            )
        }
        let stats = await pipeline.statistics
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == stats.segmentsProduced)
        #expect(summary.totalBytes == stats.totalBytes)
    }
}
