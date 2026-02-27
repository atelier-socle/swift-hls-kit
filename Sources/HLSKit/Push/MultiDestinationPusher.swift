// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Pushes segments to multiple destinations simultaneously.
///
/// Uses `TaskGroup` for parallel push. Errors from individual
/// destinations are isolated — one failure doesn't stop others.
/// Supports hot add/remove of destinations and configurable
/// failover policies.
///
/// ```swift
/// let multi = MultiDestinationPusher(
///     failoverPolicy: .continueOnFailure
/// )
/// await multi.add(httpPusher, id: "cdn-primary")
/// await multi.add(rtmpPusher, id: "twitch-backup")
/// try await multi.push(segment: liveSegment, as: "seg42.mp4")
/// ```
public actor MultiDestinationPusher: SegmentPusher {

    // MARK: - Types

    /// Policy for handling destination failures during fan-out push.
    public enum FailoverPolicy: Sendable, Equatable {

        /// Continue pushing to remaining destinations if one fails.
        /// Errors are collected but not thrown unless ALL fail.
        case continueOnFailure

        /// Fail immediately if the primary destination fails.
        /// Other destinations still receive the push attempt.
        case failOnPrimary(primaryId: String)

        /// Require ALL destinations to succeed. Throws on first
        /// failure.
        case requireAll
    }

    /// Result of a multi-destination push operation.
    public struct PushResult: Sendable {

        /// Per-destination outcomes (id to success/error).
        public let results: [String: Result<Void, PushError>]

        /// Number of successful pushes.
        public var successCount: Int {
            results.values.filter { if case .success = $0 { true } else { false } }.count
        }

        /// Number of failed pushes.
        public var failureCount: Int {
            results.values.filter { if case .failure = $0 { true } else { false } }.count
        }

        /// All destinations succeeded.
        public var allSucceeded: Bool {
            failureCount == 0
        }
    }

    // MARK: - Internal Storage

    /// Closures wrapping each destination pusher.
    private struct Destination: Sendable {
        let pushSegment: @Sendable (LiveSegment, String) async throws -> Void
        let pushPartial: @Sendable (LLPartialSegment, String) async throws -> Void
        let pushPlaylist: @Sendable (String, String) async throws -> Void
        let pushInit: @Sendable (Data, String) async throws -> Void
        let connect: @Sendable () async throws -> Void
        let disconnect: @Sendable () async -> Void
        let getState: @Sendable () async -> PushConnectionState
        let getStats: @Sendable () async -> PushStats
    }

    private var destinations: [String: Destination] = [:]
    private var _destinationStates: [String: PushConnectionState] = [:]

    /// Current failover policy.
    public let failoverPolicy: FailoverPolicy

    /// Creates a multi-destination pusher.
    ///
    /// - Parameter failoverPolicy: The failover policy to use.
    public init(failoverPolicy: FailoverPolicy = .continueOnFailure) {
        self.failoverPolicy = failoverPolicy
    }

    // MARK: - Destination Management

    /// Add a destination pusher.
    ///
    /// - Parameters:
    ///   - pusher: The segment pusher to add.
    ///   - id: A unique identifier for this destination.
    public func add<P: SegmentPusher>(_ pusher: P, id: String) {
        destinations[id] = Destination(
            pushSegment: { seg, name in
                try await pusher.push(segment: seg, as: name)
            },
            pushPartial: { partial, name in
                try await pusher.push(partial: partial, as: name)
            },
            pushPlaylist: { m3u8, name in
                try await pusher.pushPlaylist(m3u8, as: name)
            },
            pushInit: { data, name in
                try await pusher.pushInitSegment(data, as: name)
            },
            connect: { try await pusher.connect() },
            disconnect: { await pusher.disconnect() },
            getState: { await pusher.connectionState },
            getStats: { await pusher.stats }
        )
        _destinationStates[id] = .disconnected
    }

    /// Remove a destination (disconnects it first).
    ///
    /// - Parameter id: The destination identifier to remove.
    public func remove(id: String) async {
        if let dest = destinations[id] {
            await dest.disconnect()
        }
        destinations.removeValue(forKey: id)
        _destinationStates.removeValue(forKey: id)
    }

    /// List current destination IDs.
    public var destinationIds: [String] {
        Array(destinations.keys).sorted()
    }

    /// Number of active destinations.
    public var destinationCount: Int {
        destinations.count
    }

    /// Per-destination connection states.
    public var destinationStates: [String: PushConnectionState] {
        _destinationStates
    }

    // MARK: - SegmentPusher

    /// Connection state (connected if ANY destination is connected).
    public var connectionState: PushConnectionState {
        if _destinationStates.values.contains(.connected) {
            return .connected
        }
        if _destinationStates.values.contains(.connecting) {
            return .connecting
        }
        return .disconnected
    }

    /// Aggregated stats across all destinations.
    public var stats: PushStats {
        get async {
            var merged = PushStats.zero
            for dest in destinations.values {
                let s = await dest.getStats()
                merged.totalBytesPushed += s.totalBytesPushed
                merged.successCount += s.successCount
                merged.failureCount += s.failureCount
            }
            return merged
        }
    }

    /// Connect to the push destination.
    public func connect() async throws {
        try await connectAll()
    }

    /// Disconnect from the push destination.
    public func disconnect() async {
        await disconnectAll()
    }

    /// Push a completed live segment to all destinations.
    public func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        try await fanOut { dest in
            try await dest.pushSegment(segment, filename)
        }
    }

    /// Push a partial segment to all destinations.
    public func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        try await fanOut { dest in
            try await dest.pushPartial(partial, filename)
        }
    }

    /// Push a playlist to all destinations.
    public func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        try await fanOut { dest in
            try await dest.pushPlaylist(m3u8, filename)
        }
    }

    /// Push an init segment to all destinations.
    public func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        try await fanOut { dest in
            try await dest.pushInit(data, filename)
        }
    }

    // MARK: - Enhanced Push

    /// Push segment with detailed per-destination results.
    ///
    /// - Parameters:
    ///   - segment: The live segment to push.
    ///   - filename: The filename.
    /// - Returns: A ``PushResult`` with per-destination outcomes.
    public func pushWithResults(
        segment: LiveSegment, as filename: String
    ) async -> PushResult {
        let ids = Array(destinations.keys)
        let dests = destinations
        var results = [String: Result<Void, PushError>]()

        await withTaskGroup(of: (String, Result<Void, PushError>).self) { group in
            for id in ids {
                guard let dest = dests[id] else { continue }
                group.addTask {
                    do {
                        try await dest.pushSegment(segment, filename)
                        return (id, .success(()))
                    } catch let error as PushError {
                        return (id, .failure(error))
                    } catch {
                        return (
                            id,
                            .failure(
                                .connectionFailed(
                                    underlying: error.localizedDescription
                                )
                            )
                        )
                    }
                }
            }
            for await (id, result) in group {
                results[id] = result
            }
        }

        return PushResult(results: results)
    }

    // MARK: - Connection Management

    /// Connect all destinations in parallel.
    public func connectAll() async throws {
        let ids = Array(destinations.keys)
        let dests = destinations
        var errors = [String: Error]()

        await withTaskGroup(of: (String, Error?).self) { group in
            for id in ids {
                guard let dest = dests[id] else { continue }
                group.addTask {
                    do {
                        try await dest.connect()
                        return (id, nil)
                    } catch {
                        return (id, error)
                    }
                }
            }
            for await (id, error) in group {
                if let error {
                    errors[id] = error
                }
            }
        }

        // Update states after connect
        for id in ids {
            if let dest = destinations[id] {
                _destinationStates[id] = await dest.getState()
            }
        }

        if errors.count == ids.count, !ids.isEmpty {
            throw PushError.connectionFailed(
                underlying: "All destinations failed to connect"
            )
        }
    }

    /// Disconnect all destinations in parallel.
    public func disconnectAll() async {
        let ids = Array(destinations.keys)
        let dests = destinations

        await withTaskGroup(of: Void.self) { group in
            for id in ids {
                guard let dest = dests[id] else { continue }
                group.addTask {
                    await dest.disconnect()
                }
            }
        }

        for id in ids {
            _destinationStates[id] = .disconnected
        }
    }

    // MARK: - Private

    private func fanOut(
        _ operation: @Sendable @escaping (Destination) async throws -> Void
    ) async throws {
        guard !destinations.isEmpty else { return }

        let ids = Array(destinations.keys)
        let dests = destinations

        var errors = [String: PushError]()

        await withTaskGroup(of: (String, PushError?).self) { group in
            for id in ids {
                guard let dest = dests[id] else { continue }
                group.addTask {
                    do {
                        try await operation(dest)
                        return (id, nil)
                    } catch let error as PushError {
                        return (id, error)
                    } catch {
                        return (
                            id,
                            .connectionFailed(
                                underlying: error.localizedDescription
                            )
                        )
                    }
                }
            }
            for await (id, error) in group {
                if let error {
                    errors[id] = error
                }
            }
        }

        try applyFailoverPolicy(errors: errors, totalCount: ids.count)
    }

    private func applyFailoverPolicy(
        errors: [String: PushError], totalCount: Int
    ) throws {
        guard !errors.isEmpty else { return }

        switch failoverPolicy {
        case .continueOnFailure:
            if errors.count == totalCount {
                let first =
                    errors.values.first
                    ?? .connectionFailed(underlying: "All destinations failed")
                throw first
            }
        case .failOnPrimary(let primaryId):
            if let primaryError = errors[primaryId] {
                throw primaryError
            }
        case .requireAll:
            if let first = errors.values.first {
                throw first
            }
        }
    }
}
