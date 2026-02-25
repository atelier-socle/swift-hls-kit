// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ServerControlConfig", .timeLimit(.minutes(1)))
struct ServerControlConfigTests {

    @Test("Default initialization values")
    func defaultInit() {
        let config = ServerControlConfig()
        #expect(config.canBlockReload == true)
        #expect(config.holdBack == nil)
        #expect(config.partHoldBack == nil)
        #expect(config.canSkipUntil == nil)
        #expect(config.canSkipDateRanges == false)
    }

    @Test("Custom values initialization")
    func customInit() {
        let config = ServerControlConfig(
            canBlockReload: false,
            holdBack: 9.0,
            partHoldBack: 1.5,
            canSkipUntil: 36.0,
            canSkipDateRanges: true
        )
        #expect(config.canBlockReload == false)
        #expect(config.holdBack == 9.0)
        #expect(config.partHoldBack == 1.5)
        #expect(config.canSkipUntil == 36.0)
        #expect(config.canSkipDateRanges == true)
    }

    @Test("effectiveHoldBack with explicit value")
    func effectiveHoldBackExplicit() {
        let config = ServerControlConfig(holdBack: 9.0)
        let result = config.effectiveHoldBack(targetDuration: 2.0)
        #expect(result == 9.0)
    }

    @Test("effectiveHoldBack with nil falls back to 3× target")
    func effectiveHoldBackDefault() {
        let config = ServerControlConfig()
        let result = config.effectiveHoldBack(targetDuration: 2.0)
        #expect(result == 6.0)
    }

    @Test("effectivePartHoldBack with explicit value")
    func effectivePartHoldBackExplicit() {
        let config = ServerControlConfig(partHoldBack: 1.5)
        let result = config.effectivePartHoldBack(
            partTargetDuration: 0.33
        )
        #expect(result == 1.5)
    }

    @Test("effectivePartHoldBack with nil falls back to 3× partTarget")
    func effectivePartHoldBackDefault() {
        let config = ServerControlConfig()
        let result = config.effectivePartHoldBack(
            partTargetDuration: 0.33334
        )
        #expect(abs(result - 1.00002) < 0.0001)
    }

    @Test("recommendedSkipUntil is 6× target")
    func recommendedSkipUntil() {
        let result = ServerControlConfig.recommendedSkipUntil(
            targetDuration: 2.0
        )
        #expect(result == 12.0)
    }

    @Test("standard preset values")
    func standardPreset() {
        let config = ServerControlConfig.standard(
            targetDuration: 2.0,
            partTargetDuration: 0.33334
        )
        #expect(config.canBlockReload == true)
        #expect(config.holdBack == 6.0)
        #expect(abs((config.partHoldBack ?? 0) - 1.00002) < 0.0001)
        #expect(config.canSkipUntil == nil)
        #expect(config.canSkipDateRanges == false)
    }

    @Test("withDeltaUpdates preset has canSkipUntil")
    func withDeltaUpdatesPreset() {
        let config = ServerControlConfig.withDeltaUpdates(
            targetDuration: 2.0,
            partTargetDuration: 0.33334
        )
        #expect(config.canBlockReload == true)
        #expect(config.holdBack == 6.0)
        #expect(config.canSkipUntil == 12.0)
        #expect(config.canSkipDateRanges == false)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = ServerControlConfig(holdBack: 6.0)
        let b = ServerControlConfig(holdBack: 6.0)
        let c = ServerControlConfig(holdBack: 9.0)
        #expect(a == b)
        #expect(a != c)
    }
}
