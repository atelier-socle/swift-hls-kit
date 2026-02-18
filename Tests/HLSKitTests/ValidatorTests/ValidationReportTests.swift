// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - ValidationSeverity Tests

@Suite("ValidationSeverity")
struct ValidationSeverityDetailTests {

    @Test("Ordering — info < warning < error")
    func ordering() {
        #expect(ValidationSeverity.info < .warning)
        #expect(ValidationSeverity.warning < .error)
        #expect(ValidationSeverity.info < .error)
    }

    @Test("CaseIterable — 3 cases")
    func allCases() {
        #expect(ValidationSeverity.allCases.count == 3)
    }

    @Test("Raw values — 0, 1, 2")
    func rawValues() {
        #expect(ValidationSeverity.info.rawValue == 0)
        #expect(ValidationSeverity.warning.rawValue == 1)
        #expect(ValidationSeverity.error.rawValue == 2)
    }

    @Test("Codable round-trip")
    func codable() throws {
        let original = ValidationSeverity.warning
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            ValidationSeverity.self, from: data
        )
        #expect(decoded == original)
    }

    @Test("Hashable — same values equal")
    func hashable() {
        #expect(
            ValidationSeverity.error.hashValue
                == ValidationSeverity.error.hashValue)
    }
}

// MARK: - ValidationResult Tests

@Suite("ValidationResult")
struct ValidationResultDetailTests {

    @Test("Init with all parameters")
    func initFull() {
        let result = ValidationResult(
            severity: .error,
            message: "Test message",
            field: "variants[0].bandwidth",
            ruleSet: .rfc8216,
            ruleId: "RFC8216-4.3.4.2-bandwidth"
        )
        #expect(result.severity == .error)
        #expect(result.message == "Test message")
        #expect(result.field == "variants[0].bandwidth")
        #expect(result.ruleSet == .rfc8216)
        #expect(result.ruleId == "RFC8216-4.3.4.2-bandwidth")
    }

    @Test("Init with defaults")
    func initDefaults() {
        let result = ValidationResult(
            severity: .info, message: "Info", field: "test"
        )
        #expect(result.ruleSet == nil)
        #expect(result.ruleId == nil)
    }

    @Test("Hashable — equal results hash equally")
    func hashable() {
        let a = ValidationResult(
            severity: .error, message: "msg", field: "f"
        )
        let b = ValidationResult(
            severity: .error, message: "msg", field: "f"
        )
        #expect(a == b)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Codable round-trip")
    func codable() throws {
        let original = ValidationResult(
            severity: .warning,
            message: "Missing CODECS",
            field: "variants[0].codecs",
            ruleSet: .appleHLS,
            ruleId: "APPLE-2.1-codecs"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            ValidationResult.self, from: data
        )
        #expect(decoded == original)
    }
}

// MARK: - ValidationRuleSet Tests

@Suite("ValidationRuleSet")
struct ValidationRuleSetDetailTests {

    @Test("CaseIterable — 2 cases")
    func allCases() {
        #expect(ValidationRuleSet.allCases.count == 2)
    }

    @Test("Raw values")
    func rawValues() {
        #expect(ValidationRuleSet.rfc8216.rawValue == "rfc8216")
        #expect(ValidationRuleSet.appleHLS.rawValue == "appleHLS")
    }

    @Test("Codable round-trip")
    func codable() throws {
        let original = ValidationRuleSet.rfc8216
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            ValidationRuleSet.self, from: data
        )
        #expect(decoded == original)
    }
}

// MARK: - ValidationReport Tests

@Suite("ValidationReport")
struct ValidationReportDetailTests {

    @Test("Empty report — isValid, no results")
    func emptyReport() {
        let report = ValidationReport()
        #expect(report.isValid == true)
        #expect(report.results.isEmpty)
        #expect(report.errors.isEmpty)
        #expect(report.warnings.isEmpty)
        #expect(report.infos.isEmpty)
        #expect(report.ruleSet == .all)
    }

    @Test("Report with only warnings — still valid")
    func warningsOnly() {
        let report = ValidationReport(results: [
            ValidationResult(
                severity: .warning, message: "W", field: "f"
            )
        ])
        #expect(report.isValid == true)
        #expect(report.warnings.count == 1)
        #expect(report.errors.isEmpty)
    }

    @Test("Report with errors — invalid")
    func withErrors() {
        let report = ValidationReport(results: [
            ValidationResult(
                severity: .error, message: "E", field: "f"
            )
        ])
        #expect(report.isValid == false)
        #expect(report.errors.count == 1)
    }

    @Test("Results sorted by severity descending")
    func sortedBySeverity() {
        let report = ValidationReport(results: [
            ValidationResult(
                severity: .info, message: "I", field: "a"
            ),
            ValidationResult(
                severity: .error, message: "E", field: "b"
            ),
            ValidationResult(
                severity: .warning, message: "W", field: "c"
            )
        ])
        #expect(report.results[0].severity == .error)
        #expect(report.results[1].severity == .warning)
        #expect(report.results[2].severity == .info)
    }

    @Test("RuleSet — 3 cases")
    func ruleSetCases() {
        #expect(ValidationReport.RuleSet.allCases.count == 3)
    }

    @Test("RuleSet — raw values")
    func ruleSetRawValues() {
        #expect(ValidationReport.RuleSet.rfc8216.rawValue == "rfc8216")
        #expect(ValidationReport.RuleSet.appleHLS.rawValue == "appleHLS")
        #expect(ValidationReport.RuleSet.all.rawValue == "all")
    }

    @Test("RuleSet preserved in report")
    func ruleSetPreserved() {
        let report = ValidationReport(ruleSet: .rfc8216)
        #expect(report.ruleSet == .rfc8216)
    }

    @Test("Codable round-trip")
    func codable() throws {
        let original = ValidationReport(
            ruleSet: .appleHLS,
            results: [
                ValidationResult(
                    severity: .warning,
                    message: "test",
                    field: "f",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-2.1"
                )
            ]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            ValidationReport.self, from: data
        )
        #expect(decoded == original)
    }

    @Test("Mixed severity filtering")
    func mixedFiltering() {
        let report = ValidationReport(results: [
            ValidationResult(
                severity: .error, message: "E1", field: "a"
            ),
            ValidationResult(
                severity: .error, message: "E2", field: "b"
            ),
            ValidationResult(
                severity: .warning, message: "W1", field: "c"
            ),
            ValidationResult(
                severity: .info, message: "I1", field: "d"
            )
        ])
        #expect(report.errors.count == 2)
        #expect(report.warnings.count == 1)
        #expect(report.infos.count == 1)
        #expect(report.results.count == 4)
    }
}
