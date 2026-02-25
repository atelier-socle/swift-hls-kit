// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("BlockingHandlerBehavior", .timeLimit(.minutes(1)))
struct BlockingHandlerBehaviorTests {

    // MARK: - Helpers

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

    // MARK: - notify

    @Test("notify resolves waiting MSN-only requests")
    func notifyResolvesMSN() async throws {
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

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await handler.notify(segmentMSN: 0, partialIndex: 0)

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
        let pending = await handler.pendingRequestCount
        #expect(pending == 0)
    }

    @Test("notify does not resolve requests for future segments")
    func notifyDoesNotResolveFuture() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 0.3
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 5
        )
        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))
        await handler.notify(segmentMSN: 2, partialIndex: nil)

        let pending = await handler.pendingRequestCount
        #expect(pending == 1)

        do {
            _ = try await task.value
            Issue.record("Expected timeout")
        } catch {
            // Expected timeout.
        }
    }

    @Test("Multiple concurrent waiters for same segment")
    func multipleSameSegment() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )

        let task1 = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }
        let task2 = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }
        let task3 = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))
        let pending = await handler.pendingRequestCount
        #expect(pending == 3)

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await handler.notify(segmentMSN: 0, partialIndex: 0)

        let p1 = try await task1.value
        let p2 = try await task2.value
        let p3 = try await task3.value
        #expect(p1.contains("#EXTM3U"))
        #expect(p2.contains("#EXTM3U"))
        #expect(p3.contains("#EXTM3U"))
    }

    @Test("Multiple waiters for different segments")
    func multipleDifferentSegments() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        let req0 = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )
        let req1 = BlockingPlaylistRequest(
            mediaSequenceNumber: 1
        )

        let task0 = Task<String, Error> {
            try await handler.awaitPlaylist(for: req0)
        }
        let task1 = Task<String, Error> {
            try await handler.awaitPlaylist(for: req1)
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await handler.pendingRequestCount == 2)

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await handler.notify(segmentMSN: 0, partialIndex: 0)

        let p0 = try await task0.value
        #expect(p0.contains("#EXTM3U"))

        #expect(await handler.pendingRequestCount == 1)

        await manager.completeSegment(
            duration: 1.0, uri: "seg0.m4s"
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await handler.notify(segmentMSN: 1, partialIndex: 0)

        let p1 = try await task1.value
        #expect(p1.contains("#EXTM3U"))
    }

    // MARK: - pendingRequestCount

    @Test("pendingRequestCount tracks waiters")
    func pendingCount() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        #expect(await handler.pendingRequestCount == 0)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )
        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await handler.pendingRequestCount == 1)

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await handler.notify(segmentMSN: 0, partialIndex: 0)

        _ = try await task.value
        #expect(await handler.pendingRequestCount == 0)
    }

    @Test("pendingRequestCount drops to 0 after streamEnded")
    func pendingCountAfterStreamEnd() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        let task1 = Task<String, Error> {
            try await handler.awaitPlaylist(
                for: BlockingPlaylistRequest(
                    mediaSequenceNumber: 10
                )
            )
        }
        let task2 = Task<String, Error> {
            try await handler.awaitPlaylist(
                for: BlockingPlaylistRequest(
                    mediaSequenceNumber: 20
                )
            )
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await handler.pendingRequestCount == 2)

        await handler.notifyStreamEnded()
        #expect(await handler.pendingRequestCount == 0)

        do {
            _ = try await task1.value
            Issue.record("Expected error")
        } catch {}
        do {
            _ = try await task2.value
            Issue.record("Expected error")
        } catch {}
    }

    @Test("Pending count decreases after timeout")
    func pendingDecreasesOnTimeout() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 0.15
        )

        let task = Task<String, Error> {
            try await handler.awaitPlaylist(
                for: BlockingPlaylistRequest(
                    mediaSequenceNumber: 99
                )
            )
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await handler.pendingRequestCount == 1)

        try await Task.sleep(for: .milliseconds(200))
        #expect(await handler.pendingRequestCount == 0)

        do {
            _ = try await task.value
        } catch {}
    }

    // MARK: - Delta / Full playlist

    @Test("Full playlist returned when no skipRequest")
    func fullPlaylist() async throws {
        let manager = try await makeManagerWithSegments(count: 1)
        let handler = BlockingPlaylistHandler(manager: manager)
        await handler.notify(segmentMSN: 0, partialIndex: nil)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0
        )
        let playlist = try await handler.awaitPlaylist(
            for: request
        )
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-TARGETDURATION"))
    }

    // MARK: - Timeout configurability

    @Test("Very short timeout works correctly")
    func veryShortTimeout() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 0.1
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 99
        )

        do {
            _ = try await handler.awaitPlaylist(for: request)
            Issue.record("Expected timeout")
        } catch let error as LLHLSError {
            guard case .requestTimeout = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
    }

    // MARK: - No-op / Edge cases

    @Test("notify with no pending requests is no-op")
    func notifyNoPending() async {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(manager: manager)

        await handler.notify(segmentMSN: 0, partialIndex: 0)
        #expect(await handler.pendingRequestCount == 0)
    }

    @Test("Rapid sequential notifications work correctly")
    func rapidNotifications() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0, partIndex: 2
        )
        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))

        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        await handler.notify(segmentMSN: 0, partialIndex: 0)
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        await handler.notify(segmentMSN: 0, partialIndex: 1)
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        await handler.notify(segmentMSN: 0, partialIndex: 2)

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
    }
}
