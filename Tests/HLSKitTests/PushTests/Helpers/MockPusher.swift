// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Mock implementation of ``SegmentPusher`` for testing.
///
/// Records all push calls and can be configured to succeed or fail.
actor MockPusher: SegmentPusher {

    var pushSegmentCalls: [(segment: LiveSegment, filename: String)] =
        []
    var pushPartialCalls: [(partial: LLPartialSegment, filename: String)] = []
    var pushPlaylistCalls: [(m3u8: String, filename: String)] = []
    var pushInitSegmentCalls: [(data: Data, filename: String)] = []

    var shouldFail = false
    var failureError: PushError = .connectionFailed(
        underlying: "mock failure"
    )
    var _connectionState: PushConnectionState = .connected
    var _stats: PushStats = .zero

    var connectionState: PushConnectionState { _connectionState }
    var stats: PushStats { _stats }

    func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        pushSegmentCalls.append((segment, filename))
        if shouldFail { throw failureError }
    }

    func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        pushPartialCalls.append((partial, filename))
        if shouldFail { throw failureError }
    }

    func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        pushPlaylistCalls.append((m3u8, filename))
        if shouldFail { throw failureError }
    }

    func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        pushInitSegmentCalls.append((data, filename))
        if shouldFail { throw failureError }
    }

    func connect() async throws {
        _connectionState = .connected
    }

    func disconnect() async {
        _connectionState = .disconnected
    }
}
