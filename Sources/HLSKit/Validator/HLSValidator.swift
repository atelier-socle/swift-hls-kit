// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validates HLS manifests against RFC 8216 and Apple HLS Authoring rules.
///
/// The validator checks a parsed ``Manifest`` for compliance issues
/// and returns a ``ValidationReport`` containing all findings.
///
/// ```swift
/// let validator = HLSValidator()
/// let report = validator.validate(manifest)
/// print("Valid: \(report.isValid)")
/// for issue in report.results {
///     print("[\(issue.severity)] \(issue.field): \(issue.message)")
/// }
/// ```
///
/// - SeeAlso: RFC 8216, Apple HLS Authoring Specification
public struct HLSValidator: Sendable {

    /// Creates an HLS validator.
    public init() {}

    /// Validates a manifest against the specified rule set.
    ///
    /// - Parameters:
    ///   - manifest: The manifest to validate.
    ///   - ruleSet: Which rules to apply (default: `.all`).
    /// - Returns: A ``ValidationReport`` containing all findings.
    public func validate(
        _ manifest: Manifest,
        ruleSet: ValidationReport.RuleSet = .all
    ) -> ValidationReport {
        switch manifest {
        case .master(let playlist):
            return validate(playlist, ruleSet: ruleSet)
        case .media(let playlist):
            return validate(playlist, ruleSet: ruleSet)
        }
    }

    /// Validates a master playlist against the specified rule set.
    ///
    /// - Parameters:
    ///   - playlist: The master playlist to validate.
    ///   - ruleSet: Which rules to apply (default: `.all`).
    /// - Returns: A ``ValidationReport`` containing all findings.
    public func validate(
        _ playlist: MasterPlaylist,
        ruleSet: ValidationReport.RuleSet = .all
    ) -> ValidationReport {
        let results = collectMasterResults(playlist, ruleSet: ruleSet)
        return ValidationReport(ruleSet: ruleSet, results: results)
    }

    /// Validates a media playlist against the specified rule set.
    ///
    /// - Parameters:
    ///   - playlist: The media playlist to validate.
    ///   - ruleSet: Which rules to apply (default: `.all`).
    /// - Returns: A ``ValidationReport`` containing all findings.
    public func validate(
        _ playlist: MediaPlaylist,
        ruleSet: ValidationReport.RuleSet = .all
    ) -> ValidationReport {
        let results = collectMediaResults(playlist, ruleSet: ruleSet)
        return ValidationReport(ruleSet: ruleSet, results: results)
    }

    /// Parses and validates an M3U8 string in one step.
    ///
    /// - Parameters:
    ///   - string: The M3U8 manifest content.
    ///   - ruleSet: Which rules to apply (default: `.all`).
    /// - Returns: A ``ValidationReport`` containing all findings.
    /// - Throws: ``ParserError`` if parsing fails.
    public func validateString(
        _ string: String,
        ruleSet: ValidationReport.RuleSet = .all
    ) throws(ParserError) -> ValidationReport {
        let parser = ManifestParser()
        let manifest = try parser.parse(string)
        return validate(manifest, ruleSet: ruleSet)
    }

    // MARK: - Private Helpers

    private func collectMasterResults(
        _ playlist: MasterPlaylist,
        ruleSet: ValidationReport.RuleSet
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if ruleSet == .rfc8216 || ruleSet == .all {
            results += RFC8216Rules.validate(playlist)
        }
        if ruleSet == .appleHLS || ruleSet == .all {
            results += AppleHLSRules.validate(playlist)
        }
        return results
    }

    private func collectMediaResults(
        _ playlist: MediaPlaylist,
        ruleSet: ValidationReport.RuleSet
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if ruleSet == .rfc8216 || ruleSet == .all {
            results += RFC8216Rules.validate(playlist)
        }
        if ruleSet == .appleHLS || ruleSet == .all {
            results += AppleHLSRules.validate(playlist)
        }
        return results
    }
}
