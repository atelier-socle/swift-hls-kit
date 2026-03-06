// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite(
    "Variable Validation Rules",
    .timeLimit(.minutes(1))
)
struct VariableValidationTests {

    private let validator = HLSValidator()

    @Test("Undefined variable reference produces error")
    func undefinedVariableError() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "{$undefined}/low.m3u8"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let varErrors = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-undefined"
        }
        #expect(!varErrors.isEmpty)
        #expect(varErrors[0].severity == .error)
    }

    @Test("Duplicate DEFINE names produce warning")
    func duplicateDefineWarning() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(name: "base", value: "a"),
                VariableDefinition(name: "base", value: "b")
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let dupes = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-duplicate"
        }
        #expect(dupes.count == 1)
        #expect(dupes[0].severity == .warning)
    }

    @Test("IMPORT in media playlist produces error")
    func importInMediaPlaylistError() {
        let playlist = MediaPlaylist(
            version: .v8,
            targetDuration: 6,
            segments: [
                Segment(duration: 6.0, uri: "seg1.ts")
            ],
            definitions: [
                VariableDefinition(name: "token", type: .import)
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let imports = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-import"
        }
        #expect(!imports.isEmpty)
        #expect(imports[0].severity == .error)
    }

    @Test("Circular reference detection")
    func circularReferenceError() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(name: "a", value: "{$b}"),
                VariableDefinition(name: "b", value: "{$a}")
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let circular = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-circular"
        }
        #expect(!circular.isEmpty)
    }

    @Test("Self-referencing variable produces error")
    func selfReferenceError() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(name: "x", value: "{$x}")
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let circular = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-circular"
        }
        #expect(!circular.isEmpty)
    }

    @Test("Valid definitions produce no variable errors")
    func validDefinitionsNoErrors() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "{$base}/low.m3u8"
                )
            ],
            definitions: [
                VariableDefinition(
                    name: "base",
                    value: "https://cdn.example.com"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let varErrors = report.results.filter {
            ($0.ruleId ?? "").hasPrefix("RFC8216bis-4.4.3.8")
        }
        #expect(varErrors.isEmpty)
    }

    @Test("Mixed valid and invalid produces correct counts")
    func mixedValidInvalid() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(
                    bandwidth: 800_000,
                    uri: "{$base}/{$missing}/low.m3u8"
                )
            ],
            definitions: [
                VariableDefinition(
                    name: "base",
                    value: "https://cdn.example.com"
                ),
                VariableDefinition(name: "base", value: "dupe")
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let undefined = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-undefined"
        }
        let dupes = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-duplicate"
        }
        #expect(undefined.count == 1)
        #expect(dupes.count == 1)
    }

    @Test("Manifest with no variables produces no variable errors")
    func noVariablesNoErrors() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let varResults = report.results.filter {
            ($0.ruleId ?? "").hasPrefix("RFC8216bis-4.4.3.8")
        }
        #expect(varResults.isEmpty)
    }

    @Test("QUERYPARAM validation passes in master playlist")
    func queryParamInMaster() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(
                    name: "token", type: .queryParam
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let imports = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-import"
        }
        #expect(imports.isEmpty)
    }

    @Test("Undefined variable in media segment URI")
    func undefinedInMediaSegmentURI() {
        let playlist = MediaPlaylist(
            version: .v8,
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0, uri: "{$missing}/seg1.ts"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let varErrors = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-undefined"
        }
        #expect(!varErrors.isEmpty)
    }

    @Test("Defined variable in media segment URI is valid")
    func definedInMediaSegmentURI() {
        let playlist = MediaPlaylist(
            version: .v8,
            targetDuration: 6,
            segments: [
                Segment(
                    duration: 6.0, uri: "{$path}/seg1.ts"
                )
            ],
            definitions: [
                VariableDefinition(
                    name: "path", value: "/live"
                )
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let varErrors = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-undefined"
        }
        #expect(varErrors.isEmpty)
    }

    @Test("IMPORT in master playlist does not produce import error")
    func importInMasterPlaylist() {
        let playlist = MasterPlaylist(
            version: .v8,
            variants: [
                Variant(bandwidth: 800_000, uri: "low.m3u8")
            ],
            definitions: [
                VariableDefinition(name: "auth", type: .import)
            ]
        )
        let report = validator.validate(playlist, ruleSet: .rfc8216)
        let imports = report.results.filter {
            $0.ruleId == "RFC8216bis-4.4.3.8-import"
        }
        #expect(imports.isEmpty)
    }
}
