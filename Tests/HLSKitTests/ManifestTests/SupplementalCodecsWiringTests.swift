// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("SupplementalCodecs Wiring")
struct SupplementalCodecsWiringTests {

    @Test("supplementalCodecsValue get from String")
    func getFromString() {
        let variant = Variant(
            bandwidth: 8_000_000,
            uri: "video.m3u8",
            supplementalCodecs: "dvh1.20.09/db4h"
        )
        let value = variant.supplementalCodecsValue
        #expect(value == SupplementalCodecs("dvh1.20.09/db4h"))
        #expect(value?.value == "dvh1.20.09/db4h")
    }

    @Test("supplementalCodecsValue get returns nil when string nil")
    func getNilWhenStringNil() {
        let variant = Variant(
            bandwidth: 2_000_000, uri: "video.m3u8"
        )
        #expect(variant.supplementalCodecsValue == nil)
    }

    @Test("supplementalCodecsValue set updates string")
    func setUpdatesString() {
        var variant = Variant(
            bandwidth: 8_000_000, uri: "video.m3u8"
        )
        variant.supplementalCodecsValue = .dolbyVisionProfile20
        #expect(variant.supplementalCodecs == "dvh1.20.09/db4h")
    }

    @Test("supplementalCodecsValue set nil clears string")
    func setNilClearsString() {
        var variant = Variant(
            bandwidth: 8_000_000, uri: "video.m3u8",
            supplementalCodecs: "dvh1.20.09/db4h"
        )
        variant.supplementalCodecsValue = nil
        #expect(variant.supplementalCodecs == nil)
    }

    @Test("Round-trip with DV Profile 8 preset")
    func roundTripDVProfile8() {
        var variant = Variant(
            bandwidth: 8_000_000, uri: "video.m3u8"
        )
        variant.supplementalCodecsValue = .dolbyVisionProfile8
        let readBack = variant.supplementalCodecsValue
        #expect(readBack?.value == "dvh1.08.09/db4h")
        #expect(
            variant.supplementalCodecs == "dvh1.08.09/db4h"
        )
    }
}
