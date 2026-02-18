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

    /// Validates a manifest against all rule sets.
    ///
    /// - Parameter manifest: The manifest to validate.
    /// - Returns: A ``ValidationReport`` containing all findings.
    public func validate(_ manifest: Manifest) -> ValidationReport {
        validator.validate(manifest)
    }

    /// Validates a master playlist against all rule sets.
    ///
    /// - Parameter playlist: The master playlist to validate.
    /// - Returns: A ``ValidationReport``.
    public func validate(_ playlist: MasterPlaylist) -> ValidationReport {
        validator.validate(playlist)
    }

    /// Validates a media playlist against all rule sets.
    ///
    /// - Parameter playlist: The media playlist to validate.
    /// - Returns: A ``ValidationReport``.
    public func validate(_ playlist: MediaPlaylist) -> ValidationReport {
        validator.validate(playlist)
    }

    // MARK: - Combined Workflows

    /// Parses a manifest and validates it in one operation.
    ///
    /// - Parameter string: The M3U8 text.
    /// - Returns: A tuple containing the parsed manifest and its validation report.
    /// - Throws: ``ParserError`` if the input is invalid.
    public func parseAndValidate(
        _ string: String
    ) throws(ParserError) -> (manifest: Manifest, report: ValidationReport) {
        let manifest = try parser.parse(string)
        let report = validator.validate(manifest)
        return (manifest, report)
    }
}
