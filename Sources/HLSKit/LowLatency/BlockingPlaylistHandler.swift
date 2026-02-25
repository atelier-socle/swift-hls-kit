// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Handles blocking playlist reload requests for Low-Latency HLS.
///
/// When a client sends `?_HLS_msn=47&_HLS_part=3`, the server must
/// block the HTTP response until that segment/partial is available.
///
/// Maintains a map of waiting requests. When
/// ``notify(segmentMSN:partialIndex:)`` is called, it resumes
/// waiters whose conditions are met.
public actor BlockingPlaylistHandler {

    /// Timeout for blocking requests in seconds.
    public let timeout: TimeInterval

    /// Reference to the LL-HLS manager for rendering playlists.
    private let manager: LLHLSManager

    /// Waiter entry with unique ID for timeout identification.
    private struct Waiter {
        let id: Int
        let request: BlockingPlaylistRequest
        let continuation: CheckedContinuation<String, Error>
    }

    /// Active waiters keyed by ID.
    private var waiters: [Int: Waiter] = [:]
    private var nextWaiterID: Int = 0

    /// Latest available segment MSN.
    private var latestSegmentMSN: Int = -1

    /// Latest available partial index.
    private var latestPartialIndex: Int?

    /// Whether the stream has ended.
    private var streamEnded = false

    /// Creates a blocking playlist handler.
    ///
    /// - Parameters:
    ///   - manager: The LL-HLS manager to render playlists from.
    ///   - timeout: Maximum wait time in seconds. Default `6.0`.
    public init(
        manager: LLHLSManager,
        timeout: TimeInterval = 6.0
    ) {
        self.manager = manager
        self.timeout = timeout
    }

    // MARK: - Public API

    /// Await a playlist that satisfies the given blocking request.
    ///
    /// Returns immediately if content is available, otherwise
    /// blocks until arrival, timeout, or stream end.
    ///
    /// - Parameter request: The blocking playlist request.
    /// - Returns: M3U8 playlist string (full or delta).
    /// - Throws: ``LLHLSError/requestTimeout`` or
    ///   ``LLHLSError/streamAlreadyEnded``.
    public func awaitPlaylist(
        for request: BlockingPlaylistRequest
    ) async throws -> String {
        if isRequestSatisfied(request) {
            return try await renderPlaylist(for: request)
        }
        if streamEnded {
            throw LLHLSError.streamAlreadyEnded
        }

        let waiterID = nextWaiterID
        nextWaiterID += 1
        let timeoutDuration = timeout

        return try await withCheckedThrowingContinuation { continuation in
            waiters[waiterID] = Waiter(
                id: waiterID,
                request: request,
                continuation: continuation
            )
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeoutDuration))
                await self?.handleTimeout(
                    waiterID: waiterID, request: request
                )
            }
        }
    }

    /// Notify that a new segment or partial is available.
    public func notify(
        segmentMSN: Int, partialIndex: Int?
    ) async {
        if segmentMSN > latestSegmentMSN {
            latestSegmentMSN = segmentMSN
        }
        latestPartialIndex = partialIndex

        var satisfiedIDs = [Int]()
        for (id, waiter) in waiters
        where isRequestSatisfied(waiter.request) {
            satisfiedIDs.append(id)
        }

        for id in satisfiedIDs {
            guard let waiter = waiters.removeValue(forKey: id)
            else { continue }
            do {
                let playlist = try await renderPlaylist(
                    for: waiter.request
                )
                waiter.continuation.resume(returning: playlist)
            } catch {
                waiter.continuation.resume(throwing: error)
            }
        }
    }

    /// Notify that the stream has ended.
    /// All pending waiters get a `streamAlreadyEnded` error.
    public func notifyStreamEnded() async {
        streamEnded = true
        let allWaiters = waiters
        waiters.removeAll()
        for (_, waiter) in allWaiters {
            waiter.continuation.resume(
                throwing: LLHLSError.streamAlreadyEnded
            )
        }
    }

    /// Number of currently pending requests.
    public var pendingRequestCount: Int {
        waiters.count
    }

    /// Check if a request is satisfied by current state.
    public func isRequestSatisfied(
        _ request: BlockingPlaylistRequest
    ) -> Bool {
        guard latestSegmentMSN >= 0 else { return false }
        if request.mediaSequenceNumber > latestSegmentMSN {
            return false
        }
        if request.mediaSequenceNumber == latestSegmentMSN,
            let requested = request.partIndex,
            let available = latestPartialIndex,
            requested > available
        {
            return false
        }
        return true
    }

    // MARK: - Private

    private func handleTimeout(
        waiterID: Int,
        request: BlockingPlaylistRequest
    ) {
        guard let waiter = waiters.removeValue(forKey: waiterID)
        else { return }
        waiter.continuation.resume(
            throwing: LLHLSError.requestTimeout(
                mediaSequence: request.mediaSequenceNumber,
                partIndex: request.partIndex,
                timeout: timeout
            ))
    }

    private func renderPlaylist(
        for request: BlockingPlaylistRequest
    ) async throws -> String {
        if let skip = request.skipRequest,
            let delta = await manager.renderDeltaPlaylist(
                skipRequest: skip
            )
        {
            return delta
        }
        return await manager.renderPlaylist()
    }
}
