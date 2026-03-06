// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - ABRTracker

/// Tracks consecutive ABR recommendations for a single destination.
///
/// Used internally by ``LivePipeline`` transport orchestration to
/// implement the ``TransportAwarePipelinePolicy/abrResponsiveness``
/// logic. Consecutive same-direction recommendations are counted
/// and compared against the policy threshold before emitting a
/// ``LivePipelineEvent/transportBitrateAdjusted(oldBitrate:newBitrate:reason:)``
/// event.
struct ABRTracker: Sendable {
    /// Number of consecutive same-direction recommendations.
    var consecutiveCount: Int = 0
    /// Direction of the last recommendation, if any.
    var lastDirection: TransportBitrateRecommendation.Direction?
    /// Last recommended bitrate value.
    var lastRecommendedBitrate: Int = 0
    /// Current effective bitrate (updated after threshold is met).
    var currentBitrate: Int = 0
}

// MARK: - LivePipeline + Transport Monitoring

extension LivePipeline {

    /// Computes the current transport health dashboard from all
    /// transport-aware destinations.
    ///
    /// Queries each monitored ``TransportAwarePusher`` for its
    /// current quality and connection state, then aggregates the
    /// results into a ``TransportHealthDashboard``.
    ///
    /// - Returns: The health dashboard, or `nil` if no
    ///   transport-aware destinations are configured.
    public func transportHealthDashboard()
        async -> TransportHealthDashboard?
    {
        guard !monitoredPushers.isEmpty else { return nil }

        var healths: [TransportDestinationHealth] = []
        for (id, pusher) in monitoredPushers {
            let quality = await pusher.transportQuality
            let connState = await pusher.connectionState
            let health = TransportDestinationHealth(
                label: id,
                transportType: "transport",
                quality: quality,
                connectionState: connState,
                statistics: nil
            )
            healths.append(health)
        }
        return TransportHealthDashboard(destinations: healths)
    }

    // MARK: - Internal Monitoring Lifecycle

    /// Starts transport monitoring for all registered pushers.
    func startAllTransportMonitoring() {
        for (id, pusher) in monitoredPushers {
            startTransportMonitoring(
                destination: id, pusher: pusher
            )
        }
    }

    /// Starts monitoring transport events for a single destination.
    ///
    /// Creates a detached task that iterates the pusher's
    /// ``TransportAwarePusher/transportEvents`` stream. The task
    /// runs on the global concurrent executor to avoid blocking
    /// the pipeline actor while awaiting stream elements.
    func startTransportMonitoring(
        destination id: String,
        pusher: TransportAwarePusher
    ) {
        guard transportMonitorTasks[id] == nil else { return }
        guard let policy = configuration?.transportPolicy else {
            return
        }

        let eventStream = pusher.transportEvents
        let task = Task { @concurrent [weak self] in
            for await event in eventStream {
                if Task.isCancelled { break }
                guard let self else { break }
                await self.handleTransportEvent(
                    event, destination: id, policy: policy
                )
            }
        }
        transportMonitorTasks[id] = task
    }

    /// Stops monitoring a single destination.
    func stopTransportMonitoring(destination id: String) {
        transportMonitorTasks[id]?.cancel()
        transportMonitorTasks.removeValue(forKey: id)
    }

    /// Cancels all transport monitoring tasks and resets state.
    func cancelAllTransportMonitoring() {
        for task in transportMonitorTasks.values {
            task.cancel()
        }
        transportMonitorTasks.removeAll()
        abrTrackers.removeAll()
        monitoredPushers.removeAll()
    }

    // MARK: - Event Handling

    /// Processes a transport event from a monitored destination.
    ///
    /// Applies the transport policy to determine which pipeline
    /// events to emit.
    func handleTransportEvent(
        _ event: TransportEvent,
        destination id: String,
        policy: TransportAwarePipelinePolicy
    ) {
        switch event {
        case .qualityChanged(let quality):
            if quality.grade < policy.minimumQualityGrade {
                continuation.yield(
                    .transportQualityDegraded(
                        destination: id, quality: quality
                    )
                )
            }
            scheduleHealthUpdate()

        case .disconnected(_, let error):
            continuation.yield(
                .transportDestinationFailed(
                    destination: id,
                    error: error?.localizedDescription
                        ?? "Connection lost"
                )
            )
            scheduleHealthUpdate()

        case .bitrateRecommendation(let recommendation):
            handleBitrateRecommendation(
                recommendation, destination: id, policy: policy
            )

        default:
            break
        }
    }

    /// Tracks consecutive ABR recommendations and emits
    /// ``LivePipelineEvent/transportBitrateAdjusted`` when the
    /// policy threshold is reached.
    private func handleBitrateRecommendation(
        _ recommendation: TransportBitrateRecommendation,
        destination id: String,
        policy: TransportAwarePipelinePolicy
    ) {
        var tracker = abrTrackers[id] ?? ABRTracker()

        if recommendation.direction == tracker.lastDirection {
            tracker.consecutiveCount += 1
        } else {
            tracker.consecutiveCount = 1
        }
        tracker.lastDirection = recommendation.direction

        let threshold: Int
        switch policy.abrResponsiveness {
        case .conservative: threshold = 3
        case .responsive: threshold = 2
        case .immediate: threshold = 1
        }

        if tracker.consecutiveCount >= threshold {
            let oldBitrate =
                tracker.currentBitrate > 0
                ? tracker.currentBitrate
                : recommendation.currentEstimatedBitrate
            continuation.yield(
                .transportBitrateAdjusted(
                    oldBitrate: oldBitrate,
                    newBitrate: recommendation.recommendedBitrate,
                    reason: recommendation.reason
                )
            )
            tracker.currentBitrate = recommendation.recommendedBitrate
            tracker.consecutiveCount = 0
        }

        tracker.lastRecommendedBitrate =
            recommendation.recommendedBitrate
        abrTrackers[id] = tracker
    }

    /// Asynchronously computes and emits a health dashboard update.
    private func scheduleHealthUpdate() {
        Task {
            guard
                let dashboard =
                    await self.transportHealthDashboard()
            else { return }
            self.continuation.yield(
                .transportHealthUpdate(dashboard)
            )
        }
    }
}
