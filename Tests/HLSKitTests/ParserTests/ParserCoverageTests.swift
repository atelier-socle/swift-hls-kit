// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - TagParser Coverage

@Suite("TagParser — Coverage Gaps")
struct TagParserCoverageTests {

    let parser = TagParser()

    @Test("parseByteRange — invalid length throws")
    func byteRangeInvalidLength() {
        #expect(throws: ParserError.self) {
            try parser.parseByteRange("abc")
        }
    }

    @Test("parseByteRange — invalid offset throws")
    func byteRangeInvalidOffset() {
        #expect(throws: ParserError.self) {
            try parser.parseByteRange("1024@abc")
        }
    }

    @Test("parseKey — invalid METHOD throws")
    func keyInvalidMethod() {
        #expect(throws: ParserError.self) {
            try parser.parseKey("METHOD=INVALID")
        }
    }

    @Test("parseDateRange — invalid START-DATE throws")
    func dateRangeInvalidStartDate() {
        #expect(throws: ParserError.self) {
            try parser.parseDateRange(
                "ID=\"dr\",START-DATE=\"not-a-date\""
            )
        }
    }

    @Test("parseDateRange — with END-DATE")
    func dateRangeWithEndDate() throws {
        let result = try parser.parseDateRange(
            "ID=\"dr\","
                + "START-DATE=\"2026-01-01T00:00:00.000Z\","
                + "END-DATE=\"2026-01-01T01:00:00.000Z\""
        )
        #expect(result.endDate != nil)
    }

    @Test("parseProgramDateTime — invalid date throws")
    func programDateTimeInvalid() {
        #expect(throws: ParserError.self) {
            try parser.parseProgramDateTime("not-a-date")
        }
    }

    @Test("parseStreamInf — with CLOSED-CAPTIONS NONE")
    func streamInfCCNone() throws {
        let result = try parser.parseStreamInf(
            "BANDWIDTH=800000,CLOSED-CAPTIONS=NONE"
        )
        #expect(result.closedCaptions == ClosedCaptionsValue.none)
    }

    @Test("parseStreamInf — with CLOSED-CAPTIONS group")
    func streamInfCCGroup() throws {
        let result = try parser.parseStreamInf(
            "BANDWIDTH=800000,CLOSED-CAPTIONS=\"cc1\""
        )
        #expect(result.closedCaptions == .groupId("cc1"))
    }

    @Test("parseIFrameStreamInf — with HDCP-LEVEL")
    func iFrameStreamInfHDCP() throws {
        let result = try parser.parseIFrameStreamInf(
            "BANDWIDTH=200000,URI=\"iframe.m3u8\","
                + "HDCP-LEVEL=TYPE-1"
        )
        #expect(result.hdcpLevel == .type1)
    }

    @Test("parseMedia — invalid TYPE throws")
    func mediaInvalidType() {
        #expect(throws: ParserError.self) {
            try parser.parseMedia(
                "TYPE=INVALID,GROUP-ID=\"g\",NAME=\"n\""
            )
        }
    }

    @Test("parseSessionKey — delegates to parseKey")
    func sessionKey() throws {
        let result = try parser.parseSessionKey(
            "METHOD=AES-128,URI=\"key.bin\""
        )
        #expect(result.method == .aes128)
        #expect(result.uri == "key.bin")
    }
}

// MARK: - AttributeParser Coverage

@Suite("AttributeParser — Coverage Gaps")
struct AttributeParserCoverageTests {

    let parser = AttributeParser()

    @Test("parseAttributes — unclosed quote fallback")
    func unclosedQuote() {
        let attrs = parser.parseAttributes(
            "KEY=\"unclosed value"
        )
        #expect(attrs["KEY"] == "unclosed value")
    }

    @Test("requiredInteger — missing key throws")
    func requiredIntegerMissing() {
        #expect(throws: ParserError.self) {
            try parser.requiredInteger(
                "X", from: [:], tag: "TEST"
            )
        }
    }

    @Test("requiredInteger — invalid value throws")
    func requiredIntegerInvalid() {
        #expect(throws: ParserError.self) {
            try parser.requiredInteger(
                "X", from: ["X": "abc"], tag: "TEST"
            )
        }
    }

    @Test("requiredDouble — missing key throws")
    func requiredDoubleMissing() {
        #expect(throws: ParserError.self) {
            try parser.requiredDouble(
                "X", from: [:], tag: "TEST"
            )
        }
    }

    @Test("requiredEnumString — missing key throws")
    func requiredEnumStringMissing() {
        #expect(throws: ParserError.self) {
            try parser.requiredEnumString(
                "X", from: [:], tag: "TEST"
            )
        }
    }

    @Test("parseDecimalInteger — invalid throws")
    func parseDecimalIntegerInvalid() {
        #expect(throws: ParserError.self) {
            try parser.parseDecimalInteger(
                "abc", attribute: "X"
            )
        }
    }

    @Test("parseDecimalFloat — invalid throws")
    func parseDecimalFloatInvalid() {
        #expect(throws: ParserError.self) {
            try parser.parseDecimalFloat(
                "abc", attribute: "X"
            )
        }
    }

    @Test("parseResolution — invalid throws")
    func parseResolutionInvalid() {
        #expect(throws: ParserError.self) {
            try parser.parseResolution(
                "not-a-res", attribute: "X"
            )
        }
    }
}
