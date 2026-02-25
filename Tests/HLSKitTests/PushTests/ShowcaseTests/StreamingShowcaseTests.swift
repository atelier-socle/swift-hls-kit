// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Streaming Showcase", .timeLimit(.minutes(1)))
struct StreamingShowcaseTests {

    // MARK: - Helpers

    private func makeSegment(
        index: Int, dataSize: Int = 200,
        duration: Double = 2.0
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: UInt8(index % 256), count: dataSize),
            duration: duration,
            timestamp: MediaTimestamp(seconds: 0),
            isIndependent: true,
            discontinuity: false,
            programDateTime: nil,
            filename: "seg\(index).m4s",
            frameCount: 0,
            codecs: []
        )
    }

    // MARK: - RTMP Scenarios

    @Test("Twitch live stream: push 10 segments via RTMP")
    func twitchLiveStream() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.twitch(
            streamKey: "live_abc123"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        for i in 0..<10 {
            try await pusher.push(
                segment: makeSegment(index: i), as: "seg\(i).m4s"
            )
        }

        let stats = await pusher.stats
        #expect(stats.successCount == 10)
        let calls = await transport.sendCalls
        #expect(calls.count == 10)
        // Timestamps should accumulate: 0, 2000, 4000, ...
        #expect(calls[0].timestamp == 0)
        #expect(calls[9].timestamp == 18000)
    }

    @Test("YouTube simulcast: RTMP with metadata")
    func youtubeSimulcast() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.youtube(
            streamKey: "yt-key-456"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        // Send init segment as metadata.
        let initData = Data(repeating: 0xFF, count: 128)
        try await pusher.pushInitSegment(
            initData, as: "init.mp4"
        )

        // Push segments.
        for i in 0..<5 {
            try await pusher.push(
                segment: makeSegment(index: i), as: "seg\(i).m4s"
            )
        }

        let stats = await pusher.stats
        #expect(stats.successCount == 6)  // 1 init + 5 segments
    }

    // MARK: - SRT Scenarios

    @Test("SRT ultra-low-latency: partials push")
    func srtLowLatencyPartials() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.lowLatency(
            host: "srt.example.com"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        // Push playlist + segments.
        try await pusher.pushPlaylist(
            "#EXTM3U\n#EXT-X-VERSION:7\n",
            as: "playlist.m3u8"
        )
        for i in 0..<3 {
            try await pusher.push(
                segment: makeSegment(index: i), as: "seg\(i).m4s"
            )
        }

        let calls = await transport.sendCalls
        #expect(calls.count == 4)  // 1 playlist + 3 segments
    }

    @Test("Encrypted SRT stream")
    func encryptedSRTStream() async throws {
        let transport = MockSRTTransport()
        let config = SRTPusherConfiguration.encrypted(
            host: "secure.example.com",
            port: 9001,
            passphrase: "my-secret-key"
        )
        let pusher = SRTPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        let calls = await transport.connectCalls
        #expect(calls[0].options.passphrase == "my-secret-key")

        try await pusher.push(
            segment: makeSegment(index: 0, dataSize: 1024),
            as: "seg0.m4s"
        )

        let stats = await pusher.stats
        #expect(stats.totalBytesPushed == 1024)
    }

    // MARK: - Icecast Scenarios

    @Test("Podcast web radio: Icecast AAC with metadata")
    func podcastWebRadio() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration.aacStream(
            serverURL: "https://radio.example.com",
            mountpoint: "/podcast.aac",
            password: "radio-pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        try await pusher.updateMetadata(
            IcecastMetadata(
                streamTitle: "Episode 42: Swift Concurrency"
            )
        )

        for i in 0..<5 {
            try await pusher.push(
                segment: makeSegment(index: i), as: "seg\(i).m4s"
            )
        }

        let stats = await pusher.stats
        #expect(stats.successCount == 5)
        let metaCalls = await transport.metadataCalls
        #expect(metaCalls.count == 1)
    }

    @Test("Music stream: Icecast MP3 with track changes")
    func musicStreamWithTrackChanges() async throws {
        let transport = MockIcecastTransport()
        let config = IcecastPusherConfiguration.mp3Stream(
            serverURL: "https://radio.example.com",
            mountpoint: "/live.mp3",
            password: "dj-pass"
        )
        let pusher = IcecastPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()

        // Track 1.
        try await pusher.updateMetadata(
            IcecastMetadata(streamTitle: "Artist A - Song 1")
        )
        for i in 0..<3 {
            try await pusher.push(
                segment: makeSegment(index: i), as: "seg\(i).m4s"
            )
        }

        // Track 2.
        try await pusher.updateMetadata(
            IcecastMetadata(streamTitle: "Artist B - Song 2")
        )
        for i in 3..<6 {
            try await pusher.push(
                segment: makeSegment(index: i), as: "seg\(i).m4s"
            )
        }

        let metaCalls = await transport.metadataCalls
        #expect(metaCalls.count == 2)
        #expect(metaCalls[0].streamTitle == "Artist A - Song 1")
        #expect(metaCalls[1].streamTitle == "Artist B - Song 2")

        let stats = await pusher.stats
        #expect(stats.successCount == 6)
    }

    // MARK: - Cross-protocol

    @Test("Protocol comparison: same segments via all 3")
    func protocolComparison() async throws {
        let rtmpTransport = MockRTMPTransport()
        let srtTransport = MockSRTTransport()
        let icecastTransport = MockIcecastTransport()

        let rtmpPusher = RTMPPusher(
            configuration: .custom(
                serverURL: "rtmp://server.com/app",
                streamKey: "key"
            ),
            transport: rtmpTransport
        )
        let srtPusher = SRTPusher(
            configuration: .lowLatency(host: "srt.example.com"),
            transport: srtTransport
        )
        let icecastPusher = IcecastPusher(
            configuration: .mp3Stream(
                serverURL: "https://icecast.example.com",
                mountpoint: "/live.mp3",
                password: "pass"
            ),
            transport: icecastTransport
        )

        try await rtmpPusher.connect()
        try await srtPusher.connect()
        try await icecastPusher.connect()

        for i in 0..<3 {
            let seg = makeSegment(index: i)
            try await rtmpPusher.push(
                segment: seg, as: "seg\(i).m4s"
            )
            try await srtPusher.push(
                segment: seg, as: "seg\(i).m4s"
            )
            try await icecastPusher.push(
                segment: seg, as: "seg\(i).m4s"
            )
        }

        let rtmpStats = await rtmpPusher.stats
        let srtStats = await srtPusher.stats
        let icecastStats = await icecastPusher.stats

        #expect(rtmpStats.successCount == 3)
        #expect(srtStats.successCount == 3)
        #expect(icecastStats.successCount == 3)
    }

    @Test("Connection lifecycle: connect, push, disconnect")
    func connectionLifecycle() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )

        // Connect.
        try await pusher.connect()
        var state = await pusher.connectionState
        #expect(state == .connected)

        // Push.
        try await pusher.push(
            segment: makeSegment(index: 0), as: "seg0.m4s"
        )

        // Disconnect.
        await pusher.disconnect()
        state = await pusher.connectionState
        #expect(state == .disconnected)

        // Reconnect.
        try await pusher.connect()
        state = await pusher.connectionState
        #expect(state == .connected)

        // Push again.
        try await pusher.push(
            segment: makeSegment(index: 1), as: "seg1.m4s"
        )

        let stats = await pusher.stats
        #expect(stats.successCount == 2)
    }

    @Test("Stats consistency across protocols")
    func statsConsistency() async throws {
        let rtmpTransport = MockRTMPTransport()
        let srtTransport = MockSRTTransport()

        let rtmpPusher = RTMPPusher(
            configuration: .custom(
                serverURL: "rtmp://server.com/app",
                streamKey: "key"
            ),
            transport: rtmpTransport
        )
        let srtPusher = SRTPusher(
            configuration: .lowLatency(host: "srt.example.com"),
            transport: srtTransport
        )

        try await rtmpPusher.connect()
        try await srtPusher.connect()

        let segment = makeSegment(index: 0, dataSize: 500)
        try await rtmpPusher.push(
            segment: segment, as: "seg.m4s"
        )
        try await srtPusher.push(
            segment: segment, as: "seg.m4s"
        )

        let rtmpStats = await rtmpPusher.stats
        let srtStats = await srtPusher.stats

        #expect(rtmpStats.totalBytesPushed == 500)
        #expect(srtStats.totalBytesPushed == 500)
        #expect(rtmpStats.successCount == srtStats.successCount)
    }
}
