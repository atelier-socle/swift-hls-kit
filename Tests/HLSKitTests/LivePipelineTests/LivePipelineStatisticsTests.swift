// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipelineStatistics", .timeLimit(.minutes(1)))
struct LivePipelineStatisticsTests {

    // MARK: - Helpers

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xBB, count: size)
    }

    // MARK: - Default Init

    @Test("Default init: all zeros/nils")
    func defaultInit() {
        let stats = LivePipelineStatistics()
        #expect(stats.uptime == 0)
        #expect(stats.startDate == nil)
        #expect(stats.segmentsProduced == 0)
        #expect(stats.averageSegmentDuration == 0)
        #expect(stats.lastSegmentDuration == 0)
        #expect(stats.lastSegmentBytes == 0)
        #expect(stats.totalBytes == 0)
        #expect(stats.estimatedBitrate == 0)
        #expect(stats.bytesSent == 0)
        #expect(stats.pushErrors == 0)
        #expect(stats.activeDestinations == 0)
        #expect(stats.audioPeakDB == nil)
        #expect(stats.loudnessLUFS == nil)
        #expect(stats.partialsProduced == 0)
        #expect(stats.recordingActive == false)
        #expect(stats.recordedSegments == 0)
        #expect(stats.discontinuities == 0)
        #expect(stats.droppedSegments == 0)
    }

    // MARK: - Computed Properties

    @Test("averageBytesPerSegment: totalBytes / segmentsProduced")
    func averageBytesPerSegment() {
        var stats = LivePipelineStatistics()
        stats.totalBytes = 3000
        stats.segmentsProduced = 3
        #expect(stats.averageBytesPerSegment == 1000)
    }

    @Test("averageBytesPerSegment: 0 when no segments")
    func averageBytesNoSegments() {
        let stats = LivePipelineStatistics()
        #expect(stats.averageBytesPerSegment == 0)
    }

    @Test("hasPushErrors: false when 0")
    func hasPushErrorsFalse() {
        let stats = LivePipelineStatistics()
        #expect(stats.hasPushErrors == false)
    }

    @Test("hasPushErrors: true when > 0")
    func hasPushErrorsTrue() {
        var stats = LivePipelineStatistics()
        stats.pushErrors = 3
        #expect(stats.hasPushErrors == true)
    }

    // MARK: - Equatable

    @Test("Same values are equal")
    func equatable() {
        let a = LivePipelineStatistics()
        let b = LivePipelineStatistics()
        #expect(a == b)
    }

    @Test("All fields settable and readable")
    func allFieldsSettable() {
        var stats = LivePipelineStatistics()
        stats.uptime = 60
        stats.startDate = Date()
        stats.segmentsProduced = 10
        stats.averageSegmentDuration = 6.0
        stats.lastSegmentDuration = 5.5
        stats.lastSegmentBytes = 2048
        stats.totalBytes = 20480
        stats.estimatedBitrate = 2730
        stats.bytesSent = 10240
        stats.pushErrors = 1
        stats.activeDestinations = 2
        stats.audioPeakDB = -3.0
        stats.loudnessLUFS = -16.0
        stats.partialsProduced = 5
        stats.recordingActive = true
        stats.recordedSegments = 10
        stats.discontinuities = 2
        stats.droppedSegments = 1
        #expect(stats.segmentsProduced == 10)
        #expect(stats.audioPeakDB == -3.0)
        #expect(stats.hasPushErrors == true)
    }

    // MARK: - Pipeline Integration

    @Test("Pipeline statistics: idle → all zeros")
    func pipelineIdle() async {
        let pipeline = LivePipeline()
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 0)
        #expect(stats.totalBytes == 0)
        #expect(stats.uptime == 0)
        #expect(stats.startDate == nil)
    }

    @Test("Pipeline statistics: after 3 segments → correct counts")
    func pipelineAfterSegments() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        for i in 0..<3 {
            await pipeline.processSegment(
                data: segmentData(size: 500), duration: 6.0,
                filename: "seg\(i).ts"
            )
        }
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 3)
        #expect(stats.totalBytes == 1500)
        #expect(stats.lastSegmentDuration == 6.0)
        #expect(stats.lastSegmentBytes == 500)
        #expect(stats.averageSegmentDuration == 6.0)
        try await pipeline.stop()
    }

    @Test("Pipeline statistics: uptime > 0 when running")
    func pipelineUptime() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        try await Task.sleep(for: .milliseconds(10))
        let stats = await pipeline.statistics
        #expect(stats.uptime > 0)
        #expect(stats.startDate != nil)
        try await pipeline.stop()
    }

    @Test("Pipeline statistics: activeDestinations reflects added destinations")
    func pipelineDestinations() async throws {
        let pipeline = LivePipeline()
        await pipeline.addDestination(.http(url: "https://cdn.example.com"), id: "cdn1")
        await pipeline.addDestination(.local(directory: "/tmp"), id: "local1")
        let stats = await pipeline.statistics
        #expect(stats.activeDestinations == 2)
    }

    @Test("Pipeline statistics: discontinuities count correct")
    func pipelineDiscontinuities() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        await pipeline.insertDiscontinuity()
        await pipeline.insertDiscontinuity()
        let stats = await pipeline.statistics
        #expect(stats.discontinuities == 2)
        try await pipeline.stop()
    }

    @Test("Pipeline statistics: recordingActive reflects config")
    func pipelineRecording() async throws {
        var config = LivePipelineConfiguration()
        config.enableRecording = true
        config.recordingDirectory = "/tmp/rec"
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        let stats = await pipeline.statistics
        #expect(stats.recordingActive == true)
        try await pipeline.stop()
    }

    @Test("Pipeline statistics: estimatedBitrate calculation")
    func pipelineEstimatedBitrate() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        try await Task.sleep(for: .milliseconds(10))
        await pipeline.processSegment(
            data: segmentData(size: 10000), duration: 6.0, filename: "seg0.ts"
        )
        let stats = await pipeline.statistics
        #expect(stats.estimatedBitrate > 0)
        try await pipeline.stop()
    }

    @Test("Pipeline statistics: audioPeakDB and loudnessLUFS nil (no real audio)")
    func pipelineAudioNil() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "seg0.ts"
        )
        let stats = await pipeline.statistics
        #expect(stats.audioPeakDB == nil)
        #expect(stats.loudnessLUFS == nil)
        try await pipeline.stop()
    }
}
