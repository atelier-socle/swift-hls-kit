// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("EventPlaylistConfiguration", .timeLimit(.minutes(1)))
struct EventPlaylistConfigurationTests {

    @Test("Default values")
    func defaults() {
        let config = EventPlaylistConfiguration()
        #expect(config.targetDuration == 6.0)
        #expect(config.version == 7)
    }

    @Test("Custom values")
    func custom() {
        let config = EventPlaylistConfiguration(
            targetDuration: 4.0,
            version: 6
        )
        #expect(config.targetDuration == 4.0)
        #expect(config.version == 6)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = EventPlaylistConfiguration(targetDuration: 4.0)
        let b = EventPlaylistConfiguration(targetDuration: 4.0)
        let c = EventPlaylistConfiguration(targetDuration: 6.0)
        #expect(a == b)
        #expect(a != c)
    }
}
