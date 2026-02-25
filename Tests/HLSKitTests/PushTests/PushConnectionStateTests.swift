// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("PushConnectionState", .timeLimit(.minutes(1)))
struct PushConnectionStateTests {

    @Test("All cases exist")
    func allCases() {
        let cases: [PushConnectionState] = [
            .disconnected, .connecting, .connected,
            .reconnecting, .failed
        ]
        #expect(cases.count == 5)
    }

    @Test("isReady true only for connected")
    func isReady() {
        #expect(PushConnectionState.connected.isReady)
        #expect(!PushConnectionState.disconnected.isReady)
        #expect(!PushConnectionState.connecting.isReady)
        #expect(!PushConnectionState.reconnecting.isReady)
        #expect(!PushConnectionState.failed.isReady)
    }

    @Test("isTerminal true only for failed")
    func isTerminal() {
        #expect(PushConnectionState.failed.isTerminal)
        #expect(!PushConnectionState.connected.isTerminal)
        #expect(!PushConnectionState.disconnected.isTerminal)
        #expect(!PushConnectionState.connecting.isTerminal)
        #expect(!PushConnectionState.reconnecting.isTerminal)
    }

    @Test("Raw value strings")
    func rawValues() {
        #expect(
            PushConnectionState.disconnected.rawValue
                == "disconnected"
        )
        #expect(
            PushConnectionState.connected.rawValue == "connected"
        )
        #expect(PushConnectionState.failed.rawValue == "failed")
    }

    @Test("Equatable conformance")
    func equatable() {
        #expect(
            PushConnectionState.connected
                == PushConnectionState.connected
        )
        #expect(
            PushConnectionState.connected
                != PushConnectionState.failed
        )
    }

    @Test("Init from raw value")
    func initFromRaw() {
        let state = PushConnectionState(rawValue: "connecting")
        #expect(state == .connecting)
        let invalid = PushConnectionState(rawValue: "unknown")
        #expect(invalid == nil)
    }
}
