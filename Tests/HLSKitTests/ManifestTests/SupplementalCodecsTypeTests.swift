// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SupplementalCodecs Type")
struct SupplementalCodecsTypeTests {

    @Test("Init stores value")
    func initValue() {
        let codecs = SupplementalCodecs("dvh1.05.06")
        #expect(codecs.value == "dvh1.05.06")
    }

    @Test("Description returns value")
    func descriptionReturnsValue() {
        let codecs = SupplementalCodecs("dvh1.08.09/db4h")
        #expect(codecs.description == "dvh1.08.09/db4h")
        #expect("\(codecs)" == "dvh1.08.09/db4h")
    }

    @Test("Dolby Vision Profile 20 preset")
    func dolbyVisionProfile20() {
        let codecs = SupplementalCodecs.dolbyVisionProfile20
        #expect(codecs.value == "dvh1.20.09/db4h")
    }

    @Test("Dolby Vision Profile 8 preset")
    func dolbyVisionProfile8() {
        let codecs = SupplementalCodecs.dolbyVisionProfile8
        #expect(codecs.value == "dvh1.08.09/db4h")
    }

    @Test("Equatable conformance")
    func equatable() {
        let a = SupplementalCodecs.dolbyVisionProfile20
        let b = SupplementalCodecs("dvh1.20.09/db4h")
        let c = SupplementalCodecs.dolbyVisionProfile8
        #expect(a == b)
        #expect(a != c)
    }
}
