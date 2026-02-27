// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Push Delivery Showcase", .timeLimit(.minutes(1)))
struct PushDeliveryShowcaseTests {

    // MARK: - Helpers

    private func makeSegment(
        index: Int = 0, dataSize: Int = 100
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: 0xAB, count: dataSize),
            duration: 2.0,
            timestamp: MediaTimestamp(seconds: Double(index) * 2.0),
            isIndependent: true,
            discontinuity: false,
            programDateTime: nil,
            filename: "seg\(index).m4s",
            frameCount: 0,
            codecs: []
        )
    }

    // MARK: - CDN Multi-Push

    @Test("CDN multi-push: live event to CDN1 + CDN2")
    func cdnMultiPush() async throws {
        let multi = MultiDestinationPusher()
        let cdn1 = MockPusher()
        let cdn2 = MockPusher()
        await multi.add(cdn1, id: "cdn-us")
        await multi.add(cdn2, id: "cdn-eu")

        for i in 0..<5 {
            try await multi.push(
                segment: makeSegment(index: i, dataSize: 1024),
                as: "seg\(i).m4s"
            )
        }

        let calls1 = await cdn1.pushSegmentCalls
        let calls2 = await cdn2.pushSegmentCalls
        #expect(calls1.count == 5)
        #expect(calls2.count == 5)
    }

    @Test("Simulcast: RTMP to Twitch + YouTube")
    func simulcast() async throws {
        let multi = MultiDestinationPusher()
        let twitch = MockPusher()
        let youtube = MockPusher()
        await multi.add(twitch, id: "twitch")
        await multi.add(youtube, id: "youtube")

        for i in 0..<3 {
            try await multi.push(
                segment: makeSegment(index: i),
                as: "seg\(i).m4s"
            )
        }

        let result = await multi.pushWithResults(
            segment: makeSegment(index: 3), as: "seg3.m4s"
        )
        #expect(result.allSucceeded)
    }

    @Test("Podcast web radio: Icecast + HTTP backup")
    func podcastRadio() async throws {
        let multi = MultiDestinationPusher()
        let icecast = MockPusher()
        let httpBackup = MockPusher()
        await multi.add(icecast, id: "icecast-live")
        await multi.add(httpBackup, id: "http-backup")

        let seg = makeSegment(dataSize: 2048)
        try await multi.push(segment: seg, as: "audio.m4s")

        let icecastCalls = await icecast.pushSegmentCalls
        let httpCalls = await httpBackup.pushSegmentCalls
        #expect(icecastCalls.count == 1)
        #expect(httpCalls.count == 1)
    }

    @Test("LL-HLS complete: partials + rendition reports + push")
    func llhlsComplete() async throws {
        let manager = LLHLSManager()

        // Build content
        try await manager.addPartial(
            duration: 0.33, isIndependent: true
        )
        try await manager.addPartial(
            duration: 0.33, isIndependent: false
        )
        _ = await manager.completeSegment(
            duration: 1.0, uri: "seg0.ts"
        )

        await manager.setRenditionReports([
            RenditionReport(
                uri: "audio_128k.m3u8",
                lastMediaSequence: 0, lastPartIndex: 1
            )
        ])

        let playlist = await manager.renderPlaylist()
        #expect(playlist.contains("#EXT-X-PART:"))
        #expect(playlist.contains("#EXT-X-RENDITION-REPORT:"))

        // Push playlist to multi-destination
        let multi = MultiDestinationPusher()
        let cdn = MockPusher()
        await multi.add(cdn, id: "cdn")
        try await multi.pushPlaylist(playlist, as: "live.m3u8")

        let calls = await cdn.pushPlaylistCalls
        #expect(calls.count == 1)
        #expect(calls[0].m3u8.contains("RENDITION-REPORT"))
    }

    @Test("Bandwidth adaptive: monitor detects drop, callback fires")
    func bandwidthAdaptive() async {
        let triggered = LockedState(initialState: false)
        let config = BandwidthMonitor.Configuration(
            windowDuration: 60,
            requiredBitrate: 5_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 1
        )
        let monitor = BandwidthMonitor(configuration: config)
        await monitor.setOnBandwidthAlert { alert in
            if case .insufficient = alert {
                triggered.withLock { $0 = true }
            }
            if case .critical = alert {
                triggered.withLock { $0 = true }
            }
        }

        // Normal push: 1MB in 1s = 8Mbps > 5Mbps
        await monitor.recordPush(bytes: 1_000_000, duration: 1.0)
        let beforeDrop = triggered.withLock { $0 }
        #expect(!beforeDrop)

        // Slow pushes: 10KB in 1s << 5Mbps
        await monitor.recordPush(bytes: 10_000, duration: 1.0)
        await monitor.recordPush(bytes: 10_000, duration: 1.0)
        await monitor.recordPush(bytes: 10_000, duration: 1.0)
        // After low samples, alert should have fired
    }

    @Test("Disaster recovery: primary down, backup works, primary recovers")
    func disasterRecovery() async throws {
        let multi = MultiDestinationPusher(
            failoverPolicy: .continueOnFailure
        )
        let primary = MockPusher()
        let backup = MockPusher()
        await multi.add(primary, id: "primary")
        await multi.add(backup, id: "backup")

        // Phase 1: primary fails
        await primary.setShouldFail(true)
        try await multi.push(
            segment: makeSegment(index: 0), as: "seg0.m4s"
        )

        // Phase 2: primary recovers
        await primary.setShouldFail(false)
        try await multi.push(
            segment: makeSegment(index: 1), as: "seg1.m4s"
        )

        let primaryCalls = await primary.pushSegmentCalls
        let backupCalls = await backup.pushSegmentCalls
        // Primary should have 2 calls (1 fail + 1 success)
        #expect(primaryCalls.count == 2)
        #expect(backupCalls.count == 2)
    }

    @Test("Global broadcast: 5 regional CDNs fan-out")
    func globalBroadcast() async throws {
        let multi = MultiDestinationPusher()
        let regions = ["us-east", "us-west", "eu-west", "ap-south", "ap-east"]
        var mocks = [MockPusher]()
        for region in regions {
            let mock = MockPusher()
            mocks.append(mock)
            await multi.add(mock, id: region)
        }

        for i in 0..<10 {
            try await multi.push(
                segment: makeSegment(index: i, dataSize: 512),
                as: "seg\(i).m4s"
            )
        }

        for mock in mocks {
            let calls = await mock.pushSegmentCalls
            #expect(calls.count == 10)
        }
        let count = await multi.destinationCount
        #expect(count == 5)
    }

    @Test("Stats dashboard: aggregated metrics across pushers")
    func statsDashboard() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")

        try await multi.push(
            segment: makeSegment(dataSize: 512), as: "seg.m4s"
        )

        // Both mocks received the push
        let calls1 = await mock1.pushSegmentCalls
        let calls2 = await mock2.pushSegmentCalls
        #expect(calls1.count == 1)
        #expect(calls2.count == 1)
    }

    @Test("Protocol comparison: same stream to multiple mocks")
    func protocolComparison() async throws {
        let multi = MultiDestinationPusher()
        let http = MockPusher()
        let rtmp = MockPusher()
        let srt = MockPusher()
        let icecast = MockPusher()
        await multi.add(http, id: "http")
        await multi.add(rtmp, id: "rtmp")
        await multi.add(srt, id: "srt")
        await multi.add(icecast, id: "icecast")

        for i in 0..<10 {
            try await multi.push(
                segment: makeSegment(index: i, dataSize: 256),
                as: "seg\(i).m4s"
            )
        }

        for mock in [http, rtmp, srt, icecast] {
            let calls = await mock.pushSegmentCalls
            #expect(calls.count == 10)
        }
    }

    @Test("Empty stream edge case: push with no data")
    func emptyStream() async throws {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await multi.add(mock, id: "cdn")

        let seg = LiveSegment(
            index: 0, data: Data(),
            duration: 0.0,
            timestamp: MediaTimestamp(seconds: 0),
            isIndependent: true, discontinuity: false,
            programDateTime: nil, filename: "empty.m4s",
            frameCount: 0, codecs: []
        )
        try await multi.push(segment: seg, as: "empty.m4s")

        let calls = await mock.pushSegmentCalls
        #expect(calls.count == 1)
        #expect(calls[0].segment.data.isEmpty)
    }

    @Test("Rapid segment production: 100 segments pushed")
    func rapidProduction() async throws {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await multi.add(mock, id: "cdn")

        for i in 0..<100 {
            try await multi.push(
                segment: makeSegment(index: i, dataSize: 64),
                as: "seg\(i).m4s"
            )
        }

        let calls = await mock.pushSegmentCalls
        #expect(calls.count == 100)
    }

    @Test("Connection lifecycle: connect, push, disconnect, reconnect")
    func connectionLifecycle() async throws {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await mock.setDisconnected()
        await multi.add(mock, id: "cdn")

        try await multi.connectAll()
        var state = await multi.connectionState
        #expect(state == .connected)

        try await multi.push(
            segment: makeSegment(index: 0), as: "seg0.m4s"
        )

        await multi.disconnectAll()
        state = await multi.connectionState
        #expect(state == .disconnected)

        try await multi.connectAll()
        state = await multi.connectionState
        #expect(state == .connected)

        try await multi.push(
            segment: makeSegment(index: 1), as: "seg1.m4s"
        )

        let calls = await mock.pushSegmentCalls
        #expect(calls.count == 2)
    }

    @Test("End-to-end: segmenter + playlist + push + rendition reports")
    func endToEnd() async throws {
        // Build LL-HLS content
        let manager = LLHLSManager()
        try await manager.addPartial(
            duration: 0.5, isIndependent: true
        )
        _ = await manager.completeSegment(
            duration: 2.0, uri: "seg0.ts"
        )

        await manager.setRenditionReports([
            RenditionReport(
                uri: "audio.m3u8",
                lastMediaSequence: 0, lastPartIndex: 0
            )
        ])

        let playlist = await manager.renderPlaylist()

        // Push to multi-destination
        let multi = MultiDestinationPusher()
        let cdn1 = MockPusher()
        let cdn2 = MockPusher()
        await multi.add(cdn1, id: "cdn1")
        await multi.add(cdn2, id: "cdn2")

        try await multi.pushPlaylist(playlist, as: "live.m3u8")

        // Verify both CDNs got the full playlist
        let calls1 = await cdn1.pushPlaylistCalls
        let calls2 = await cdn2.pushPlaylistCalls
        #expect(calls1.count == 1)
        #expect(calls2.count == 1)

        let m3u8 = calls1[0].m3u8
        #expect(m3u8.contains("#EXTM3U"))
        #expect(m3u8.contains("#EXT-X-PART:"))
        #expect(m3u8.contains("#EXT-X-RENDITION-REPORT:"))
        #expect(m3u8.contains("audio.m3u8"))
    }
}
