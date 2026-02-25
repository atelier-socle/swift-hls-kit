// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Recorded SRT connect call for mock verification.
struct MockSRTConnectCall: Sendable {
    let host: String
    let port: Int
    let options: SRTOptions
}

/// Mock SRT transport for testing.
///
/// Records all calls and can be configured to succeed or fail.
actor MockSRTTransport: SRTTransport {

    var connectCalls: [MockSRTConnectCall] = []
    var disconnectCallCount = 0
    var sendCalls: [Data] = []
    var _isConnected = false
    var shouldThrow = false
    var _networkStats: SRTNetworkStats?

    var isConnected: Bool { _isConnected }
    var networkStats: SRTNetworkStats? { _networkStats }

    func connect(
        to host: String, port: Int, options: SRTOptions
    ) async throws {
        connectCalls.append(
            MockSRTConnectCall(
                host: host, port: port, options: options
            )
        )
        if shouldThrow {
            throw PushError.connectionFailed(
                underlying: "mock SRT failure"
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
                underlying: "mock SRT send failure"
            )
        }
        sendCalls.append(data)
    }
}
