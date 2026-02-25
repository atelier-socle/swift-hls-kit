// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("LivePlaylistMetadata", .timeLimit(.minutes(1)))
struct LivePlaylistMetadataTests {

    @Test("Default values")
    func defaults() {
        let m = LivePlaylistMetadata()
        #expect(m.independentSegments == false)
        #expect(m.startOffset == nil)
        #expect(m.startPrecise == false)
        #expect(m.customTags.isEmpty)
    }

    @Test("Custom values")
    func custom() {
        let m = LivePlaylistMetadata(
            independentSegments: true,
            startOffset: -12.0,
            startPrecise: true,
            customTags: ["#EXT-X-SESSION-DATA:DATA-ID=\"test\""]
        )
        #expect(m.independentSegments == true)
        #expect(m.startOffset == -12.0)
        #expect(m.startPrecise == true)
        #expect(m.customTags.count == 1)
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = LivePlaylistMetadata(independentSegments: true)
        let b = LivePlaylistMetadata(independentSegments: true)
        let c = LivePlaylistMetadata(independentSegments: false)
        #expect(a == b)
        #expect(a != c)
    }
}
