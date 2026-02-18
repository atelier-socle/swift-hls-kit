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
public struct HLSValidator: Sendable {

    /// Creates an HLS validator.
    public init() {}

    /// Validates a manifest against all rule sets.
    ///
    /// - Parameter manifest: The manifest to validate.
    /// - Returns: A ``ValidationReport`` containing all findings.
    public func validate(_ manifest: Manifest) -> ValidationReport {
        switch manifest {
        case .master(let playlist):
            return validate(playlist)
        case .media(let playlist):
            return validate(playlist)
        }
    }

    /// Validates a master playlist against all rule sets.
    ///
    /// - Parameter playlist: The master playlist to validate.
    /// - Returns: A ``ValidationReport`` containing all findings.
    public func validate(_ playlist: MasterPlaylist) -> ValidationReport {
        var results: [ValidationResult] = []
        results += RFC8216Rules.validate(playlist)
        results += AppleHLSRules.validate(playlist)
        return ValidationReport(results: results)
    }

    /// Validates a media playlist against all rule sets.
    ///
    /// - Parameter playlist: The media playlist to validate.
    /// - Returns: A ``ValidationReport`` containing all findings.
    public func validate(_ playlist: MediaPlaylist) -> ValidationReport {
        var results: [ValidationResult] = []
        results += RFC8216Rules.validate(playlist)
        results += AppleHLSRules.validate(playlist)
        return ValidationReport(results: results)
    }
}
