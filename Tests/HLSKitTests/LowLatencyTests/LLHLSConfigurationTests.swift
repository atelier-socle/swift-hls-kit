// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("LLHLSConfiguration", .timeLimit(.minutes(1)))
struct LLHLSConfigurationTests {

    // MARK: - Presets

    @Test("ultraLowLatency preset values")
    func ultraLowLatency() {
        let config = LLHLSConfiguration.ultraLowLatency
        #expect(config.partTargetDuration == 0.2)
        #expect(config.maxPartialsPerSegment == 5)
        #expect(config.segmentTargetDuration == 1.0)
        #expect(config.retainedPartialSegments == 4)
    }

    @Test("lowLatency preset values")
    func lowLatency() {
        let config = LLHLSConfiguration.lowLatency
        #expect(config.partTargetDuration == 0.33334)
        #expect(config.maxPartialsPerSegment == 6)
        #expect(config.segmentTargetDuration == 2.0)
        #expect(config.retainedPartialSegments == 3)
    }

    @Test("balanced preset values")
    func balanced() {
        let config = LLHLSConfiguration.balanced
        #expect(config.partTargetDuration == 0.5)
        #expect(config.maxPartialsPerSegment == 8)
        #expect(config.segmentTargetDuration == 4.0)
        #expect(config.retainedPartialSegments == 3)
    }

    // MARK: - Custom

    @Test("Custom configuration")
    func custom() {
        let config = LLHLSConfiguration(
            partTargetDuration: 0.25,
            maxPartialsPerSegment: 4,
            segmentTargetDuration: 1.0,
            retainedPartialSegments: 5,
            partialURITemplate: "part-{segment}-{part}.{ext}",
            fileExtension: "m4s",
            includeProgramDateTime: true
        )

        #expect(config.partTargetDuration == 0.25)
        #expect(config.maxPartialsPerSegment == 4)
        #expect(config.segmentTargetDuration == 1.0)
        #expect(config.retainedPartialSegments == 5)
        #expect(config.fileExtension == "m4s")
        #expect(config.includeProgramDateTime == true)
    }

    // MARK: - URI Template

    @Test("URI template resolves placeholders")
    func resolveURI() {
        let config = LLHLSConfiguration()
        let uri = config.resolveURI(
            segmentIndex: 3, partialIndex: 1
        )
        #expect(uri == "seg3.1.mp4")
    }

    @Test("Custom URI template resolves correctly")
    func customTemplate() {
        let config = LLHLSConfiguration(
            partialURITemplate: "part-{segment}-{part}.{ext}",
            fileExtension: "m4s"
        )
        let uri = config.resolveURI(
            segmentIndex: 10, partialIndex: 2
        )
        #expect(uri == "part-10-2.m4s")
    }

    // MARK: - Server Control

    @Test("ultraLowLatency has delta-enabled server control")
    func ultraLowLatencyServerControl() {
        let sc = LLHLSConfiguration.ultraLowLatency.serverControl
        #expect(sc != nil)
        #expect(sc?.canSkipUntil != nil)
    }

    @Test("lowLatency has delta-enabled server control")
    func lowLatencyServerControl() {
        let sc = LLHLSConfiguration.lowLatency.serverControl
        #expect(sc != nil)
        #expect(sc?.canSkipUntil != nil)
    }

    @Test("balanced has standard server control (no delta)")
    func balancedServerControl() {
        let sc = LLHLSConfiguration.balanced.serverControl
        #expect(sc != nil)
        #expect(sc?.canSkipUntil == nil)
    }

    @Test("Custom config with nil serverControl")
    func customServerControlNil() {
        let config = LLHLSConfiguration()
        #expect(config.serverControl == nil)
    }

    @Test("Custom config with explicit serverControl")
    func customServerControlExplicit() {
        let config = LLHLSConfiguration(
            serverControl: .withDeltaUpdates(
                targetDuration: 2.0, partTargetDuration: 0.33
            )
        )
        #expect(config.serverControl?.canSkipUntil != nil)
    }

    // MARK: - Equatable

    @Test("Presets are equatable")
    func equatable() {
        let a = LLHLSConfiguration.lowLatency
        let b = LLHLSConfiguration.lowLatency
        #expect(a == b)
    }

    @Test("Different configs are not equal")
    func notEqual() {
        let a = LLHLSConfiguration.lowLatency
        let b = LLHLSConfiguration.balanced
        #expect(a != b)
    }
}
