// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "RTMPPusher Edge Cases", .timeLimit(.minutes(1))
)
struct RTMPPusherEdgeCaseTests {

    @Test("Init segment transport failure records stats")
    func initSegmentFailure() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()
        await transport.setThrow(true)

        do {
            try await pusher.pushInitSegment(
                Data(repeating: 0xFF, count: 64), as: "init.mp4"
            )
        } catch {}

        let stats = await pusher.stats
        #expect(stats.failureCount == 1)
    }

    @Test("Partial segment transport failure records stats")
    func partialSegmentFailure() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )
        try await pusher.connect()
        await transport.setThrow(true)

        do {
            let partial = LLPartialSegment(
                duration: 0.5,
                uri: "part0.m4s",
                isIndependent: true,
                segmentIndex: 0,
                partialIndex: 0
            )
            try await pusher.push(
                partial: partial, as: "part0.m4s"
            )
        } catch {}

        let stats = await pusher.stats
        #expect(stats.failureCount == 1)
    }

    @Test("Push partial not connected throws")
    func pushPartialNotConnected() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )

        do {
            let partial = LLPartialSegment(
                duration: 0.5,
                uri: "part0.m4s",
                isIndependent: true,
                segmentIndex: 0,
                partialIndex: 0
            )
            try await pusher.push(
                partial: partial, as: "part0.m4s"
            )
            Issue.record("Expected notConnected")
        } catch let error as PushError {
            guard case .notConnected = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
    }

    @Test("Push init segment not connected throws")
    func pushInitNotConnected() async throws {
        let transport = MockRTMPTransport()
        let config = RTMPPusherConfiguration.custom(
            serverURL: "rtmp://server.com/app",
            streamKey: "key"
        )
        let pusher = RTMPPusher(
            configuration: config, transport: transport
        )

        do {
            try await pusher.pushInitSegment(
                Data(repeating: 0xFF, count: 64), as: "init.mp4"
            )
            Issue.record("Expected notConnected")
        } catch let error as PushError {
            guard case .notConnected = error else {
                Issue.record("Wrong error: \(error)")
                return
            }
        }
    }
}
