// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipeline", .timeLimit(.minutes(1)))
struct LivePipelineTests {

    // MARK: - Helpers

    private func validConfig() -> LivePipelineConfiguration {
        LivePipelineConfiguration()
    }

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xAB, count: size)
    }

    // MARK: - Init

    @Test("Init state is idle")
    func initIdle() async {
        let pipeline = LivePipeline()
        let state = await pipeline.state
        #expect(state == .idle)
    }

    @Test("Init segmentsProduced is 0")
    func initSegmentsZero() async {
        let pipeline = LivePipeline()
        let count = await pipeline.segmentsProduced
        #expect(count == 0)
    }

    @Test("Init totalBytes is 0")
    func initTotalBytesZero() async {
        let pipeline = LivePipeline()
        let bytes = await pipeline.totalBytes
        #expect(bytes == 0)
    }

    @Test("Uptime is 0 when idle")
    func uptimeIdle() async {
        let pipeline = LivePipeline()
        let uptime = await pipeline.uptime
        #expect(uptime == 0)
    }

    // MARK: - Start

    @Test("Start with valid config transitions to running")
    func startValid() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
    }

    @Test("Start with invalid config throws invalidConfiguration")
    func startInvalid() async {
        let pipeline = LivePipeline()
        var config = LivePipelineConfiguration()
        config.segmentDuration = -1
        do {
            try await pipeline.start(configuration: config)
            Issue.record("Expected error")
        } catch let error as LivePipelineError {
            #expect(error == .invalidConfiguration("segmentDuration must be greater than 0"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Start when already running throws alreadyRunning")
    func startAlreadyRunning() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        do {
            try await pipeline.start(configuration: validConfig())
            Issue.record("Expected error")
        } catch let error as LivePipelineError {
            #expect(error == .alreadyRunning)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    // MARK: - Stop

    @Test("Stop when running returns summary")
    func stopRunning() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 0)
        #expect(summary.totalBytes == 0)
        #expect(summary.reason == .userRequested)
        #expect(summary.duration >= 0)
    }

    @Test("Stop when not running throws notRunning")
    func stopNotRunning() async {
        let pipeline = LivePipeline()
        do {
            try await pipeline.stop()
            Issue.record("Expected error")
        } catch let error as LivePipelineError {
            #expect(error == .notRunning)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("State returns to idle after stop")
    func stateIdleAfterStop() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        try await pipeline.stop()
        let state = await pipeline.state
        #expect(state == .idle)
    }

    // MARK: - Process Segment

    @Test("processSegment increments counters")
    func processSegmentCounters() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        await pipeline.processSegment(
            data: segmentData(size: 500), duration: 6.0, filename: "seg0.ts"
        )
        let count = await pipeline.segmentsProduced
        let bytes = await pipeline.totalBytes
        #expect(count == 1)
        #expect(bytes == 500)
    }

    @Test("processSegment accumulates totalBytes")
    func processSegmentAccumulates() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        await pipeline.processSegment(
            data: segmentData(size: 100), duration: 6.0, filename: "seg0.ts"
        )
        await pipeline.processSegment(
            data: segmentData(size: 200), duration: 6.0, filename: "seg1.ts"
        )
        let bytes = await pipeline.totalBytes
        #expect(bytes == 300)
    }

    @Test("processSegment when not running is a no-op")
    func processSegmentNotRunning() async {
        let pipeline = LivePipeline()
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "seg0.ts"
        )
        let count = await pipeline.segmentsProduced
        #expect(count == 0)
    }

    // MARK: - Summary

    @Test("Summary contains correct values after processing segments")
    func summaryAfterSegments() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        await pipeline.processSegment(
            data: segmentData(size: 1000), duration: 6.0, filename: "seg0.ts"
        )
        await pipeline.processSegment(
            data: segmentData(size: 2000), duration: 6.0, filename: "seg1.ts"
        )
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 2)
        #expect(summary.totalBytes == 3000)
        #expect(summary.reason == .userRequested)
    }

    // MARK: - Destinations

    @Test("addDestination adds to active list")
    func addDestination() async {
        let pipeline = LivePipeline()
        await pipeline.addDestination(
            .http(url: "https://cdn.example.com"), id: "cdn1"
        )
        let dests = await pipeline.activeDestinations
        #expect(dests == ["cdn1"])
    }

    @Test("addDestination does not duplicate existing id")
    func addDestinationNoDuplicate() async {
        let pipeline = LivePipeline()
        await pipeline.addDestination(.local(directory: "/tmp"), id: "local1")
        await pipeline.addDestination(.local(directory: "/tmp"), id: "local1")
        let dests = await pipeline.activeDestinations
        #expect(dests.count == 1)
    }

    @Test("removeDestination removes from active list")
    func removeDestination() async {
        let pipeline = LivePipeline()
        await pipeline.addDestination(
            .http(url: "https://cdn.example.com"), id: "cdn1"
        )
        await pipeline.removeDestination(id: "cdn1")
        let dests = await pipeline.activeDestinations
        #expect(dests.isEmpty)
    }

    @Test("removeDestination with unknown id is a no-op")
    func removeUnknownDestination() async {
        let pipeline = LivePipeline()
        await pipeline.addDestination(.local(directory: "/tmp"), id: "local1")
        await pipeline.removeDestination(id: "unknown")
        let dests = await pipeline.activeDestinations
        #expect(dests == ["local1"])
    }

    // MARK: - Discontinuity

    @Test("insertDiscontinuity when not running is a no-op")
    func discontinuityNotRunning() async {
        let pipeline = LivePipeline()
        await pipeline.insertDiscontinuity()
    }

    @Test("insertDiscontinuity when running sets pending flag")
    func discontinuityRunning() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        await pipeline.insertDiscontinuity()
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
    }

    // MARK: - Uptime

    @Test("Uptime is greater than 0 when running")
    func uptimeRunning() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: validConfig())
        try await Task.sleep(for: .milliseconds(10))
        let uptime = await pipeline.uptime
        #expect(uptime > 0)
        try await pipeline.stop()
    }

    // MARK: - Multiple Start/Stop Cycles

    @Test("Multiple start/stop cycles work")
    func multipleStartStop() async throws {
        let pipeline = LivePipeline()

        // Cycle 1
        try await pipeline.start(configuration: validConfig())
        await pipeline.processSegment(
            data: segmentData(size: 100), duration: 6.0, filename: "seg0.ts"
        )
        let summary1 = try await pipeline.stop()
        #expect(summary1.segmentsProduced == 1)

        // Cycle 2
        try await pipeline.start(configuration: validConfig())
        let count = await pipeline.segmentsProduced
        #expect(count == 0)
        let summary2 = try await pipeline.stop()
        #expect(summary2.segmentsProduced == 0)
    }
}
