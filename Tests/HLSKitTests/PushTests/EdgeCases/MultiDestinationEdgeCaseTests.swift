// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "MultiDestinationPusher Edge Cases", .timeLimit(.minutes(1))
)
struct MultiDestinationEdgeCaseTests {

    // MARK: - Helpers

    private func makeSegment(
        index: Int = 0, dataSize: Int = 100
    ) -> LiveSegment {
        LiveSegment(
            index: index,
            data: Data(repeating: 0xAB, count: dataSize),
            duration: 2.0,
            timestamp: MediaTimestamp(seconds: 0),
            isIndependent: true,
            discontinuity: false,
            programDateTime: nil,
            filename: "seg\(index).m4s",
            frameCount: 0,
            codecs: []
        )
    }

    // MARK: - Failover Policies

    @Test("continueOnFailure: one fails, others succeed")
    func continueOnFailureSingleFail() async throws {
        let multi = MultiDestinationPusher(
            failoverPolicy: .continueOnFailure
        )
        let good = MockPusher()
        let bad = MockPusher()
        await bad.setShouldFail(true)

        await multi.add(good, id: "good")
        await multi.add(bad, id: "bad")

        try await multi.push(segment: makeSegment(), as: "seg.m4s")
        let calls = await good.pushSegmentCalls
        #expect(calls.count == 1)
    }

    @Test("continueOnFailure: ALL fail throws")
    func continueOnFailureAllFail() async throws {
        let multi = MultiDestinationPusher(
            failoverPolicy: .continueOnFailure
        )
        let bad1 = MockPusher()
        let bad2 = MockPusher()
        await bad1.setShouldFail(true)
        await bad2.setShouldFail(true)
        await multi.add(bad1, id: "bad1")
        await multi.add(bad2, id: "bad2")

        do {
            try await multi.push(
                segment: makeSegment(), as: "seg.m4s"
            )
            Issue.record("Expected error")
        } catch {
            // Expected
        }
    }

    @Test("failOnPrimary: primary fails throws")
    func failOnPrimaryFails() async throws {
        let multi = MultiDestinationPusher(
            failoverPolicy: .failOnPrimary(primaryId: "primary")
        )
        let primary = MockPusher()
        let backup = MockPusher()
        await primary.setShouldFail(true)
        await multi.add(primary, id: "primary")
        await multi.add(backup, id: "backup")

        do {
            try await multi.push(
                segment: makeSegment(), as: "seg.m4s"
            )
            Issue.record("Expected error")
        } catch {
            // Expected - primary failed
        }
    }

    @Test("failOnPrimary: non-primary fails, no throw")
    func failOnPrimaryNonPrimaryFails() async throws {
        let multi = MultiDestinationPusher(
            failoverPolicy: .failOnPrimary(primaryId: "primary")
        )
        let primary = MockPusher()
        let backup = MockPusher()
        await backup.setShouldFail(true)
        await multi.add(primary, id: "primary")
        await multi.add(backup, id: "backup")

        try await multi.push(segment: makeSegment(), as: "seg.m4s")
        let calls = await primary.pushSegmentCalls
        #expect(calls.count == 1)
    }

    @Test("requireAll: one fails throws")
    func requireAllOneFails() async throws {
        let multi = MultiDestinationPusher(
            failoverPolicy: .requireAll
        )
        let good = MockPusher()
        let bad = MockPusher()
        await bad.setShouldFail(true)
        await multi.add(good, id: "good")
        await multi.add(bad, id: "bad")

        do {
            try await multi.push(
                segment: makeSegment(), as: "seg.m4s"
            )
            Issue.record("Expected error")
        } catch {
            // Expected
        }
    }

    // MARK: - PushWithResults

    @Test("pushWithResults returns per-destination results")
    func pushWithResults() async {
        let multi = MultiDestinationPusher()
        let good = MockPusher()
        let bad = MockPusher()
        await bad.setShouldFail(true)
        await multi.add(good, id: "good")
        await multi.add(bad, id: "bad")

        let result = await multi.pushWithResults(
            segment: makeSegment(), as: "seg.m4s"
        )
        #expect(result.successCount == 1)
        #expect(result.failureCount == 1)
        #expect(!result.allSucceeded)
    }

    @Test("pushWithResults all succeed")
    func pushWithResultsAllSucceed() async {
        let multi = MultiDestinationPusher()
        await multi.add(MockPusher(), id: "cdn1")
        await multi.add(MockPusher(), id: "cdn2")

        let result = await multi.pushWithResults(
            segment: makeSegment(), as: "seg.m4s"
        )
        #expect(result.successCount == 2)
        #expect(result.failureCount == 0)
        #expect(result.allSucceeded)
    }

    // MARK: - Connection Management

    @Test("connectAll connects all destinations")
    func connectAll() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await mock1.setDisconnected()
        await mock2.setDisconnected()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")

        try await multi.connectAll()

        let states = await multi.destinationStates
        #expect(states["cdn1"] == .connected)
        #expect(states["cdn2"] == .connected)
    }

    @Test("disconnectAll disconnects all destinations")
    func disconnectAll() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")
        try await multi.connectAll()

        await multi.disconnectAll()

        let states = await multi.destinationStates
        #expect(states["cdn1"] == .disconnected)
        #expect(states["cdn2"] == .disconnected)
    }

    @Test("connectionState connected if ANY connected")
    func connectionStateAny() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await mock2.setDisconnected()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")
        try await multi.connectAll()

        let state = await multi.connectionState
        #expect(state == .connected)
    }

    @Test("connectionState disconnected if ALL disconnected")
    func connectionStateAllDisconnected() async {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await mock.setDisconnected()
        await multi.add(mock, id: "cdn1")

        let state = await multi.connectionState
        #expect(state == .disconnected)
    }

    // MARK: - Large Fan-Out

    @Test("Large fan-out: 5 destinations all receive data")
    func largeFanOut() async throws {
        let multi = MultiDestinationPusher()
        var mocks = [MockPusher]()
        for i in 0..<5 {
            let mock = MockPusher()
            mocks.append(mock)
            await multi.add(mock, id: "cdn\(i)")
        }

        try await multi.push(segment: makeSegment(), as: "seg.m4s")

        for mock in mocks {
            let calls = await mock.pushSegmentCalls
            #expect(calls.count == 1)
        }
    }

    // MARK: - Stats & Connect/Disconnect

    @Test("Aggregated stats across destinations")
    func aggregatedStats() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")

        let stats = await multi.stats
        #expect(stats.totalBytesPushed == 0)
        #expect(stats.successCount == 0)
    }

    @Test("connect delegates to connectAll")
    func connectDelegates() async throws {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await mock.setDisconnected()
        await multi.add(mock, id: "cdn")

        try await multi.connect()

        let state = await multi.connectionState
        #expect(state == .connected)
    }

    @Test("disconnect delegates to disconnectAll")
    func disconnectDelegates() async throws {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await multi.add(mock, id: "cdn")
        try await multi.connectAll()

        await multi.disconnect()

        let state = await multi.connectionState
        #expect(state == .disconnected)
    }
}
