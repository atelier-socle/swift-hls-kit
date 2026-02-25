// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Recorded Icecast connect call for mock verification.
struct MockIcecastConnectCall: Sendable {
    let url: String
    let credentials: IcecastCredentials
    let mountpoint: String
}

/// Mock Icecast transport for testing.
///
/// Records all calls and can be configured to succeed or fail.
actor MockIcecastTransport: IcecastTransport {

    var connectCalls: [MockIcecastConnectCall] = []
    var disconnectCallCount = 0
    var sendCalls: [Data] = []
    var metadataCalls: [IcecastMetadata] = []
    var _isConnected = false
    var shouldThrow = false

    var isConnected: Bool { _isConnected }

    func connect(
        to url: String,
        credentials: IcecastCredentials,
        mountpoint: String
    ) async throws {
        connectCalls.append(
            MockIcecastConnectCall(
                url: url,
                credentials: credentials,
                mountpoint: mountpoint
            )
        )
        if shouldThrow {
            throw PushError.connectionFailed(
                underlying: "mock Icecast failure"
            )
        }
        _isConnected = true
    }

    func disconnect() async {
        disconnectCallCount += 1
        _isConnected = false
    }

    func send(_ data: Data) async throws {
        if shouldThrow {
            throw PushError.connectionFailed(
                underlying: "mock Icecast send failure"
            )
        }
        sendCalls.append(data)
    }

    func updateMetadata(
        _ metadata: IcecastMetadata
    ) async throws {
        if shouldThrow {
            throw PushError.connectionFailed(
                underlying: "mock Icecast metadata failure"
            )
        }
        metadataCalls.append(metadata)
    }
}
