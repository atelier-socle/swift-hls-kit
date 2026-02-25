// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("BlockingIntegration", .timeLimit(.minutes(1)))
struct BlockingIntegrationTests {

    // MARK: - Blocking Flow

    @Test("Request future segment → add partials → complete → resolves")
    func futureSegmentResolves() async throws {
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
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        await manager.completeSegment(
            duration: 1.0, uri: "seg0.m4s"
        )
        await handler.notify(segmentMSN: 0, partialIndex: nil)

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("seg0.m4s"))
    }

    @Test("Request future partial → add partials → resolves")
    func futurePartialResolves() async throws {
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

        for i in 0...2 {
            try await manager.addPartial(
                duration: 0.33, isIndependent: i == 0
            )
            await handler.notify(
                segmentMSN: 0, partialIndex: i
            )
        }

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
    }

    @Test("Concurrent 5 requests for different segments resolve")
    func concurrentRequests() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )

        var tasks = [Task<String, Error>]()
        for msn in 0..<5 {
            let req = BlockingPlaylistRequest(
                mediaSequenceNumber: msn
            )
            tasks.append(
                Task<String, Error> {
                    try await handler.awaitPlaylist(for: req)
                }
            )
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await handler.pendingRequestCount == 5)

        for s in 0..<5 {
            try await manager.addPartial(
                duration: 0.33, isIndependent: true
            )
            await manager.completeSegment(
                duration: 1.0, uri: "seg\(s).m4s"
            )
            await handler.notify(
                segmentMSN: s, partialIndex: nil
            )
        }

        for task in tasks {
            let playlist = try await task.value
            #expect(playlist.contains("#EXTM3U"))
        }
    }

    @Test("Timeout for far-future segment")
    func farFutureTimeout() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 0.2
        )

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 999
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

    @Test("Stream end with pending request")
    func streamEndWithPending() async throws {
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
            Issue.record("Expected streamAlreadyEnded")
        } catch let error as LLHLSError {
            #expect(error == .streamAlreadyEnded)
        }
    }

    // MARK: - Auto-notification via Manager

    @Test("Attach handler → auto-notification on addPartial")
    func autoNotifyOnPartial() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )
        await manager.attachBlockingHandler(handler)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0, partIndex: 0
        )
        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))

        // addPartial auto-notifies through manager.
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
    }

    @Test("Attach handler → auto-notification on completeSegment")
    func autoNotifyOnSegment() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )
        await manager.attachBlockingHandler(handler)

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
        await manager.completeSegment(
            duration: 1.0, uri: "seg0.m4s"
        )

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
    }

    @Test("Attach handler → auto-notification on endStream")
    func autoNotifyOnEnd() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )
        await manager.attachBlockingHandler(handler)

        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 99
        )
        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))
        await manager.endStream()

        do {
            _ = try await task.value
            Issue.record("Expected streamAlreadyEnded")
        } catch let error as LLHLSError {
            #expect(error == .streamAlreadyEnded)
        }
    }

    @Test("Full flow: attach → add partials → blocking → auto-resolves")
    func fullAutoFlow() async throws {
        let manager = LLHLSManager(configuration: .lowLatency)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )
        await manager.attachBlockingHandler(handler)

        // Request partial 1 of segment 0.
        let request = BlockingPlaylistRequest(
            mediaSequenceNumber: 0, partIndex: 1
        )
        let task = Task<String, Error> {
            try await handler.awaitPlaylist(for: request)
        }

        try await Task.sleep(for: .milliseconds(50))

        // Add partials — auto-notifies through manager.
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )

        let playlist = try await task.value
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-PART:"))
    }
}
