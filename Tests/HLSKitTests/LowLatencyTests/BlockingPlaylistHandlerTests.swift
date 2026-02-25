// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("BlockingPlaylistHandler", .timeLimit(.minutes(1)))
struct BlockingPlaylistHandlerTests {

    // MARK: - Helpers

    /// Creates a manager with some partials and completed segments.
    private func makeManagerWithSegments(
        count: Int = 1
    ) async throws -> LLHLSManager {
        let manager = LLHLSManager(configuration: .lowLatency)
        for i in 0..<count {
            try await manager.addPartial(
                duration: 0.33, isIndependent: true
            )
            try await manager.addPartial(
                duration: 0.33, isIndependent: false
            )
            await manager.completeSegment(
                duration: 1.0, uri: "seg\(i).m4s"
            )
        }
        return manager
    }

    // MARK: - Initialization

    @Test("Initialize with manager and timeout")
    func initWithTimeout() async {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 3.0
        )
        let timeout = await handler.timeout
        #expect(timeout == 3.0)
        let pending = await handler.pendingRequestCount
        #expect(pending == 0)
    }

    @Test("Default timeout is 6 seconds")
    func defaultTimeout() async {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(manager: manager)
        let timeout = await handler.timeout
        #expect(timeout == 6.0)
    }

    // MARK: - isRequestSatisfied

    @Test("isRequestSatisfied returns true when segment available")
    func satisfiedWhenAvailable() async throws {
        let manager = try await makeManagerWithSegments(count: 2)
        let handler = BlockingPlaylistHandler(manager: manager)
        await handler.notify(segmentMSN: 1, partialIndex: nil)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )
        let satisfied = await handler.isRequestSatisfied(request)
        #expect(satisfied)
    }

    @Test("isRequestSatisfied returns false when segment not available")
    func notSatisfiedWhenUnavailable() async {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(manager: manager)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 5
        )
        let satisfied = await handler.isRequestSatisfied(request)
        #expect(!satisfied)
    }

    @Test("isRequestSatisfied with partial — true when available")
    func satisfiedWithPartial() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(manager: manager)
        await handler.notify(segmentMSN: 0, partialIndex: 3)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0, partIndex: 2
        )
        let satisfied = await handler.isRequestSatisfied(request)
        #expect(satisfied)
    }

    @Test("isRequestSatisfied with partial — false when not available")
    func notSatisfiedWithPartial() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(manager: manager)
        await handler.notify(segmentMSN: 0, partialIndex: 1)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0, partIndex: 5
        )
        let satisfied = await handler.isRequestSatisfied(request)
        #expect(!satisfied)
    }

    @Test("isRequestSatisfied returns false before any notifications")
    func notSatisfiedBeforeNotify() async {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(manager: manager)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )
        let satisfied = await handler.isRequestSatisfied(request)
        #expect(!satisfied)
    }

    // MARK: - awaitPlaylist

    @Test("awaitPlaylist returns immediately when satisfied")
    func awaitImmediateReturn() async throws {
        let manager = try await makeManagerWithSegments(count: 2)
        let handler = BlockingPlaylistHandler(manager: manager)
        await handler.notify(segmentMSN: 1, partialIndex: nil)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )
        let playlist = try await handler.awaitPlaylist(for: request)
        #expect(playlist.contains("#EXTM3U"))
    }

    @Test("awaitPlaylist blocks then resolves on notify")
    func awaitBlocksThenResolves() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )

        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))
        let pending = await handler.pendingRequestCount
        #expect(pending == 1)

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await handler.notify(segmentMSN: 0, partialIndex: 0)

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
    }

    @Test("awaitPlaylist times out after configured timeout")
    func awaitTimeout() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 0.2
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 99
        )

        do {
            _ = try await handler.awaitPlaylist(for: request)
            Issue.record("Expected timeout error")
        } catch let error as LLHLSError {
            guard case .requestTimeout(let msn, _, let t) = error
            else {
                Issue.record("Wrong error case: \(error)")
                return
            }
            #expect(msn == 99)
            #expect(t == 0.2)
        }
    }

    @Test("awaitPlaylist throws streamEnded on notifyStreamEnded")
    func awaitStreamEnded() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 99
        )

        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))
        await handler.notifyStreamEnded()

        do {
            _ = try await task.value
            Issue.record("Expected streamAlreadyEnded error")
        } catch let error as LLHLSError {
            #expect(error == .streamAlreadyEnded)
        }
    }

    @Test("awaitPlaylist throws streamAlreadyEnded if stream ended")
    func awaitAfterStreamEnded() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )
        await handler.notifyStreamEnded()

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )
        do {
            _ = try await handler.awaitPlaylist(for: request)
            Issue.record("Expected streamAlreadyEnded")
        } catch let error as LLHLSError {
            #expect(error == .streamAlreadyEnded)
        }
    }
}
