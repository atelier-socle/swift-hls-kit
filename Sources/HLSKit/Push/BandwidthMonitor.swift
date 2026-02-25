// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Monitors real-time upload bandwidth and alerts when insufficient.
///
/// Tracks bytes pushed over time windows to estimate effective upload
/// bandwidth. Triggers quality reduction callbacks when bandwidth
/// drops below configured thresholds.
///
/// ```swift
/// let monitor = BandwidthMonitor(
///     configuration: .standard(requiredBitrate: 5_000_000)
/// )
/// monitor.onBandwidthAlert = { alert in
///     switch alert {
///     case .insufficient(let bps, _):
///         print("Low bandwidth: \(bps) bps")
///     case .recovered(let bps):
///         print("Recovered: \(bps) bps")
///     case .critical:
///         print("Critical bandwidth!")
///     }
/// }
/// await monitor.recordPush(bytes: 65536, duration: 0.1)
/// ```
public actor BandwidthMonitor {

    // MARK: - Types

    /// Bandwidth alert levels.
    public enum BandwidthAlert: Sendable, Equatable {

        /// Upload bandwidth is insufficient for the current bitrate.
        case insufficient(availableBps: Int, requiredBps: Int)

        /// Bandwidth has recovered above the required threshold.
        case recovered(availableBps: Int)

        /// Bandwidth is critically low (below critical threshold).
        case critical(availableBps: Int, requiredBps: Int)
    }

    /// Internal alert state for transition detection.
    enum AlertState: Sendable, Equatable {
        case normal
        case insufficient
        case critical
    }

    /// Configuration for bandwidth monitoring.
    public struct Configuration: Sendable, Equatable {

        /// Time window for bandwidth estimation (seconds).
        public var windowDuration: TimeInterval

        /// Required upload bitrate in bits per second.
        public var requiredBitrate: Int

        /// Ratio below which an alert is triggered (0.0-1.0).
        public var alertThreshold: Double

        /// Ratio below which a critical alert is triggered.
        public var criticalThreshold: Double

        /// Minimum samples before alerting.
        public var minimumSamples: Int

        /// Creates a bandwidth monitor configuration.
        ///
        /// - Parameters:
        ///   - windowDuration: Estimation window in seconds.
        ///   - requiredBitrate: Required bitrate in bps.
        ///   - alertThreshold: Alert ratio (default 0.9).
        ///   - criticalThreshold: Critical ratio (default 0.5).
        ///   - minimumSamples: Minimum samples (default 3).
        public init(
            windowDuration: TimeInterval,
            requiredBitrate: Int,
            alertThreshold: Double = 0.9,
            criticalThreshold: Double = 0.5,
            minimumSamples: Int = 3
        ) {
            self.windowDuration = windowDuration
            self.requiredBitrate = requiredBitrate
            self.alertThreshold = alertThreshold
            self.criticalThreshold = criticalThreshold
            self.minimumSamples = minimumSamples
        }

        /// Standard: 10s window, 90% alert, 50% critical, 3 min.
        ///
        /// - Parameter requiredBitrate: Required bitrate in bps.
        /// - Returns: A standard configuration.
        public static func standard(
            requiredBitrate: Int
        ) -> Configuration {
            Configuration(
                windowDuration: 10,
                requiredBitrate: requiredBitrate,
                alertThreshold: 0.9,
                criticalThreshold: 0.5,
                minimumSamples: 3
            )
        }

        /// Aggressive: 5s window, 95% alert, faster detection.
        ///
        /// - Parameter requiredBitrate: Required bitrate in bps.
        /// - Returns: An aggressive configuration.
        public static func aggressive(
            requiredBitrate: Int
        ) -> Configuration {
            Configuration(
                windowDuration: 5,
                requiredBitrate: requiredBitrate,
                alertThreshold: 0.95,
                criticalThreshold: 0.5,
                minimumSamples: 2
            )
        }

        /// Conservative: 30s window, 80% alert, fewer false alarms.
        ///
        /// - Parameter requiredBitrate: Required bitrate in bps.
        /// - Returns: A conservative configuration.
        public static func conservative(
            requiredBitrate: Int
        ) -> Configuration {
            Configuration(
                windowDuration: 30,
                requiredBitrate: requiredBitrate,
                alertThreshold: 0.8,
                criticalThreshold: 0.4,
                minimumSamples: 5
            )
        }
    }

    /// A single bandwidth sample.
    struct Sample: Sendable {
        let bytes: Int
        let duration: TimeInterval
        let timestamp: Date
    }

    // MARK: - Properties

    private let configuration: Configuration
    private var samples: [Sample] = []
    private var _totalBytesMonitored: Int = 0
    private var _sampleCount: Int = 0
    private var alertState: AlertState = .normal

    /// Called when bandwidth state changes.
    public var onBandwidthAlert: (@Sendable (BandwidthAlert) -> Void)?

    /// Creates a bandwidth monitor.
    ///
    /// - Parameter configuration: The monitoring configuration.
    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    // MARK: - Observable State

    /// Current estimated bandwidth in bits per second.
    public var estimatedBandwidthBps: Int {
        let now = Date()
        let windowSamples = samples.filter {
            now.timeIntervalSince($0.timestamp)
                <= configuration.windowDuration
        }
        guard !windowSamples.isEmpty else { return 0 }

        let totalBytes = windowSamples.reduce(0) { $0 + $1.bytes }
        let totalDuration = windowSamples.reduce(0.0) {
            $0 + $1.duration
        }
        guard totalDuration > 0 else { return 0 }

        return Int((Double(totalBytes) * 8.0) / totalDuration)
    }

    /// Whether bandwidth is currently sufficient.
    public var isSufficient: Bool {
        alertState == .normal
    }

    /// Current alert state (nil if no alert active).
    public var currentAlert: BandwidthAlert? {
        switch alertState {
        case .normal:
            return nil
        case .insufficient:
            return .insufficient(
                availableBps: estimatedBandwidthBps,
                requiredBps: configuration.requiredBitrate
            )
        case .critical:
            return .critical(
                availableBps: estimatedBandwidthBps,
                requiredBps: configuration.requiredBitrate
            )
        }
    }

    /// Total bytes monitored.
    public var totalBytesMonitored: Int {
        _totalBytesMonitored
    }

    /// Total samples recorded.
    public var sampleCount: Int {
        _sampleCount
    }

    // MARK: - Recording

    /// Record a push operation for bandwidth estimation.
    ///
    /// - Parameters:
    ///   - bytes: Number of bytes pushed.
    ///   - duration: Time taken for the push (seconds).
    public func recordPush(bytes: Int, duration: TimeInterval) {
        let safeDuration = max(duration, 0.001)
        let sample = Sample(
            bytes: bytes,
            duration: safeDuration,
            timestamp: Date()
        )
        samples.append(sample)
        _totalBytesMonitored += bytes
        _sampleCount += 1

        evictOldSamples()
        evaluateAlertState()
    }

    /// Reset all samples and state.
    public func reset() {
        samples.removeAll()
        _totalBytesMonitored = 0
        _sampleCount = 0
        alertState = .normal
    }

    // MARK: - Private

    private func evictOldSamples() {
        let now = Date()
        samples.removeAll {
            now.timeIntervalSince($0.timestamp)
                > configuration.windowDuration
        }
    }

    private func evaluateAlertState() {
        guard _sampleCount >= configuration.minimumSamples else {
            return
        }

        let bps = estimatedBandwidthBps
        let required = configuration.requiredBitrate
        guard required > 0 else { return }

        let ratio = Double(bps) / Double(required)
        let previousState = alertState

        if ratio < configuration.criticalThreshold {
            alertState = .critical
        } else if ratio < configuration.alertThreshold {
            alertState = .insufficient
        } else {
            alertState = .normal
        }

        // Fire callback only on transitions
        guard alertState != previousState else { return }

        switch alertState {
        case .critical:
            onBandwidthAlert?(
                .critical(availableBps: bps, requiredBps: required)
            )
        case .insufficient:
            onBandwidthAlert?(
                .insufficient(availableBps: bps, requiredBps: required)
            )
        case .normal where previousState != .normal:
            onBandwidthAlert?(.recovered(availableBps: bps))
        case .normal:
            break
        }
    }
}
