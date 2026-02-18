// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validation rules derived from RFC 8216 — HTTP Live Streaming.
///
/// These rules check that a manifest conforms to the requirements
/// and constraints specified in the HLS standard.
enum RFC8216Rules {

    /// Validates a master playlist against RFC 8216 rules.
    ///
    /// - Parameter playlist: The master playlist to validate.
    /// - Returns: An array of validation results.
    static func validate(_ playlist: MasterPlaylist) -> [ValidationResult] {
        var results: [ValidationResult] = []
        results += validateVariants(playlist.variants)
        results += validateRenditions(playlist.renditions)
        return results
    }

    /// Validates a media playlist against RFC 8216 rules.
    ///
    /// - Parameter playlist: The media playlist to validate.
    /// - Returns: An array of validation results.
    static func validate(_ playlist: MediaPlaylist) -> [ValidationResult] {
        var results: [ValidationResult] = []
        results += validateTargetDuration(playlist)
        results += validateSegments(playlist.segments)
        return results
    }

    // MARK: - Master Playlist Rules

    /// Validates that variants have required attributes.
    private static func validateVariants(_ variants: [Variant]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if variants.isEmpty {
            results.append(
                ValidationResult(
                    severity: .error,
                    message: "Master playlist must contain at least one variant stream.",
                    field: "variants",
                    ruleSet: .rfc8216
                ))
        }
        for (index, variant) in variants.enumerated() where variant.bandwidth <= 0 {
            results.append(
                ValidationResult(
                    severity: .error,
                    message: "BANDWIDTH must be a positive integer.",
                    field: "variants[\(index)].bandwidth",
                    ruleSet: .rfc8216
                ))
        }
        return results
    }

    /// Validates rendition groups.
    private static func validateRenditions(_ renditions: [Rendition]) -> [ValidationResult] {
        // Stub — detailed rendition validation in a later session.
        []
    }

    // MARK: - Media Playlist Rules

    /// Validates that no segment exceeds the target duration.
    private static func validateTargetDuration(_ playlist: MediaPlaylist) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (index, segment) in playlist.segments.enumerated()
        where Int(segment.duration.rounded(.up)) > playlist.targetDuration {
            results.append(
                ValidationResult(
                    severity: .error,
                    message: "Segment duration \(segment.duration)s exceeds target duration \(playlist.targetDuration)s.",
                    field: "segments[\(index)].duration",
                    ruleSet: .rfc8216
                ))
        }
        return results
    }

    /// Validates individual segments.
    private static func validateSegments(_ segments: [Segment]) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (index, segment) in segments.enumerated() {
            if segment.duration < 0 {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message: "Segment duration must not be negative.",
                        field: "segments[\(index)].duration",
                        ruleSet: .rfc8216
                    ))
            }
            if segment.uri.isEmpty {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message: "Segment URI must not be empty.",
                        field: "segments[\(index)].uri",
                        ruleSet: .rfc8216
                    ))
            }
        }
        return results
    }
}
