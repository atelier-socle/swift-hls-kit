// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A high-level facade that combines parsing, generation, and validation.
///
/// ``HLSEngine`` provides a single entry point for the most common
/// HLS manifest operations. It delegates to ``ManifestParser``,
/// ``ManifestGenerator``, and ``HLSValidator`` internally.
///
/// ```swift
/// let engine = HLSEngine()
///
/// // Parse
/// let manifest = try engine.parse(m3u8String)
///
/// // Generate
/// let output = engine.generate(manifest)
///
/// // Validate
/// let report = engine.validate(manifest)
///
/// // Parse + validate in one step
/// let (parsed, validation) = try engine.parseAndValidate(m3u8String)
/// ```
public struct HLSEngine: Sendable {

    /// The manifest parser.
    private let parser: ManifestParser

    /// The manifest generator.
    private let generator: ManifestGenerator

    /// The manifest validator.
    private let validator: HLSValidator

    /// Creates an HLS engine with default components.
    public init() {
        self.parser = ManifestParser()
        self.generator = ManifestGenerator()
        self.validator = HLSValidator()
    }

    // MARK: - Parsing

    /// Parses an M3U8 manifest string.
    ///
    /// - Parameter string: The M3U8 text.
    /// - Returns: A ``Manifest`` value.
    /// - Throws: ``ParserError`` if the input is invalid.
    public func parse(_ string: String) throws(ParserError) -> Manifest {
        try parser.parse(string)
    }

    // MARK: - Generation

    /// Generates an M3U8 string from a manifest.
    ///
    /// - Parameter manifest: The manifest to serialize.
    /// - Returns: The M3U8 text string.
    public func generate(_ manifest: Manifest) -> String {
        generator.generate(manifest)
    }

    /// Generates an M3U8 string from a master playlist.
    ///
    /// - Parameter playlist: The master playlist.
    /// - Returns: The M3U8 text string.
    public func generate(_ playlist: MasterPlaylist) -> String {
        generator.generateMaster(playlist)
    }

    /// Generates an M3U8 string from a media playlist.
    ///
    /// - Parameter playlist: The media playlist.
    /// - Returns: The M3U8 text string.
    public func generate(_ playlist: MediaPlaylist) -> String {
        generator.generateMedia(playlist)
    }

    // MARK: - Validation

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
        validator.validate(manifest, ruleSet: ruleSet)
    }

    /// Validates a master playlist against the specified rule set.
    ///
    /// - Parameters:
    ///   - playlist: The master playlist to validate.
    ///   - ruleSet: Which rules to apply (default: `.all`).
    /// - Returns: A ``ValidationReport``.
    public func validate(
        _ playlist: MasterPlaylist,
        ruleSet: ValidationReport.RuleSet = .all
    ) -> ValidationReport {
        validator.validate(playlist, ruleSet: ruleSet)
    }

    /// Validates a media playlist against the specified rule set.
    ///
    /// - Parameters:
    ///   - playlist: The media playlist to validate.
    ///   - ruleSet: Which rules to apply (default: `.all`).
    /// - Returns: A ``ValidationReport``.
    public func validate(
        _ playlist: MediaPlaylist,
        ruleSet: ValidationReport.RuleSet = .all
    ) -> ValidationReport {
        validator.validate(playlist, ruleSet: ruleSet)
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
        try validator.validateString(string, ruleSet: ruleSet)
    }

    // MARK: - Combined Workflows

    /// Parses a manifest and validates it in one operation.
    ///
    /// - Parameters:
    ///   - string: The M3U8 text.
    ///   - ruleSet: Which rules to apply (default: `.all`).
    /// - Returns: A tuple of the parsed manifest and its validation report.
    /// - Throws: ``ParserError`` if the input is invalid.
    public func parseAndValidate(
        _ string: String,
        ruleSet: ValidationReport.RuleSet = .all
    ) throws(ParserError) -> (manifest: Manifest, report: ValidationReport) {
        let manifest = try parser.parse(string)
        let report = validator.validate(manifest, ruleSet: ruleSet)
        return (manifest, report)
    }

    /// Parses an M3U8 string and regenerates it.
    ///
    /// This performs a round-trip: parse → generate. Useful for
    /// normalizing or cleaning up M3U8 manifests.
    ///
    /// - Parameter string: The M3U8 text to regenerate.
    /// - Returns: The regenerated M3U8 text.
    /// - Throws: ``ParserError`` if the input is invalid.
    public func regenerate(
        _ string: String
    ) throws(ParserError) -> String {
        let manifest = try parser.parse(string)
        return generator.generate(manifest)
    }
}
