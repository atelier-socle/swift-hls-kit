// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipeline Accessors & Backward Compat", .timeLimit(.minutes(1)))
struct LivePipelineAccessorTests {

    // MARK: - Helpers

    private func segmentData(size: Int = 1024) -> Data {
        Data(repeating: 0xDD, count: size)
    }

    // MARK: - Component Accessors

    @Test("currentLoudness: nil without meter")
    func currentLoudnessNil() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let loudness = await pipeline.currentLoudness
        #expect(loudness == nil)
        try await pipeline.stop()
    }

    @Test("hasLevelMeter: false without meter")
    func hasLevelMeterFalse() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let has = await pipeline.hasLevelMeter
        #expect(has == false)
        try await pipeline.stop()
    }

    @Test("hasLevelMeter: true with meter")
    func hasLevelMeterTrue() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents(
            audio: AudioComponents(levelMeter: LevelMeter())
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let has = await pipeline.hasLevelMeter
        #expect(has == true)
        try await pipeline.stop()
    }

    @Test("hasSilenceDetector: false without detector")
    func hasSilenceDetectorFalse() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let has = await pipeline.hasSilenceDetector
        #expect(has == false)
        try await pipeline.stop()
    }

    @Test("hasSilenceDetector: true with detector")
    func hasSilenceDetectorTrue() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents(
            audio: AudioComponents(silenceDetector: SilenceDetector())
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        let has = await pipeline.hasSilenceDetector
        #expect(has == true)
        try await pipeline.stop()
    }

    @Test("recordingStats: nil without recorder")
    func recordingStatsNil() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        let stats = await pipeline.recordingStats
        #expect(stats == nil)
        try await pipeline.stop()
    }

    // MARK: - New Event Cases

    @Test("LivePipelineEvent: new cases compile and are distinct")
    func newEventCases() {
        let events: [LivePipelineEvent] = [
            .metadataInjected,
            .interstitialScheduled("ad-1"),
            .scte35Inserted,
            .recordingFinalized,
            .silenceDetected(duration: 5.0),
            .loudnessUpdate(lufs: -16.0),
            .pushSucceeded(destination: "cdn", bytesSent: 1024),
            .componentWarning("test warning")
        ]
        #expect(events.count == 8)
    }

    // MARK: - New Error Case

    @Test("LivePipelineError: componentNotConfigured")
    func componentNotConfiguredError() {
        let error = LivePipelineError.componentNotConfigured("TestComponent")
        #expect(error == .componentNotConfigured("TestComponent"))
        #expect(error != .notRunning)
    }

    // MARK: - Full Lifecycle

    @Test("Full lifecycle: start, processSegment, stop (with components)")
    func fullLifecycleWithComponents() async throws {
        let pipeline = LivePipeline()
        let components = LivePipelineComponents(
            audio: AudioComponents(levelMeter: LevelMeter())
        )
        try await pipeline.start(
            configuration: LivePipelineConfiguration(),
            components: components
        )
        await pipeline.processSegment(
            data: segmentData(), duration: 6.0, filename: "seg0.m4s"
        )
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 1)
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 1)
    }

    // MARK: - Existing API Backward Compatibility

    @Test("Existing processSegment still works without components")
    func existingProcessSegment() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        await pipeline.processSegment(
            data: segmentData(size: 500), duration: 6.0, filename: "seg0.ts"
        )
        let stats = await pipeline.statistics
        #expect(stats.segmentsProduced == 1)
        #expect(stats.totalBytes == 500)
        try await pipeline.stop()
    }

    @Test("Existing addDestination/removeDestination still works")
    func existingDestinationMethods() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        await pipeline.addDestination(
            .http(url: "https://cdn.example.com"), id: "cdn"
        )
        var dests = await pipeline.activeDestinations
        #expect(dests.count == 1)
        await pipeline.removeDestination(id: "cdn")
        dests = await pipeline.activeDestinations
        #expect(dests.count == 0)
        try await pipeline.stop()
    }

    @Test("Existing insertDiscontinuity still works")
    func existingInsertDiscontinuity() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: LivePipelineConfiguration())
        await pipeline.insertDiscontinuity()
        let stats = await pipeline.statistics
        #expect(stats.discontinuities == 1)
        try await pipeline.stop()
    }
}
