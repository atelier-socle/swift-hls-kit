// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validation rules for `EXT-X-DEFINE` variable substitution.
///
/// Checks for undefined variable references, duplicate definitions,
/// unresolvable imports, and circular references per RFC 8216bis-20
/// Section 4.4.3.8.
enum VariableRules {

    // MARK: - Master Playlist

    /// Validates variable definitions and references in a master
    /// playlist.
    static func validate(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        let defs = playlist.definitions

        results += validateDuplicateNames(defs)
        results += validateCircularReferences(defs)

        let definedNames = Set(
            defs.filter { $0.type == .value }.map(\.name)
        )
        let importedNames = Set(
            defs.filter { $0.type == .import }.map(\.name)
        )

        // Check all variant URIs for undefined references.
        for (i, variant) in playlist.variants.enumerated() {
            results += validateUndefinedReferences(
                in: variant.uri,
                definedNames: definedNames,
                importedNames: importedNames,
                field: "variants[\(i)].uri"
            )
        }
        for (i, iFrame) in playlist.iFrameVariants.enumerated() {
            results += validateUndefinedReferences(
                in: iFrame.uri,
                definedNames: definedNames,
                importedNames: importedNames,
                field: "iFrameVariants[\(i)].uri"
            )
        }
        for (i, rendition) in playlist.renditions.enumerated() {
            if let uri = rendition.uri {
                results += validateUndefinedReferences(
                    in: uri,
                    definedNames: definedNames,
                    importedNames: importedNames,
                    field: "renditions[\(i)].uri"
                )
            }
        }
        return results
    }

    // MARK: - Media Playlist

    /// Validates variable definitions and references in a media
    /// playlist.
    static func validate(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        let defs = playlist.definitions

        results += validateDuplicateNames(defs)
        results += validateCircularReferences(defs)

        let definedNames = Set(
            defs.filter { $0.type == .value }.map(\.name)
        )
        let importedNames = Set(
            defs.filter { $0.type == .import }.map(\.name)
        )

        // IMPORT requires a parent multivariant playlist.
        for def in defs where def.type == .import {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "IMPORT \"\(def.name)\" requires a "
                        + "multivariant playlist context.",
                    field: "definitions",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216bis-4.4.3.8-import"
                )
            )
        }

        for (i, segment) in playlist.segments.enumerated() {
            results += validateUndefinedReferences(
                in: segment.uri,
                definedNames: definedNames,
                importedNames: importedNames,
                field: "segments[\(i)].uri"
            )
            if let key = segment.key, let uri = key.uri {
                results += validateUndefinedReferences(
                    in: uri,
                    definedNames: definedNames,
                    importedNames: importedNames,
                    field: "segments[\(i)].key.uri"
                )
            }
            if let map = segment.map {
                results += validateUndefinedReferences(
                    in: map.uri,
                    definedNames: definedNames,
                    importedNames: importedNames,
                    field: "segments[\(i)].map.uri"
                )
            }
        }
        return results
    }

    // MARK: - Shared Rules

    /// Detects duplicate DEFINE names.
    private static func validateDuplicateNames(
        _ definitions: [VariableDefinition]
    ) -> [ValidationResult] {
        var seen = Set<String>()
        var results: [ValidationResult] = []
        for def in definitions {
            if seen.contains(def.name) {
                results.append(
                    ValidationResult(
                        severity: .warning,
                        message:
                            "Duplicate EXT-X-DEFINE name "
                            + "\"\(def.name)\".",
                        field: "definitions",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216bis-4.4.3.8-duplicate"
                    )
                )
            }
            seen.insert(def.name)
        }
        return results
    }

    /// Detects circular references in variable definitions.
    private static func validateCircularReferences(
        _ definitions: [VariableDefinition]
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        var valueMap: [String: String] = [:]
        for def in definitions where def.type == .value {
            valueMap[def.name] = def.value
        }

        for (name, value) in valueMap {
            let referenced = VariableResolver.extractVariableNames(
                from: value
            )
            for ref in referenced {
                if ref == name {
                    results.append(
                        ValidationResult(
                            severity: .error,
                            message:
                                "Circular reference: variable "
                                + "\"\(name)\" references itself.",
                            field: "definitions",
                            ruleSet: .rfc8216,
                            ruleId:
                                "RFC8216bis-4.4.3.8-circular"
                        )
                    )
                } else if let transitive = valueMap[ref],
                    VariableResolver.extractVariableNames(
                        from: transitive
                    ).contains(name)
                {
                    results.append(
                        ValidationResult(
                            severity: .error,
                            message:
                                "Circular reference between "
                                + "\"\(name)\" and \"\(ref)\".",
                            field: "definitions",
                            ruleSet: .rfc8216,
                            ruleId:
                                "RFC8216bis-4.4.3.8-circular"
                        )
                    )
                }
            }
        }
        return results
    }

    /// Checks for undefined variable references in a string.
    private static func validateUndefinedReferences(
        in input: String,
        definedNames: Set<String>,
        importedNames: Set<String>,
        field: String
    ) -> [ValidationResult] {
        let references = VariableResolver.extractVariableNames(
            from: input
        )
        var results: [ValidationResult] = []
        for ref in references {
            if !definedNames.contains(ref),
                !importedNames.contains(ref)
            {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "Undefined variable reference "
                            + "\"{$\(ref)}\".",
                        field: field,
                        ruleSet: .rfc8216,
                        ruleId:
                            "RFC8216bis-4.4.3.8-undefined"
                    )
                )
            }
        }
        return results
    }
}
