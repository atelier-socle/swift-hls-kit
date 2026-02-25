// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SlidingWindowConfiguration", .timeLimit(.minutes(1)))
struct SlidingWindowConfigurationTests {

    @Test("Default values")
    func defaults() {
        let config = SlidingWindowConfiguration()
        #expect(config.windowSize == 5)
        #expect(config.targetDuration == 6.0)
        #expect(config.version == 7)
    }

    @Test("Custom values")
    func custom() {
        let config = SlidingWindowConfiguration(
            windowSize: 10,
            targetDuration: 4.0,
            version: 6
        )
        #expect(config.windowSize == 10)
        #expect(config.targetDuration == 4.0)
        #expect(config.version == 6)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = SlidingWindowConfiguration(windowSize: 3)
        let b = SlidingWindowConfiguration(windowSize: 3)
        let c = SlidingWindowConfiguration(windowSize: 5)
        #expect(a == b)
        #expect(a != c)
    }
}
