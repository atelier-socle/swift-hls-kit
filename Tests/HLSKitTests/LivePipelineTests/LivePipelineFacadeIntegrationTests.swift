// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipeline Facade Integration", .timeLimit(.minutes(1)))
struct LivePipelineFacadeIntegrationTests {

    // MARK: - Helpers

    private func validConfig() -> LivePipelineConfiguration {
        LivePipelineConfiguration()
    }

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xCD, count: size)
    }

    // MARK: - Full Lifecycle

    @Test("Full lifecycle: start → process 5 segments → stop → verify summary")
    func fullLifecycle() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())

        for i in 0..<5 {
            await pipeline.processSegment(
                data: segmentData(size: 1000 + i * 100),
                duration: 6.0,
                filename: "seg\(i).ts"
            )
        }

        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 5)
        // 1000 + 1100 + 1200 + 1300 + 1400 = 6000
        #expect(summary.totalBytes == 6000)
        #expect(summary.reason == .userRequested)
        #expect(summary.duration >= 0)
        #expect(summary.startDate <= summary.stopDate)
    }

    // MARK: - Configuration Validation

    @Test("Configuration validation catches all error types")
    func configValidationErrors() async {
        let pipeline = LivePipeline()

        // segmentDuration
        var c1 = LivePipelineConfiguration()
        c1.segmentDuration = 0
        do {
            try await pipeline.start(configuration: c1)
            Issue.record("Expected error")
        } catch let error as LivePipelineError {
            if case let .invalidConfiguration(msg) = error {
                #expect(msg.contains("segmentDuration"))
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // videoBitrate when video enabled
        var c2 = LivePipelineConfiguration()
        c2.videoEnabled = true
        c2.videoBitrate = 0
        do {
            try await pipeline.start(configuration: c2)
            Issue.record("Expected error")
        } catch let error as LivePipelineError {
            if case let .invalidConfiguration(msg) = error {
                #expect(msg.contains("videoBitrate"))
            } else {
                Issue.record("Wrong error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - State Machine

    @Test("State machine prevents invalid transitions comprehensively")
    func invalidTransitions() async throws {
        let pipeline = LivePipeline()

        // Cannot stop from idle
        do {
            try await pipeline.stop()
            Issue.record("Expected error")
        } catch let error as LivePipelineError {
            #expect(error == .notRunning)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        // Start → running
        try await pipeline.start(configuration: validConfig())

        // Cannot start again
        do {
            try await pipeline.start(configuration: validConfig())
            Issue.record("Expected error")
        } catch let error as LivePipelineError {
            #expect(error == .alreadyRunning)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        try await pipeline.stop()
    }

    // MARK: - Destinations

    @Test("Multiple destinations: add 2, remove 1, verify active list")
    func multipleDestinations() async {
        let pipeline = LivePipeline()
        await pipeline.addDestination(
            .http(url: "https://cdn1.example.com"), id: "cdn1"
        )
        await pipeline.addDestination(
            .http(url: "https://cdn2.example.com"), id: "cdn2"
        )
        let before = await pipeline.activeDestinations
        #expect(before.count == 2)

        await pipeline.removeDestination(id: "cdn1")
        let after = await pipeline.activeDestinations
        #expect(after == ["cdn2"])
    }

    // MARK: - Recording

    @Test("Recording flag: processSegment tracks recording-enabled config")
    func recordingEnabled() async throws {
        var config = LivePipelineConfiguration()
        config.enableRecording = true
        config.recordingDirectory = "/tmp/recording"

        let pipeline = LivePipeline()
        try await pipeline.start(configuration: config)
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "rec_seg0.ts"
        )
        let count = await pipeline.segmentsProduced
        #expect(count == 1)
        try await pipeline.stop()
    }

    // MARK: - Discontinuity

    @Test("Discontinuity: insert when running does not crash")
    func discontinuityInsert() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        await pipeline.insertDiscontinuity()
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "seg0.ts"
        )
        let count = await pipeline.segmentsProduced
        #expect(count == 1)
        try await pipeline.stop()
    }

    // MARK: - Large Segment Count

    @Test("Process 100 segments → counters correct")
    func largeSegmentCount() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())

        for i in 0..<100 {
            await pipeline.processSegment(
                data: segmentData(size: 50),
                duration: 6.0,
                filename: "seg\(i).ts"
            )
        }

        let count = await pipeline.segmentsProduced
        let bytes = await pipeline.totalBytes
        #expect(count == 100)
        #expect(bytes == 5000)

        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 100)
        #expect(summary.totalBytes == 5000)
    }

    // MARK: - Concurrent Safety

    @Test("Concurrent processSegment calls via actor isolation")
    func concurrentSafety() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<20 {
                group.addTask {
                    await pipeline.processSegment(
                        data: Data(repeating: UInt8(i % 256), count: 100),
                        duration: 6.0,
                        filename: "seg\(i).ts"
                    )
                }
            }
        }

        let count = await pipeline.segmentsProduced
        let bytes = await pipeline.totalBytes
        #expect(count == 20)
        #expect(bytes == 2000)
        try await pipeline.stop()
    }
}
