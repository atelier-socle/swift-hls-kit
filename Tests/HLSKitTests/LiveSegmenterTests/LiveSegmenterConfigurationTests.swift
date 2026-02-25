// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "LiveSegmenterConfiguration",
    .timeLimit(.minutes(1))
)
struct LiveSegmenterConfigurationTests {

    @Test("Default configuration values")
    func defaultValues() {
        let config = LiveSegmenterConfiguration()
        #expect(config.targetDuration == 6.0)
        #expect(config.maxDuration == 9.0)
        #expect(config.ringBufferSize == 5)
        #expect(config.keyframeAligned)
        #expect(config.startIndex == 0)
        #expect(config.trackProgramDateTime)
        #expect(config.namingPattern == "segment_%d.m4s")
    }

    @Test("Custom configuration values")
    func customValues() {
        let config = LiveSegmenterConfiguration(
            targetDuration: 4.0,
            maxDuration: 8.0,
            ringBufferSize: 10,
            keyframeAligned: false,
            startIndex: 5,
            trackProgramDateTime: false,
            namingPattern: "chunk_%d.ts"
        )
        #expect(config.targetDuration == 4.0)
        #expect(config.maxDuration == 8.0)
        #expect(config.ringBufferSize == 10)
        #expect(!config.keyframeAligned)
        #expect(config.startIndex == 5)
        #expect(!config.trackProgramDateTime)
        #expect(config.namingPattern == "chunk_%d.ts")
    }

    @Test("maxDuration defaults to targetDuration x 1.5")
    func maxDurationDefault() {
        let config = LiveSegmenterConfiguration(
            targetDuration: 4.0
        )
        #expect(config.maxDuration == 6.0)
    }

    @Test("Preset: standardLive")
    func presetStandardLive() {
        let config = LiveSegmenterConfiguration.standardLive
        #expect(config.targetDuration == 6.0)
        #expect(config.ringBufferSize == 5)
        #expect(config.keyframeAligned)
    }

    @Test("Preset: lowLatencyPrep")
    func presetLowLatency() {
        let config = LiveSegmenterConfiguration.lowLatencyPrep
        #expect(config.targetDuration == 2.0)
        #expect(config.ringBufferSize == 8)
        #expect(config.keyframeAligned)
    }

    @Test("Preset: audioOnly")
    func presetAudioOnly() {
        let config = LiveSegmenterConfiguration.audioOnly
        #expect(!config.keyframeAligned)
        #expect(config.targetDuration == 6.0)
    }

    @Test("Preset: longDVR")
    func presetLongDVR() {
        let config = LiveSegmenterConfiguration.longDVR
        #expect(config.ringBufferSize == 60)
    }

    @Test("Preset: eventRecording")
    func presetEventRecording() {
        let config = LiveSegmenterConfiguration.eventRecording
        #expect(config.ringBufferSize == .max)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = LiveSegmenterConfiguration.standardLive
        let b = LiveSegmenterConfiguration.standardLive
        let c = LiveSegmenterConfiguration.lowLatencyPrep
        #expect(a == b)
        #expect(a != c)
    }
}
