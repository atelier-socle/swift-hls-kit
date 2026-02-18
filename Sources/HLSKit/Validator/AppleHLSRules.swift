// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validation rules derived from the Apple HLS Authoring Specification.
///
/// These rules check Apple-specific requirements such as codec
/// declarations, I-frame playlists, and audio group conventions.
enum AppleHLSRules {

    /// Validates a master playlist against Apple HLS authoring rules.
    ///
    /// - Parameter playlist: The master playlist to validate.
    /// - Returns: An array of validation results.
    static func validate(_ playlist: MasterPlaylist) -> [ValidationResult] {
        var results: [ValidationResult] = []
        results += validateCodecDeclarations(playlist.variants)
        return results
    }

    /// Validates a media playlist against Apple HLS authoring rules.
    ///
    /// - Parameter playlist: The media playlist to validate.
    /// - Returns: An array of validation results.
    static func validate(_ playlist: MediaPlaylist) -> [ValidationResult] {
        // Stub — Apple-specific media playlist rules in a later session.
        []
    }

    // MARK: - Private Helpers

    /// Validates that codec declarations are present for variants.
    private static func validateCodecDeclarations(_ variants: [Variant]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (index, variant) in variants.enumerated() where variant.codecs == nil {
            results.append(
                ValidationResult(
                    severity: .warning,
                    message: "Apple recommends including CODECS attribute for all variant streams.",
                    field: "variants[\(index)].codecs",
                    ruleSet: .appleHLS
                ))
        }
        return results
    }
}
