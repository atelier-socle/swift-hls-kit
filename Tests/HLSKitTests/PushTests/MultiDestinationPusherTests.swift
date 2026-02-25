// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MultiDestinationPusher", .timeLimit(.minutes(1)))
struct MultiDestinationPusherTests {

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

    // MARK: - Destination Management

    @Test("Add single destination")
    func addSingle() async {
        let multi = MultiDestinationPusher()
        let mock = MockPusher()
        await multi.add(mock, id: "cdn1")
        let count = await multi.destinationCount
        #expect(count == 1)
    }

    @Test("Add multiple destinations")
    func addMultiple() async {
        let multi = MultiDestinationPusher()
        await multi.add(MockPusher(), id: "cdn1")
        await multi.add(MockPusher(), id: "cdn2")
        let ids = await multi.destinationIds
        #expect(ids == ["cdn1", "cdn2"])
        let count = await multi.destinationCount
        #expect(count == 2)
    }

    @Test("Remove destination")
    func removeDestination() async {
        let multi = MultiDestinationPusher()
        await multi.add(MockPusher(), id: "cdn1")
        await multi.add(MockPusher(), id: "cdn2")
        await multi.remove(id: "cdn1")
        let count = await multi.destinationCount
        #expect(count == 1)
        let ids = await multi.destinationIds
        #expect(ids == ["cdn2"])
    }

    @Test("Remove nonexistent ID is no-op")
    func removeNonexistent() async {
        let multi = MultiDestinationPusher()
        await multi.add(MockPusher(), id: "cdn1")
        await multi.remove(id: "unknown")
        let count = await multi.destinationCount
        #expect(count == 1)
    }

    // MARK: - Push Fan-Out

    @Test("Push segment to all destinations")
    func pushSegmentFanOut() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")

        let seg = makeSegment(dataSize: 256)
        try await multi.push(segment: seg, as: "seg0.m4s")

        let calls1 = await mock1.pushSegmentCalls
        let calls2 = await mock2.pushSegmentCalls
        #expect(calls1.count == 1)
        #expect(calls2.count == 1)
        #expect(calls1[0].segment.data.count == 256)
    }

    @Test("Push partial to all destinations")
    func pushPartialFanOut() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")

        let partial = LLPartialSegment(
            duration: 0.5, uri: "part0.m4s",
            isIndependent: true, segmentIndex: 0, partialIndex: 0
        )
        try await multi.push(partial: partial, as: "part0.m4s")

        let calls1 = await mock1.pushPartialCalls
        let calls2 = await mock2.pushPartialCalls
        #expect(calls1.count == 1)
        #expect(calls2.count == 1)
    }

    @Test("Push playlist to all destinations")
    func pushPlaylistFanOut() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")

        try await multi.pushPlaylist("#EXTM3U\n", as: "live.m3u8")

        let calls1 = await mock1.pushPlaylistCalls
        let calls2 = await mock2.pushPlaylistCalls
        #expect(calls1.count == 1)
        #expect(calls2.count == 1)
    }

    @Test("Push init segment to all destinations")
    func pushInitFanOut() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")

        let data = Data(repeating: 0xFF, count: 64)
        try await multi.pushInitSegment(data, as: "init.mp4")

        let calls1 = await mock1.pushInitSegmentCalls
        let calls2 = await mock2.pushInitSegmentCalls
        #expect(calls1.count == 1)
        #expect(calls2.count == 1)
    }

    @Test("Push to empty destinations is no-op")
    func pushToEmpty() async throws {
        let multi = MultiDestinationPusher()
        try await multi.push(segment: makeSegment(), as: "seg.m4s")
        // No error thrown
    }

    @Test("Push after remove only reaches remaining")
    func pushAfterRemove() async throws {
        let multi = MultiDestinationPusher()
        let mock1 = MockPusher()
        let mock2 = MockPusher()
        await multi.add(mock1, id: "cdn1")
        await multi.add(mock2, id: "cdn2")
        await multi.remove(id: "cdn1")

        try await multi.push(segment: makeSegment(), as: "seg.m4s")

        let calls1 = await mock1.pushSegmentCalls
        let calls2 = await mock2.pushSegmentCalls
        #expect(calls1.isEmpty)
        #expect(calls2.count == 1)
    }
}

// MARK: - MockPusher helpers

extension MockPusher {

    func setShouldFail(_ value: Bool) {
        shouldFail = value
    }

    func setDisconnected() {
        _connectionState = .disconnected
    }
}
