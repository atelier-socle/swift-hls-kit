// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The severity level of a validation finding.
///
/// Severity determines how a finding affects the overall validity of
/// a manifest. Only ``error`` findings cause the manifest to be
/// considered invalid.
public enum ValidationSeverity: Int, Sendable, Hashable, Codable, Comparable, CaseIterable {

    /// Informational finding. Does not affect validity.
    case info = 0

    /// A potential issue that should be reviewed.
    case warning = 1

    /// A specification violation that makes the manifest non-compliant.
    case error = 2

    // MARK: - Comparable

    public static func < (lhs: ValidationSeverity, rhs: ValidationSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A single validation finding.
///
/// Each result identifies a specific issue found during validation,
/// including its severity, a human-readable message, the field or
/// tag where the issue was found, and the rule that flagged it.
public struct ValidationResult: Sendable, Hashable, Codable {

    /// The severity of this finding.
    public let severity: ValidationSeverity

    /// A human-readable description of the issue.
    public let message: String

    /// A dot-path identifying the location of the issue
    /// (e.g., `"variants[0].bandwidth"`, `"segments[3].duration"`).
    public let field: String

    /// The rule set that produced this finding.
    public let ruleSet: ValidationRuleSet?

    /// The specific rule identifier (e.g., `"RFC8216-4.3.4.2"`).
    public let ruleId: String?

    /// Creates a validation result.
    ///
    /// - Parameters:
    ///   - severity: The severity level.
    ///   - message: A description of the issue.
    ///   - field: The location of the issue.
    ///   - ruleSet: The optional rule set that found the issue.
    ///   - ruleId: The specific rule identifier.
    public init(
        severity: ValidationSeverity,
        message: String,
        field: String,
        ruleSet: ValidationRuleSet? = nil,
        ruleId: String? = nil
    ) {
        self.severity = severity
        self.message = message
        self.field = field
        self.ruleSet = ruleSet
        self.ruleId = ruleId
    }
}

/// The rule set used for validation.
public enum ValidationRuleSet: String, Sendable, Hashable, Codable, CaseIterable {

    /// Rules derived from RFC 8216.
    case rfc8216

    /// Rules from the Apple HLS Authoring Specification.
    case appleHLS
}

/// A validation report summarizing all findings for a manifest.
///
/// The report aggregates all ``ValidationResult`` items and provides
/// convenience accessors for filtering by severity.
public struct ValidationReport: Sendable, Hashable, Codable {

    /// Which rule set was applied during validation.
    public let ruleSet: RuleSet

    /// All validation results, sorted by severity (errors first).
    public let results: [ValidationResult]

    /// Creates a validation report.
    ///
    /// - Parameters:
    ///   - ruleSet: The rule set used for validation.
    ///   - results: The validation results. They will be
    ///     sorted by severity in descending order.
    public init(
        ruleSet: RuleSet = .all,
        results: [ValidationResult] = []
    ) {
        self.ruleSet = ruleSet
        self.results = results.sorted { $0.severity > $1.severity }
    }

    /// Whether the manifest is valid (no error-level findings).
    public var isValid: Bool {
        errors.isEmpty
    }

    /// All error-level findings.
    public var errors: [ValidationResult] {
        results.filter { $0.severity == .error }
    }

    /// All warning-level findings.
    public var warnings: [ValidationResult] {
        results.filter { $0.severity == .warning }
    }

    /// All informational findings.
    public var infos: [ValidationResult] {
        results.filter { $0.severity == .info }
    }

    /// The rule sets available for validation.
    public enum RuleSet: String, Sendable, Hashable, Codable, CaseIterable {

        /// Only RFC 8216 rules.
        case rfc8216

        /// Only Apple HLS Authoring Spec rules.
        case appleHLS

        /// Both RFC 8216 and Apple HLS rules.
        case all
    }
}
