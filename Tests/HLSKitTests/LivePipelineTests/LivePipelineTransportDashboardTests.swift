// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Dashboard Tests

@Suite(
    "LivePipeline — Transport Dashboard",
    .timeLimit(.minutes(1))
)
struct LivePipelineTransportDashboardTests {

    @Test("Dashboard nil with no transport-aware destinations")
    func dashboardNilWithoutTransportDests() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        #expect(
            await pipeline.transportHealthDashboard() == nil
        )
        _ = try await pipeline.stop()
    }

    @Test("Dashboard returns correct destination count")
    func dashboardCorrectCount() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let t1 = OrchQualityTransport()
        let t2 = OrchQualityTransport()
        await pipeline.addDestination(
            orchPusher(transport: t1), id: "d-1"
        )
        await pipeline.addDestination(
            orchPusher(transport: t2), id: "d-2"
        )
        let dashboard = await pipeline.transportHealthDashboard()
        #expect(dashboard?.destinations.count == 2)
        _ = try await pipeline.stop()
    }

    @Test("Dashboard computes worst-case overall grade")
    func dashboardOverallGrade() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let goodQ = TransportQuality(
            score: 0.8, grade: .good,
            recommendation: nil, timestamp: Date()
        )
        let poorQ = TransportQuality(
            score: 0.35, grade: .poor,
            recommendation: nil, timestamp: Date()
        )
        await pipeline.addDestination(
            orchPusher(
                transport: OrchQualityTransport(quality: goodQ)
            ),
            id: "good"
        )
        await pipeline.addDestination(
            orchPusher(
                transport: OrchQualityTransport(quality: poorQ)
            ),
            id: "poor"
        )
        let dashboard = await pipeline.transportHealthDashboard()
        #expect(dashboard?.overallGrade == .poor)
        _ = try await pipeline.stop()
    }

    @Test("Dashboard includes correct connection states")
    func dashboardConnectionStates() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        await pipeline.addDestination(
            orchPusher(transport: OrchQualityTransport()),
            id: "dest-1"
        )
        let dest = await pipeline.transportHealthDashboard()?
            .destinations.first
        #expect(dest?.connectionState == .connected)
        #expect(dest?.label == "dest-1")
        _ = try await pipeline.stop()
    }

    @Test("Dashboard updates when destination added/removed")
    func dashboardUpdatesOnChange() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        await pipeline.addDestination(
            orchPusher(transport: OrchQualityTransport()),
            id: "dest-1"
        )
        #expect(
            await pipeline.transportHealthDashboard()?
                .destinations.count == 1
        )
        await pipeline.removeDestination(id: "dest-1")
        #expect(
            await pipeline.transportHealthDashboard() == nil
        )
        _ = try await pipeline.stop()
    }
}

// MARK: - Backward Compatibility Tests

@Suite(
    "LivePipeline — Transport Backward Compat",
    .timeLimit(.minutes(1))
)
struct LivePipelineTransportBackwardCompatTests {

    @Test("Pipeline without policy works unchanged")
    func backwardCompatNoPolicy() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(
            configuration: LivePipelineConfiguration()
        )
        await pipeline.processSegment(
            data: Data([0x00]),
            duration: 6.0,
            filename: "seg0.ts"
        )
        let count = await pipeline.segmentsProduced
        #expect(count == 1)
        let summary = try await pipeline.stop()
        #expect(summary.segmentsProduced == 1)
    }

    @Test("Policy but no transport dests — no crash")
    func policyButNoTransportDests() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        await pipeline.addDestination(
            OrchPlainPusher(), id: "plain-1"
        )
        #expect(
            await pipeline.transportHealthDashboard() == nil
        )
        _ = try await pipeline.stop()
    }

    @Test("Existing events work alongside transport events")
    func existingEventsWork() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let (collector, task) = orchCollect(from: pipeline)
        await pipeline.processSegment(
            data: Data([0x00]),
            duration: 6.0,
            filename: "seg0.ts"
        )
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        let segments = await collector.collected().filter {
            if case .segmentProduced = $0 { return true }
            return false
        }
        #expect(!segments.isEmpty)
        _ = try await pipeline.stop()
    }

    @Test("Pipeline start/stop lifecycle unchanged")
    func lifecycleUnchanged() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let state = await pipeline.state
        #expect(state == .running(since: Date()))
        let summary = try await pipeline.stop()
        #expect(summary.reason == .userRequested)
        let finalState = await pipeline.state
        #expect(finalState == .idle)
    }
}

// MARK: - ABR Responsiveness Tests

@Suite(
    "LivePipeline — ABR Responsiveness",
    .timeLimit(.minutes(1))
)
struct LivePipelineABRResponsivenessTests {

    @Test("Conservative requires 3 consecutive recommendations")
    func conservativeABR() async throws {
        let pipeline = LivePipeline()
        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .poor,
            abrResponsiveness: .conservative
        )
        try await pipeline.start(
            configuration: orchConfig(policy: policy)
        )
        let transport = OrchQualityTransport()
        let (collector, task) = orchCollect(from: pipeline)
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "dest-1"
        )
        try await Task.sleep(for: .milliseconds(50))
        for _ in 0..<3 {
            await transport.emitEvent(
                .bitrateRecommendation(
                    TransportBitrateRecommendation(
                        recommendedBitrate: 96_000,
                        currentEstimatedBitrate: 128_000,
                        direction: .decrease,
                        reason: "congestion",
                        confidence: 0.9, timestamp: Date()
                    )
                )
            )
        }
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let adjusted = await collector.collected().filter {
            if case .transportBitrateAdjusted = $0 { return true }
            return false
        }
        #expect(!adjusted.isEmpty)
        _ = try await pipeline.stop()
    }

    @Test("Responsive requires 2 consecutive recommendations")
    func responsiveABR() async throws {
        let pipeline = LivePipeline()
        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .poor,
            abrResponsiveness: .responsive
        )
        try await pipeline.start(
            configuration: orchConfig(policy: policy)
        )
        let transport = OrchQualityTransport()
        let (collector, task) = orchCollect(from: pipeline)
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "dest-1"
        )
        try await Task.sleep(for: .milliseconds(50))
        for _ in 0..<2 {
            await transport.emitEvent(
                .bitrateRecommendation(
                    TransportBitrateRecommendation(
                        recommendedBitrate: 96_000,
                        currentEstimatedBitrate: 128_000,
                        direction: .decrease,
                        reason: "congestion",
                        confidence: 0.9, timestamp: Date()
                    )
                )
            )
        }
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let adjusted = await collector.collected().filter {
            if case .transportBitrateAdjusted = $0 { return true }
            return false
        }
        #expect(!adjusted.isEmpty)
        _ = try await pipeline.stop()
    }
}
