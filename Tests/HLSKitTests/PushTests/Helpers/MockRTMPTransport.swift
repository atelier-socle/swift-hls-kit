// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Recorded RTMP send call for mock verification.
struct MockRTMPSendCall: Sendable {
    let data: Data
    let timestamp: UInt32
    let type: FLVTagType
}

/// Mock RTMP transport for testing.
///
/// Records all calls and can be configured to succeed or fail.
actor MockRTMPTransport: RTMPTransport {

    var connectCalls: [String] = []
    var disconnectCallCount = 0
    var sendCalls: [MockRTMPSendCall] = []
    var _isConnected = false
    var shouldThrow = false

    var isConnected: Bool { _isConnected }

    func connect(to url: String) async throws {
        connectCalls.append(url)
        if shouldThrow {
            throw PushError.connectionFailed(
                underlying: "mock RTMP failure"
            )
        }
        _isConnected = true
    }

    func disconnect() async {
        disconnectCallCount += 1
        _isConnected = false
    }

    func send(
        data: Data, timestamp: UInt32, type: FLVTagType
    ) async throws {
        if shouldThrow {
            throw PushError.connectionFailed(
                underlying: "mock RTMP send failure"
            )
        }
        sendCalls.append(
            MockRTMPSendCall(
                data: data, timestamp: timestamp, type: type
            )
        )
    }
}
