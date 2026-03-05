// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TransportRecordingState — Recording State")
struct TransportRecordingStateTests {

    // MARK: - Init

    @Test("Init stores all parameters")
    func initStoresAllParameters() {
        let state = TransportRecordingState(
            isRecording: true,
            bytesWritten: 5_000_000,
            duration: 120.0,
            currentFilePath: "/tmp/recording.ts"
        )
        #expect(state.isRecording == true)
        #expect(state.bytesWritten == 5_000_000)
        #expect(state.duration == 120.0)
        #expect(state.currentFilePath == "/tmp/recording.ts")
    }

    // MARK: - States

    @Test("Active recording state")
    func activeRecordingState() {
        let state = TransportRecordingState(
            isRecording: true,
            bytesWritten: 1024,
            duration: 10.0,
            currentFilePath: "/var/recordings/stream.ts"
        )
        #expect(state.isRecording)
        #expect(state.currentFilePath != nil)
    }

    @Test("Inactive recording state with nil path")
    func inactiveState() {
        let state = TransportRecordingState(
            isRecording: false,
            bytesWritten: 0,
            duration: 0,
            currentFilePath: nil
        )
        #expect(!state.isRecording)
        #expect(state.currentFilePath == nil)
    }

    // MARK: - Equatable

    @Test("Equatable conformance")
    func equatableConformance() {
        let a = TransportRecordingState(
            isRecording: true,
            bytesWritten: 100,
            duration: 5.0,
            currentFilePath: "/tmp/a.ts"
        )
        let b = TransportRecordingState(
            isRecording: true,
            bytesWritten: 100,
            duration: 5.0,
            currentFilePath: "/tmp/a.ts"
        )
        #expect(a == b)
    }

    // MARK: - Zero State

    @Test("Zero state")
    func zeroState() {
        let state = TransportRecordingState(
            isRecording: false,
            bytesWritten: 0,
            duration: 0,
            currentFilePath: nil
        )
        #expect(state.bytesWritten == 0)
        #expect(state.duration == 0)
    }
}
