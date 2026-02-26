// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - LivePipeline

/// Facade actor orchestrating the full live streaming pipeline.
///
/// Composes: encoding → segmentation → playlist generation → push delivery.
///
/// The pipeline manages its own state machine and emits events for
/// monitoring. All operations are thread-safe via actor isolation.
///
/// ## Basic usage (configuration only)
/// ```swift
/// let pipeline = LivePipeline()
/// try await pipeline.start(configuration: config)
/// await pipeline.processSegment(data: segData, duration: 6.0, filename: "seg0.m4s")
/// let summary = try await pipeline.stop()
/// ```
///
/// ## Component-wired usage
/// ```swift
/// let pipeline = LivePipeline()
/// let components = LivePipelineComponents(
///     input: .init(source: micSource),
///     encoding: .init(encoder: aacEncoder),
///     segmentation: .init(segmenter: audioSegmenter),
///     playlist: .init(manager: slidingWindow),
///     push: .init(destinations: [httpPusher])
/// )
/// try await pipeline.start(configuration: config, components: components)
/// ```
public actor LivePipeline {

    // MARK: - State

    /// Current pipeline state.
    public private(set) var state: LivePipelineState = .idle

    /// Event stream for monitoring pipeline activity.
    public nonisolated let events: AsyncStream<LivePipelineEvent>

    /// Number of segments produced so far.
    public private(set) var segmentsProduced: Int = 0

    /// Total bytes produced so far.
    public private(set) var totalBytes: Int64 = 0

    /// Current active destination identifiers.
    public private(set) var activeDestinations: [String] = []

    // MARK: - Internal (accessed by LivePipelineOrchestration extension)

    let continuation: AsyncStream<LivePipelineEvent>.Continuation
    var configuration: LivePipelineConfiguration?
    var components: LivePipelineComponents?

    // MARK: - Private

    private var startDate: Date?
    private var pendingDiscontinuity: Bool = false
    private var discontinuityCount: Int = 0
    private var totalSegmentDuration: TimeInterval = 0
    private var lastSegmentDuration: TimeInterval = 0
    private var lastSegmentBytes: Int = 0
    private var recordedSegmentCount: Int = 0

    // MARK: - Init

    /// Creates a new LivePipeline instance.
    public init() {
        let (stream, cont) = AsyncStream<LivePipelineEvent>.makeStream()
        self.events = stream
        self.continuation = cont
    }

    deinit {
        continuation.finish()
    }

    // MARK: - Lifecycle

    /// Starts the pipeline with the given configuration.
    ///
    /// Validates the configuration, transitions through `starting` to `running`,
    /// and emits state change events.
    ///
    /// - Parameter configuration: Pipeline configuration to use.
    /// - Throws: ``LivePipelineError/invalidConfiguration(_:)`` if validation fails.
    /// - Throws: ``LivePipelineError/alreadyRunning`` if the pipeline is not idle.
    public func start(configuration: LivePipelineConfiguration) throws {
        guard state == .idle else {
            throw LivePipelineError.alreadyRunning
        }

        if let error = configuration.validate() {
            throw LivePipelineError.invalidConfiguration(error)
        }

        performStart(configuration: configuration)
    }

    /// Starts the pipeline with configuration and pre-built components.
    ///
    /// Validates configuration, checks component compatibility, then starts.
    /// Emits ``LivePipelineEvent/componentWarning(_:)`` for mismatches.
    ///
    /// - Parameters:
    ///   - configuration: Pipeline configuration to use.
    ///   - components: Pre-built component groups for DI.
    /// - Throws: ``LivePipelineError/invalidConfiguration(_:)`` if validation fails.
    /// - Throws: ``LivePipelineError/alreadyRunning`` if the pipeline is not idle.
    public func start(
        configuration: LivePipelineConfiguration,
        components: LivePipelineComponents
    ) throws {
        guard state == .idle else {
            throw LivePipelineError.alreadyRunning
        }

        if let error = configuration.validate() {
            throw LivePipelineError.invalidConfiguration(error)
        }

        self.components = components
        validateComponentCompatibility(
            configuration: configuration,
            components: components
        )
        performStart(configuration: configuration)
    }

    /// Stops the pipeline gracefully.
    ///
    /// Transitions through `stopping` to `stopped`, builds a summary
    /// of the streaming session, and emits state change events.
    ///
    /// - Returns: A summary of the completed streaming session.
    /// - Throws: ``LivePipelineError/notRunning`` if the pipeline is not running.
    @discardableResult
    public func stop() throws -> LivePipelineSummary {
        guard case .running = state else {
            throw LivePipelineError.notRunning
        }

        transitionTo(.stopping)

        let now = Date()
        let start = startDate ?? now
        let summary = LivePipelineSummary(
            duration: now.timeIntervalSince(start),
            segmentsProduced: segmentsProduced,
            totalBytes: totalBytes,
            startDate: start,
            stopDate: now,
            reason: .userRequested
        )

        transitionTo(.stopped(summary: summary))

        // Reset to allow reuse
        self.configuration = nil
        self.components = nil
        self.startDate = nil
        self.state = .idle

        return summary
    }

    // MARK: - Runtime Operations

    /// Processes a segment, updating internal counters and emitting events.
    ///
    /// If the pipeline is not running, this is a no-op.
    ///
    /// - Parameters:
    ///   - data: The segment data.
    ///   - duration: Segment duration in seconds.
    ///   - filename: Segment filename for recording events.
    public func processSegment(
        data: Data, duration: TimeInterval, filename: String
    ) async {
        guard case .running = state else { return }

        let index = segmentsProduced
        segmentsProduced += 1
        totalBytes += Int64(data.count)
        totalSegmentDuration += duration
        lastSegmentDuration = duration
        lastSegmentBytes = data.count

        if pendingDiscontinuity {
            continuation.yield(.discontinuityInserted)
            pendingDiscontinuity = false
        }

        continuation.yield(
            .segmentProduced(index: index, duration: duration, byteSize: data.count)
        )

        if configuration?.enableRecording == true {
            recordedSegmentCount += 1
            continuation.yield(.recordingSegmentSaved(filename: filename))
        }
    }

    /// Marks a discontinuity to be inserted before the next segment.
    public func insertDiscontinuity() {
        guard case .running = state else { return }
        pendingDiscontinuity = true
        discontinuityCount += 1
        continuation.yield(.discontinuityInserted)
    }

    /// Adds a push destination at runtime.
    ///
    /// - Parameters:
    ///   - destination: The destination configuration.
    ///   - id: A unique identifier for this destination.
    public func addDestination(_ destination: PushDestinationConfig, id: String) {
        if !activeDestinations.contains(id) {
            activeDestinations.append(id)
        }
    }

    /// Removes a push destination at runtime.
    ///
    /// If the ID is not found, this is a no-op.
    ///
    /// - Parameter id: The identifier of the destination to remove.
    public func removeDestination(id: String) {
        activeDestinations.removeAll { $0 == id }
    }

    // MARK: - Info

    /// Pipeline uptime in seconds. Returns 0 if not running.
    public var uptime: TimeInterval {
        guard case .running = state, let start = startDate else {
            return 0
        }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Statistics

    /// Current pipeline statistics snapshot.
    ///
    /// Computed from internal state on each access.
    public var statistics: LivePipelineStatistics {
        var stats = LivePipelineStatistics()
        stats.uptime = uptime
        stats.startDate = startDate
        stats.segmentsProduced = segmentsProduced
        stats.totalBytes = totalBytes
        stats.lastSegmentDuration = lastSegmentDuration
        stats.lastSegmentBytes = lastSegmentBytes
        stats.activeDestinations = activeDestinations.count
        stats.discontinuities = discontinuityCount
        stats.recordingActive = configuration?.enableRecording ?? false
        stats.recordedSegments = recordedSegmentCount
        if segmentsProduced > 0 {
            stats.averageSegmentDuration =
                totalSegmentDuration / Double(segmentsProduced)
        }
        if uptime > 0 {
            stats.estimatedBitrate = Int(Double(totalBytes * 8) / uptime)
        }
        return stats
    }

    // MARK: - Private

    private func performStart(configuration: LivePipelineConfiguration) {
        transitionTo(.starting)
        self.configuration = configuration
        self.segmentsProduced = 0
        self.totalBytes = 0
        self.pendingDiscontinuity = false
        self.discontinuityCount = 0
        self.totalSegmentDuration = 0
        self.lastSegmentDuration = 0
        self.lastSegmentBytes = 0
        self.recordedSegmentCount = 0

        let now = Date()
        self.startDate = now
        transitionTo(.running(since: now))
    }

    private func validateComponentCompatibility(
        configuration: LivePipelineConfiguration,
        components: LivePipelineComponents
    ) {
        if configuration.enableRecording && components.recording == nil {
            continuation.yield(
                .componentWarning(
                    "Recording enabled but no RecordingComponents provided"
                )
            )
        }
        if configuration.lowLatency != nil && components.lowLatency == nil {
            continuation.yield(
                .componentWarning(
                    "Low-latency enabled but no LowLatencyComponents provided"
                )
            )
        }
        if !configuration.destinations.isEmpty && components.push == nil {
            continuation.yield(
                .componentWarning(
                    "Push destinations configured but no PushComponents provided"
                )
            )
        }
    }

    private func transitionTo(_ newState: LivePipelineState) {
        state = newState
        continuation.yield(.stateChanged(newState))
    }
}
