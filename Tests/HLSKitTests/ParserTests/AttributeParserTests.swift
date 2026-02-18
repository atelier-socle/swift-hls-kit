// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("AttributeParser — Attribute List Parsing")
struct AttributeParserListTests {

    let parser = AttributeParser()

    @Test("Parse empty attribute string")
    func emptyString() {
        let result = parser.parseAttributes("")
        #expect(result.isEmpty)
    }

    @Test("Parse single unquoted attribute")
    func singleUnquoted() {
        let result = parser.parseAttributes("BANDWIDTH=800000")
        #expect(result["BANDWIDTH"] == "800000")
    }

    @Test("Parse single quoted attribute")
    func singleQuoted() {
        let result = parser.parseAttributes("URI=\"segment.ts\"")
        #expect(result["URI"] == "segment.ts")
    }

    @Test("Parse multiple attributes — full EXT-X-STREAM-INF")
    func fullStreamInf() {
        let input =
            "BANDWIDTH=2800000,AVERAGE-BANDWIDTH=2200000,"
            + "RESOLUTION=1280x720,FRAME-RATE=30.000,"
            + "CODECS=\"avc1.4d401f,mp4a.40.2\",AUDIO=\"audio-aac\""
        let result = parser.parseAttributes(input)
        #expect(result["BANDWIDTH"] == "2800000")
        #expect(result["AVERAGE-BANDWIDTH"] == "2200000")
        #expect(result["RESOLUTION"] == "1280x720")
        #expect(result["FRAME-RATE"] == "30.000")
        #expect(result["CODECS"] == "avc1.4d401f,mp4a.40.2")
        #expect(result["AUDIO"] == "audio-aac")
    }

    @Test("Parse resolution value")
    func parseResolution() {
        let result = parser.parseAttributes("RESOLUTION=1920x1080")
        #expect(result["RESOLUTION"] == "1920x1080")
    }

    @Test("Parse hexadecimal value")
    func parseHex() {
        let result = parser.parseAttributes("IV=0x00000000000000000000000000000001")
        #expect(result["IV"] == "0x00000000000000000000000000000001")
    }

    @Test("Parse quoted string containing commas — CODECS")
    func quotedWithCommas() {
        let result = parser.parseAttributes("CODECS=\"avc1.4d401e,mp4a.40.2\"")
        #expect(result["CODECS"] == "avc1.4d401e,mp4a.40.2")
    }

    @Test("Trailing comma is ignored")
    func trailingComma() {
        let result = parser.parseAttributes("BANDWIDTH=800000,")
        #expect(result["BANDWIDTH"] == "800000")
        #expect(result.count == 1)
    }

    @Test("Empty value is preserved")
    func emptyValue() {
        let result = parser.parseAttributes("KEY=")
        #expect(result["KEY"] == "")
    }

    @Test("Missing equals sign skips entry")
    func missingEquals() {
        let result = parser.parseAttributes("NOEQUALSSIGN")
        #expect(result.isEmpty)
    }

    @Test("Unknown X- attributes are preserved")
    func customAttributes() {
        let result = parser.parseAttributes("X-CUSTOM=\"hello\",BANDWIDTH=100")
        #expect(result["X-CUSTOM"] == "hello")
        #expect(result["BANDWIDTH"] == "100")
    }
}

// MARK: - Typed Extraction

@Suite("AttributeParser — Typed Extraction")
struct AttributeParserExtractionTests {

    let parser = AttributeParser()

    // MARK: - Required

    @Test("requiredInteger succeeds for valid value")
    func requiredIntegerSuccess() throws {
        let attrs = ["BANDWIDTH": "800000"]
        let value = try parser.requiredInteger("BANDWIDTH", from: attrs, tag: "TEST")
        #expect(value == 800_000)
    }

    @Test("requiredInteger throws for missing key")
    func requiredIntegerMissing() {
        let attrs: [String: String] = [:]
        #expect(throws: ParserError.self) {
            try parser.requiredInteger("BANDWIDTH", from: attrs, tag: "TEST")
        }
    }

    @Test("requiredInteger throws for non-integer value")
    func requiredIntegerInvalid() {
        let attrs = ["BANDWIDTH": "abc"]
        #expect(throws: ParserError.self) {
            try parser.requiredInteger("BANDWIDTH", from: attrs, tag: "TEST")
        }
    }

    @Test("requiredDouble succeeds for valid value")
    func requiredDoubleSuccess() throws {
        let attrs = ["DURATION": "6.006"]
        let value = try parser.requiredDouble("DURATION", from: attrs, tag: "TEST")
        #expect(value == 6.006)
    }

    @Test("requiredQuotedString succeeds for present key")
    func requiredQuotedStringSuccess() throws {
        let attrs = ["URI": "segment.ts"]
        let value = try parser.requiredQuotedString("URI", from: attrs, tag: "TEST")
        #expect(value == "segment.ts")
    }

    @Test("requiredQuotedString throws for missing key")
    func requiredQuotedStringMissing() {
        let attrs: [String: String] = [:]
        #expect(throws: ParserError.self) {
            try parser.requiredQuotedString("URI", from: attrs, tag: "TEST")
        }
    }

    @Test("requiredEnumString succeeds for present key")
    func requiredEnumSuccess() throws {
        let attrs = ["TYPE": "AUDIO"]
        let value = try parser.requiredEnumString("TYPE", from: attrs, tag: "TEST")
        #expect(value == "AUDIO")
    }

    // MARK: - Optional

    @Test("optionalInteger returns value when present")
    func optionalIntegerPresent() {
        let attrs = ["BANDWIDTH": "500000"]
        #expect(parser.optionalInteger("BANDWIDTH", from: attrs) == 500_000)
    }

    @Test("optionalInteger returns nil when absent")
    func optionalIntegerAbsent() {
        let attrs: [String: String] = [:]
        #expect(parser.optionalInteger("BANDWIDTH", from: attrs) == nil)
    }

    @Test("optionalDouble returns value when present")
    func optionalDoublePresent() {
        let attrs = ["FRAME-RATE": "29.970"]
        #expect(parser.optionalDouble("FRAME-RATE", from: attrs) == 29.970)
    }

    @Test("optionalDouble returns nil when absent")
    func optionalDoubleAbsent() {
        #expect(parser.optionalDouble("MISSING", from: [:]) == nil)
    }

    @Test("optionalQuotedString returns value when present")
    func optionalQuotedPresent() {
        let attrs = ["CODECS": "avc1.4d401f"]
        #expect(parser.optionalQuotedString("CODECS", from: attrs) == "avc1.4d401f")
    }

    @Test("optionalQuotedString returns nil when absent")
    func optionalQuotedAbsent() {
        #expect(parser.optionalQuotedString("MISSING", from: [:]) == nil)
    }

    @Test("optionalResolution parses WIDTHxHEIGHT")
    func optionalResolutionValid() {
        let attrs = ["RESOLUTION": "1920x1080"]
        let resolution = parser.optionalResolution("RESOLUTION", from: attrs)
        #expect(resolution == .p1080)
    }

    @Test("optionalResolution returns nil for invalid format")
    func optionalResolutionInvalid() {
        let attrs = ["RESOLUTION": "invalid"]
        #expect(parser.optionalResolution("RESOLUTION", from: attrs) == nil)
    }

    @Test("optionalResolution returns nil when absent")
    func optionalResolutionAbsent() {
        #expect(parser.optionalResolution("RESOLUTION", from: [:]) == nil)
    }

    @Test("optionalHex returns hex string when present")
    func optionalHexPresent() {
        let attrs = ["IV": "0xABCD"]
        #expect(parser.optionalHex("IV", from: attrs) == "0xABCD")
    }

    @Test("optionalBool returns true for YES")
    func optionalBoolYes() {
        let attrs = ["DEFAULT": "YES"]
        #expect(parser.optionalBool("DEFAULT", from: attrs) == true)
    }

    @Test("optionalBool returns false for NO")
    func optionalBoolNo() {
        let attrs = ["DEFAULT": "NO"]
        #expect(parser.optionalBool("DEFAULT", from: attrs) == false)
    }

    @Test("optionalBool returns nil when absent")
    func optionalBoolAbsent() {
        #expect(parser.optionalBool("MISSING", from: [:]) == nil)
    }

    @Test("optionalEnumString returns value when present")
    func optionalEnumPresent() {
        let attrs = ["METHOD": "AES-128"]
        #expect(parser.optionalEnumString("METHOD", from: attrs) == "AES-128")
    }
}
