// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Shared Mocks (prefixed to avoid conflicts)

actor OrchPlainPusher: SegmentPusher {
    var connectionState: PushConnectionState = .connected
    var stats: PushStats = .zero

    func push(
        segment: LiveSegment, as filename: String
    ) async throws {}
    func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {}
    func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {}
    func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {}
    func connect() async throws {}
    func disconnect() async {}
}

actor OrchQualityTransport: QualityAwareTransport {
    let transportEvents: AsyncStream<TransportEvent>
    private let eventsContinuation:
        AsyncStream<TransportEvent>
            .Continuation
    private var _quality: TransportQuality?

    var connectionQuality: TransportQuality? { _quality }
    var statisticsSnapshot: TransportStatisticsSnapshot? { nil }

    init(
        quality: TransportQuality? = TransportQuality(
            score: 0.8, grade: .good,
            recommendation: nil, timestamp: Date()
        )
    ) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: TransportEvent.self
        )
        self.transportEvents = stream
        self.eventsContinuation = continuation
        self._quality = quality
    }

    func emitEvent(_ event: TransportEvent) {
        eventsContinuation.yield(event)
    }

    func finish() { eventsContinuation.finish() }
}

func orchConfig(
    policy: TransportAwarePipelinePolicy = .default
) -> LivePipelineConfiguration {
    var config = LivePipelineConfiguration()
    config.transportPolicy = policy
    return config
}

func orchPusher(
    transport: OrchQualityTransport
) -> TransportAwarePusher {
    TransportAwarePusher(
        pusher: OrchPlainPusher(),
        qualityTransport: transport
    )
}

actor OrchEventCollector {
    private var events: [LivePipelineEvent] = []

    func append(_ event: LivePipelineEvent) {
        events.append(event)
    }

    func collected() -> [LivePipelineEvent] { events }
}

func orchCollect(
    from pipeline: LivePipeline
) -> (OrchEventCollector, Task<Void, Never>) {
    let collector = OrchEventCollector()
    let task = Task {
        for await event in pipeline.events {
            if Task.isCancelled { break }
            await collector.append(event)
        }
    }
    return (collector, task)
}

// MARK: - Monitoring Tests

@Suite(
    "LivePipeline — Transport Monitoring",
    .timeLimit(.minutes(1))
)
struct LivePipelineTransportMonitoringTests {

    @Test("Pipeline with policy monitors TransportAwarePusher")
    func monitorsTransportAwarePusher() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let transport = OrchQualityTransport()
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "rtmp-1"
        )
        let dashboard = await pipeline.transportHealthDashboard()
        #expect(dashboard?.destinations.count == 1)
        _ = try await pipeline.stop()
    }

    @Test("Pipeline without policy does NOT monitor")
    func noMonitoringWithoutPolicy() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(
            configuration: LivePipelineConfiguration()
        )
        let transport = OrchQualityTransport()
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "rtmp-1"
        )
        let (collector, task) = orchCollect(from: pipeline)
        await transport.emitEvent(
            .qualityChanged(
                TransportQuality(
                    score: 0.2, grade: .critical,
                    recommendation: nil, timestamp: Date()
                )
            )
        )
        await transport.finish()
        try await Task.sleep(for: .milliseconds(200))
        task.cancel()
        let degraded = await collector.collected().filter {
            if case .transportQualityDegraded = $0 { return true }
            return false
        }
        #expect(degraded.isEmpty)
        _ = try await pipeline.stop()
    }

    @Test("Plain SegmentPusher — no monitoring, no crash")
    func plainPusherNoMonitoring() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        await pipeline.addDestination(
            OrchPlainPusher(), id: "http-1"
        )
        #expect(
            await pipeline.transportHealthDashboard() == nil
        )
        _ = try await pipeline.stop()
    }

    @Test("Removing destination stops monitoring")
    func removeStopsMonitoring() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let transport = OrchQualityTransport()
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "srt-1"
        )
        #expect(
            await pipeline.transportHealthDashboard() != nil
        )
        await pipeline.removeDestination(id: "srt-1")
        #expect(
            await pipeline.transportHealthDashboard() == nil
        )
        _ = try await pipeline.stop()
    }

    @Test("Pipeline stop cancels all monitoring")
    func stopCancelsMonitoring() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let transport = OrchQualityTransport()
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "dest-1"
        )
        _ = try await pipeline.stop()
        #expect(
            await pipeline.transportHealthDashboard() == nil
        )
    }

    @Test("Destination added before start is monitored")
    func destinationBeforeStart() async throws {
        let pipeline = LivePipeline()
        let transport = OrchQualityTransport()
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "dest-1"
        )
        try await pipeline.start(configuration: orchConfig())
        let (collector, task) = orchCollect(from: pipeline)
        try await Task.sleep(for: .milliseconds(50))
        await transport.emitEvent(
            .qualityChanged(
                TransportQuality(
                    score: 0.2, grade: .critical,
                    recommendation: nil, timestamp: Date()
                )
            )
        )
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let degraded = await collector.collected().filter {
            if case .transportQualityDegraded = $0 { return true }
            return false
        }
        #expect(!degraded.isEmpty)
        _ = try await pipeline.stop()
    }
}

// MARK: - Event Emission Tests

@Suite(
    "LivePipeline — Transport Event Emission",
    .timeLimit(.minutes(1))
)
struct LivePipelineTransportEventEmissionTests {

    @Test("qualityDegraded emitted below threshold")
    func qualityDegradedEmitted() async throws {
        let pipeline = LivePipeline()
        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: false,
            minimumQualityGrade: .good,
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
        await transport.emitEvent(
            .qualityChanged(
                TransportQuality(
                    score: 0.3, grade: .poor,
                    recommendation: nil, timestamp: Date()
                )
            )
        )
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let degraded = await collector.collected().filter {
            if case .transportQualityDegraded = $0 { return true }
            return false
        }
        #expect(!degraded.isEmpty)
        _ = try await pipeline.stop()
    }

    @Test("qualityDegraded NOT emitted above threshold")
    func qualityNotDegradedAboveThreshold() async throws {
        let pipeline = LivePipeline()
        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: false,
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
        await transport.emitEvent(
            .qualityChanged(
                TransportQuality(
                    score: 0.6, grade: .fair,
                    recommendation: nil, timestamp: Date()
                )
            )
        )
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let degraded = await collector.collected().filter {
            if case .transportQualityDegraded = $0 { return true }
            return false
        }
        #expect(degraded.isEmpty)
        _ = try await pipeline.stop()
    }

    @Test("destinationFailed emitted on disconnect")
    func destinationFailedOnDisconnect() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let transport = OrchQualityTransport()
        let (collector, task) = orchCollect(from: pipeline)
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "dest-1"
        )
        try await Task.sleep(for: .milliseconds(50))
        await transport.emitEvent(
            .disconnected(transportType: "RTMP", error: nil)
        )
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let failed = await collector.collected().filter {
            if case .transportDestinationFailed = $0 {
                return true
            }
            return false
        }
        #expect(!failed.isEmpty)
        if case let .transportDestinationFailed(dest, err) =
            failed.first
        {
            #expect(dest == "dest-1")
            #expect(err == "Connection lost")
        }
        _ = try await pipeline.stop()
    }

    @Test("bitrateAdjusted emitted at immediate threshold")
    func bitrateAdjustedImmediate() async throws {
        let pipeline = LivePipeline()
        let policy = TransportAwarePipelinePolicy(
            autoAdjustBitrate: true,
            minimumQualityGrade: .poor,
            abrResponsiveness: .immediate
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
        await transport.emitEvent(
            .bitrateRecommendation(
                TransportBitrateRecommendation(
                    recommendedBitrate: 96_000,
                    currentEstimatedBitrate: 128_000,
                    direction: .decrease, reason: "congestion",
                    confidence: 0.9, timestamp: Date()
                )
            )
        )
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let adjusted = await collector.collected().filter {
            if case .transportBitrateAdjusted = $0 { return true }
            return false
        }
        #expect(!adjusted.isEmpty)
        if case let .transportBitrateAdjusted(old, new, reason) =
            adjusted.first
        {
            #expect(old == 128_000)
            #expect(new == 96_000)
            #expect(reason == "congestion")
        }
        _ = try await pipeline.stop()
    }

    @Test("bitrateAdjusted NOT emitted below threshold")
    func bitrateNotAdjustedBelowThreshold() async throws {
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
        #expect(adjusted.isEmpty)
        _ = try await pipeline.stop()
    }

    @Test("ABR resets on direction change")
    func abrResetsOnDirectionChange() async throws {
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
        let dec = TransportBitrateRecommendation(
            recommendedBitrate: 96_000,
            currentEstimatedBitrate: 128_000,
            direction: .decrease, reason: "congestion",
            confidence: 0.9, timestamp: Date()
        )
        let inc = TransportBitrateRecommendation(
            recommendedBitrate: 192_000,
            currentEstimatedBitrate: 128_000,
            direction: .increase, reason: "bandwidth",
            confidence: 0.8, timestamp: Date()
        )
        await transport.emitEvent(.bitrateRecommendation(dec))
        await transport.emitEvent(.bitrateRecommendation(inc))
        await transport.emitEvent(.bitrateRecommendation(dec))
        await transport.finish()
        try await Task.sleep(for: .milliseconds(300))
        task.cancel()
        let adjusted = await collector.collected().filter {
            if case .transportBitrateAdjusted = $0 { return true }
            return false
        }
        #expect(adjusted.isEmpty)
        _ = try await pipeline.stop()
    }

    @Test("healthUpdate emitted with dashboard")
    func healthUpdateEmitted() async throws {
        let pipeline = LivePipeline()
        try await pipeline.start(configuration: orchConfig())
        let transport = OrchQualityTransport()
        let (collector, task) = orchCollect(from: pipeline)
        await pipeline.addDestination(
            orchPusher(transport: transport), id: "dest-1"
        )
        try await Task.sleep(for: .milliseconds(50))
        await transport.emitEvent(
            .qualityChanged(
                TransportQuality(
                    score: 0.2, grade: .critical,
                    recommendation: nil, timestamp: Date()
                )
            )
        )
        await transport.finish()
        try await Task.sleep(for: .milliseconds(500))
        task.cancel()
        let health = await collector.collected().filter {
            if case .transportHealthUpdate = $0 { return true }
            return false
        }
        #expect(!health.isEmpty)
        _ = try await pipeline.stop()
    }
}
