// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePipelineState", .timeLimit(.minutes(1)))
struct LivePipelineStateTests {

    // MARK: - State Construction

    @Test("Idle state is constructable")
    func idleState() {
        let state = LivePipelineState.idle
        #expect(state == .idle)
    }

    @Test("Starting state is constructable")
    func startingState() {
        let state = LivePipelineState.starting
        #expect(state == .starting)
    }

    @Test("Running state is constructable")
    func runningState() {
        let state = LivePipelineState.running(since: Date())
        #expect(state == .running(since: Date.distantPast))
    }

    @Test("Stopping state is constructable")
    func stoppingState() {
        let state = LivePipelineState.stopping
        #expect(state == .stopping)
    }

    @Test("Stopped state is constructable")
    func stoppedState() {
        let summary = LivePipelineSummary(
            duration: 60, segmentsProduced: 10, totalBytes: 1024,
            startDate: Date(), stopDate: Date(), reason: .userRequested
        )
        let state = LivePipelineState.stopped(summary: summary)
        #expect(state == .stopped(summary: summary))
    }

    @Test("Failed state is constructable")
    func failedState() {
        let state = LivePipelineState.failed(.notRunning)
        #expect(state == .failed(.notRunning))
    }

    // MARK: - Equality

    @Test("Running with different dates are equal (case-only comparison)")
    func runningDifferentDatesEqual() {
        let state1 = LivePipelineState.running(since: Date.distantPast)
        let state2 = LivePipelineState.running(since: Date.distantFuture)
        #expect(state1 == state2)
    }

    @Test("Different state cases are not equal")
    func differentCasesNotEqual() {
        #expect(LivePipelineState.idle != .starting)
        #expect(LivePipelineState.starting != .stopping)
        #expect(LivePipelineState.idle != .running(since: Date()))
    }

    // MARK: - LivePipelineSummary

    @Test("Summary stores all fields correctly")
    func summaryFields() {
        let start = Date(timeIntervalSince1970: 1000)
        let stop = Date(timeIntervalSince1970: 1060)
        let summary = LivePipelineSummary(
            duration: 60, segmentsProduced: 10, totalBytes: 5000,
            startDate: start, stopDate: stop, reason: .sourceEnded
        )
        #expect(summary.duration == 60)
        #expect(summary.segmentsProduced == 10)
        #expect(summary.totalBytes == 5000)
        #expect(summary.startDate == start)
        #expect(summary.stopDate == stop)
        #expect(summary.reason == .sourceEnded)
    }

    @Test("StopReason raw values")
    func stopReasonRawValues() {
        #expect(LivePipelineSummary.StopReason.userRequested.rawValue == "userRequested")
        #expect(LivePipelineSummary.StopReason.sourceEnded.rawValue == "sourceEnded")
        #expect(LivePipelineSummary.StopReason.error.rawValue == "error")
    }

    // MARK: - LivePipelineError

    @Test("Error cases are constructable and equatable")
    func errorCases() {
        #expect(LivePipelineError.notRunning == .notRunning)
        #expect(LivePipelineError.alreadyRunning == .alreadyRunning)
        #expect(LivePipelineError.invalidConfiguration("bad") == .invalidConfiguration("bad"))
        #expect(LivePipelineError.encodingFailed("enc") == .encodingFailed("enc"))
        #expect(LivePipelineError.segmentationFailed("seg") == .segmentationFailed("seg"))
        #expect(LivePipelineError.pushFailed("push") == .pushFailed("push"))
        #expect(LivePipelineError.sourceError("src") == .sourceError("src"))
    }

    @Test("Error cases with different messages are not equal")
    func errorDifferentMessages() {
        #expect(LivePipelineError.invalidConfiguration("a") != .invalidConfiguration("b"))
    }

    // MARK: - LivePipelineEvent

    @Test("Event cases are constructable")
    func eventCases() {
        _ = LivePipelineEvent.stateChanged(.idle)
        _ = LivePipelineEvent.segmentProduced(index: 0, duration: 6.0, byteSize: 1024)
        _ = LivePipelineEvent.pushCompleted(
            destination: "cdn", segmentIndex: 1, latency: 0.5
        )
        _ = LivePipelineEvent.pushFailed(destination: "cdn", error: "timeout")
        _ = LivePipelineEvent.metadataInserted(type: "ID3")
        _ = LivePipelineEvent.discontinuityInserted
        _ = LivePipelineEvent.recordingSegmentSaved(filename: "seg001.ts")
        _ = LivePipelineEvent.warning("low bandwidth")
    }

    // MARK: - Valid Transitions

    @Test("Valid: idle → starting")
    func validIdleToStarting() {
        #expect(LivePipelineStateTransition.isValid(from: .idle, to: .starting))
    }

    @Test("Valid: starting → running")
    func validStartingToRunning() {
        #expect(
            LivePipelineStateTransition.isValid(
                from: .starting, to: .running(since: Date())
            ))
    }

    @Test("Valid: starting → failed")
    func validStartingToFailed() {
        #expect(
            LivePipelineStateTransition.isValid(
                from: .starting, to: .failed(.encodingFailed("init error"))
            ))
    }

    @Test("Valid: running → stopping")
    func validRunningToStopping() {
        #expect(
            LivePipelineStateTransition.isValid(
                from: .running(since: Date()), to: .stopping
            ))
    }

    @Test("Valid: running → failed")
    func validRunningToFailed() {
        #expect(
            LivePipelineStateTransition.isValid(
                from: .running(since: Date()), to: .failed(.sourceError("eof"))
            ))
    }

    @Test("Valid: stopping → stopped")
    func validStoppingToStopped() {
        let summary = LivePipelineSummary(
            duration: 10, segmentsProduced: 2, totalBytes: 500,
            startDate: Date(), stopDate: Date(), reason: .userRequested
        )
        #expect(
            LivePipelineStateTransition.isValid(
                from: .stopping, to: .stopped(summary: summary)
            ))
    }

    @Test("Valid: stopping → failed")
    func validStoppingToFailed() {
        #expect(
            LivePipelineStateTransition.isValid(
                from: .stopping, to: .failed(.pushFailed("flush error"))
            ))
    }

    // MARK: - Invalid Transitions

    @Test("Invalid: idle → running (skipping starting)")
    func invalidIdleToRunning() {
        #expect(
            !LivePipelineStateTransition.isValid(
                from: .idle, to: .running(since: Date())
            ))
    }

    @Test("Invalid: running → starting")
    func invalidRunningToStarting() {
        #expect(
            !LivePipelineStateTransition.isValid(
                from: .running(since: Date()), to: .starting
            ))
    }

    @Test("Invalid: stopped → running")
    func invalidStoppedToRunning() {
        let summary = LivePipelineSummary(
            duration: 10, segmentsProduced: 2, totalBytes: 500,
            startDate: Date(), stopDate: Date(), reason: .userRequested
        )
        #expect(
            !LivePipelineStateTransition.isValid(
                from: .stopped(summary: summary), to: .running(since: Date())
            ))
    }

    @Test("Invalid: stopped → starting")
    func invalidStoppedToStarting() {
        let summary = LivePipelineSummary(
            duration: 10, segmentsProduced: 2, totalBytes: 500,
            startDate: Date(), stopDate: Date(), reason: .userRequested
        )
        #expect(
            !LivePipelineStateTransition.isValid(
                from: .stopped(summary: summary), to: .starting
            ))
    }

    // MARK: - Valid Transitions List

    @Test("All valid transitions are listed")
    func validTransitionsList() {
        let transitions = LivePipelineStateTransition.validTransitions
        #expect(transitions.count == 7)
        #expect(transitions[0].from == "idle")
        #expect(transitions[0].to == "starting")
        #expect(transitions[6].from == "stopping")
        #expect(transitions[6].to == "failed")
    }
}
