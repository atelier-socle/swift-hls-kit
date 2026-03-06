// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("VideoChannelLayout")
struct VideoChannelLayoutTests {

    @Test("Raw value for stereoLeftRight is CH-STEREO")
    func stereoLeftRightRawValue() {
        #expect(VideoChannelLayout.stereoLeftRight.rawValue == "CH-STEREO")
    }

    @Test("Raw value for mono is CH-MONO")
    func monoRawValue() {
        #expect(VideoChannelLayout.mono.rawValue == "CH-MONO")
    }

    @Test("CaseIterable includes all cases")
    func caseIterable() {
        let allCases = VideoChannelLayout.allCases
        #expect(allCases.count == 2)
        #expect(allCases.contains(.stereoLeftRight))
        #expect(allCases.contains(.mono))
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = VideoChannelLayout.stereoLeftRight
        let b = VideoChannelLayout.stereoLeftRight
        let c = VideoChannelLayout.mono
        #expect(a == b)
        #expect(a != c)
    }
}
