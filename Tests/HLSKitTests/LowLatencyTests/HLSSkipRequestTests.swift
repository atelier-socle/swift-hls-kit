// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("HLSSkipRequest", .timeLimit(.minutes(1)))
struct HLSSkipRequestTests {

    @Test("Raw value for .yes is YES")
    func yesRawValue() {
        #expect(HLSSkipRequest.yes.rawValue == "YES")
    }

    @Test("Raw value for .v2 is v2")
    func v2RawValue() {
        #expect(HLSSkipRequest.v2.rawValue == "v2")
    }

    @Test("skipDateRanges is true for v2")
    func v2SkipDateRanges() {
        #expect(HLSSkipRequest.v2.skipDateRanges == true)
    }

    @Test("skipDateRanges is false for yes")
    func yesSkipDateRanges() {
        #expect(HLSSkipRequest.yes.skipDateRanges == false)
    }

    @Test("Init from raw value YES")
    func initFromYes() {
        let request = HLSSkipRequest(rawValue: "YES")
        #expect(request == .yes)
    }

    @Test("Init from raw value v2")
    func initFromV2() {
        let request = HLSSkipRequest(rawValue: "v2")
        #expect(request == .v2)
    }

    @Test("Init from invalid raw value returns nil")
    func initFromInvalid() {
        let request = HLSSkipRequest(rawValue: "invalid")
        #expect(request == nil)
    }
}
