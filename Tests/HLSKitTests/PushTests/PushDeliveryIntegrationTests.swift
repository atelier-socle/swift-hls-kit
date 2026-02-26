// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing
import os

@testable import HLSKit

@Suite("Push Delivery Integration", .timeLimit(.minutes(1)))
struct PushDeliveryIntegrationTests {

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

    // MARK: - Full Pipeline

    @Test("HTTPPusher push 5 segments stats correct")
    func httpPusher5Segments() async throws {
        let mock = MockPusher()
        let multi = MultiDestinationPusher()
        await multi.add(mock, id: "cdn")

        for i in 0..<5 {
            try await multi.push(
                segment: makeSegment(index: i, dataSize: 200),
                as: "seg\(i).m4s"
            )
        }

        let calls = await mock.pushSegmentCalls
        #expect(calls.count == 5)
    }

    @Test("MultiDestination: 3 mocks push sequence")
    func threeDestinations() async throws {
        let multi = MultiDestinationPusher()
        let mocks = [MockPusher(), MockPusher(), MockPusher()]
        for (i, mock) in mocks.enumerated() {
            await multi.add(mock, id: "cdn\(i)")
        }

        for i in 0..<3 {
            try await multi.push(
                segment: makeSegment(index: i),
                as: "seg\(i).m4s"
            )
        }

        for mock in mocks {
            let calls = await mock.pushSegmentCalls
            #expect(calls.count == 3)
        }
    }

    @Test("BandwidthMonitor + push loop alerts on low bandwidth")
    func bandwidthAlerts() async {
        let alerts = OSAllocatedUnfairLock(
            initialState: [BandwidthMonitor.BandwidthAlert]()
        )
        let config = BandwidthMonitor.Configuration(
            windowDuration: 60,
            requiredBitrate: 10_000_000,
            alertThreshold: 0.9,
            criticalThreshold: 0.5,
            minimumSamples: 1
        )
        let monitor = BandwidthMonitor(configuration: config)
        await monitor.setOnBandwidthAlert { alert in
            alerts.withLock { $0.append(alert) }
        }

        for _ in 0..<3 {
            await monitor.recordPush(bytes: 10_000, duration: 1.0)
        }

        let count = alerts.withLock { $0.count }
        #expect(count > 0)
    }

    @Test("LL-HLS push: partials + playlist + rendition reports")
    func llhlsPush() async throws {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await multi.add(mock, id: "cdn")

        // Push a partial
        let partial = LLPartialSegment(
            duration: 0.5, uri: "part0.m4s",
            isIndependent: true, segmentIndex: 0, partialIndex: 0
        )
        try await multi.push(partial: partial, as: "part0.m4s")

        // Push a playlist with rendition reports
        let manager = LLHLSManager()
        try await manager.addPartial(
            duration: 0.5, isIndependent: true
        )
        await manager.setRenditionReports([
            RenditionReport(
                uri: "audio.m3u8",
                lastMediaSequence: 0, lastPartIndex: 0
            )
        ])
        let playlist = await manager.renderPlaylist()
        try await multi.pushPlaylist(playlist, as: "live.m3u8")

        let partialCalls = await mock.pushPartialCalls
        let playlistCalls = await mock.pushPlaylistCalls
        #expect(partialCalls.count == 1)
        #expect(playlistCalls.count == 1)
        #expect(
            playlistCalls[0].m3u8.contains("#EXT-X-RENDITION-REPORT:")
        )
    }

    @Test("Failover: primary fails, secondary continues")
    func failoverScenario() async throws {
        let multi = MultiDestinationPusher(
            failoverPolicy: .continueOnFailure
        )
        let primary = MockPusher()
        let secondary = MockPusher()
        await primary.setShouldFail(true)
        await multi.add(primary, id: "primary")
        await multi.add(secondary, id: "secondary")

        // Push should succeed (secondary works)
        for i in 0..<3 {
            try await multi.push(
                segment: makeSegment(index: i),
                as: "seg\(i).m4s"
            )
        }

        let secondaryCalls = await secondary.pushSegmentCalls
        #expect(secondaryCalls.count == 3)
    }

    @Test("Mixed protocols: multiple mocks all receive segments")
    func mixedProtocols() async throws {
        let multi = MultiDestinationPusher()
        let httpMock = MockPusher()
        let rtmpMock = MockPusher()
        let srtMock = MockPusher()
        await multi.add(httpMock, id: "http-cdn")
        await multi.add(rtmpMock, id: "rtmp-twitch")
        await multi.add(srtMock, id: "srt-feed")

        let seg = makeSegment(dataSize: 512)
        try await multi.push(segment: seg, as: "seg0.m4s")

        for mock in [httpMock, rtmpMock, srtMock] {
            let calls = await mock.pushSegmentCalls
            #expect(calls.count == 1)
            #expect(calls[0].segment.data.count == 512)
        }
    }
}
