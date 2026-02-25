// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Phase11Showcase", .timeLimit(.minutes(1)))
struct Phase11ShowcaseTests {

    // MARK: - Showcase: Ultra-low-latency esports

    @Test("Ultra-low-latency esports stream")
    func esportsStream() async throws {
        let config = LLHLSConfiguration.ultraLowLatency
        let manager = LLHLSManager(configuration: config)
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 3.0
        )
        await manager.attachBlockingHandler(handler)

        // Build 10 segments × 5 partials (0.2s each).
        for s in 0..<10 {
            for p in 0..<5 {
                try await manager.addPartial(
                    duration: 0.2, isIndependent: p == 0
                )
            }
            await manager.completeSegment(
                duration: 1.0, uri: "esports\(s).m4s"
            )
        }

        let playlist = await manager.renderPlaylist()
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(playlist.contains("esports9.m4s"))

        // Delta should skip older segments.
        let delta = await manager.renderDeltaPlaylist()
        if let delta {
            #expect(delta.contains("EXT-X-SKIP"))
        }
    }

    // MARK: - Showcase: Live concert

    @Test("Live concert with server control")
    func liveConcert() async throws {
        let config = LLHLSConfiguration.balanced
        let manager = LLHLSManager(configuration: config)

        for s in 0..<6 {
            for p in 0..<3 {
                try await manager.addPartial(
                    duration: 0.5, isIndependent: p == 0
                )
            }
            await manager.completeSegment(
                duration: 2.0, uri: "concert\(s).m4s"
            )
        }

        let playlist = await manager.renderPlaylist()
        #expect(playlist.contains("#EXT-X-SERVER-CONTROL:"))
        #expect(playlist.contains("concert5.m4s"))
    }

    // MARK: - Showcase: Multi-viewer sports

    @Test("Sports multi-viewer concurrent blocking")
    func sportsMultiViewer() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )
        await manager.attachBlockingHandler(handler)

        // 3 concurrent viewers request segment 0.
        var viewers = [Task<String, Error>]()
        for _ in 0..<3 {
            viewers.append(
                Task<String, Error> {
                    try await handler.awaitPlaylist(
                        for: BlockingPlaylistRequest(
                            mediaSequenceNumber: 0
                        )
                    )
                }
            )
        }

        try await Task.sleep(for: .milliseconds(50))
        #expect(await handler.pendingRequestCount == 3)

        // Produce the segment.
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        await manager.completeSegment(
            duration: 1.0, uri: "sports0.m4s"
        )

        // All viewers get resolved.
        for viewer in viewers {
            let playlist = try await viewer.value
            #expect(playlist.contains("#EXTM3U"))
            #expect(playlist.contains("#EXT-X-PART:"))
        }
    }

    // MARK: - Showcase: Stream end

    @Test("Stream end with pending requests")
    func streamEndPending() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        let handler = BlockingPlaylistHandler(
            manager: manager, timeout: 5.0
        )
        await manager.attachBlockingHandler(handler)

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
        await manager.endStream()

        for task in [task1, task2] {
            do {
                _ = try await task.value
                Issue.record("Expected streamAlreadyEnded")
            } catch let error as LLHLSError {
                #expect(error == .streamAlreadyEnded)
            }
        }
    }

    // MARK: - Showcase: Round-trip

    @Test("LL-HLS render → parse → validate round-trip")
    func roundTrip() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )
        for s in 0..<3 {
            for p in 0..<3 {
                try await manager.addPartial(
                    duration: 0.33, isIndependent: p == 0
                )
            }
            await manager.completeSegment(
                duration: 1.0, uri: "rt\(s).m4s"
            )
        }

        let playlist = await manager.renderPlaylist()
        let parser = ManifestParser()
        let result = try parser.parse(playlist)

        guard case .media(let media) = result else {
            Issue.record("Expected media playlist")
            return
        }
        #expect(media.version == .v7)
        #expect(media.targetDuration == 1)
        #expect(!media.segments.isEmpty)
    }

    // MARK: - Showcase: Podcast live recording

    @Test("Podcast live recording with LL-HLS")
    func podcastLive() async throws {
        let config = LLHLSConfiguration.lowLatency
        let manager = LLHLSManager(configuration: config)

        for s in 0..<4 {
            for p in 0..<2 {
                try await manager.addPartial(
                    duration: 0.5, isIndependent: p == 0
                )
            }
            await manager.completeSegment(
                duration: 2.0, uri: "podcast\(s).m4s"
            )
        }

        let playlist = await manager.renderPlaylist()
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("podcast3.m4s"))
    }

    // MARK: - Showcase: Gaming stream

    @Test("Gaming stream with every partial independent")
    func gamingStream() async throws {
        let manager = LLHLSManager(
            configuration: .ultraLowLatency
        )

        for s in 0..<3 {
            for _ in 0..<4 {
                try await manager.addPartial(
                    duration: 0.25,
                    isIndependent: true
                )
            }
            await manager.completeSegment(
                duration: 1.0, uri: "game\(s).m4s"
            )
        }

        let playlist = await manager.renderPlaylist()
        // All partials should have INDEPENDENT=YES.
        let independentCount =
            playlist.components(
                separatedBy: "INDEPENDENT=YES"
            ).count - 1
        #expect(independentCount > 0)
    }

    // MARK: - Showcase: Conference call

    @Test("Conference call with short segments")
    func conferenceCall() async throws {
        let manager = LLHLSManager(
            configuration: .ultraLowLatency
        )

        for s in 0..<5 {
            for p in 0..<3 {
                try await manager.addPartial(
                    duration: 0.33, isIndependent: p == 0
                )
            }
            await manager.completeSegment(
                duration: 1.0, uri: "conf\(s).m4s"
            )
        }

        let playlist = await manager.renderPlaylist()
        #expect(playlist.contains("#EXTM3U"))
        #expect(playlist.contains("#EXT-X-PART:"))
        #expect(playlist.contains("conf4.m4s"))
    }

    // MARK: - Showcase: Maximum scale

    @Test("Maximum scale: 100 segments, 5 partials each")
    func maximumScale() async throws {
        let manager = LLHLSManager(
            configuration: .lowLatency
        )

        for s in 0..<100 {
            for p in 0..<5 {
                try await manager.addPartial(
                    duration: 0.2, isIndependent: p == 0
                )
            }
            await manager.completeSegment(
                duration: 1.0, uri: "scale\(s).m4s"
            )
        }

        let full = await manager.renderPlaylist()
        #expect(full.contains("#EXTM3U"))
        #expect(full.contains("scale99.m4s"))

        let delta = await manager.renderDeltaPlaylist()
        if let delta {
            #expect(delta.count < full.count)
        }
    }
}
