// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validation rules derived from RFC 8216 — HTTP Live Streaming.
///
/// These rules check that a manifest conforms to the requirements
/// and constraints specified in the HLS standard.
enum RFC8216Rules {

    // MARK: - Master Playlist Rules

    /// Validates a master playlist against RFC 8216 rules.
    static func validate(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        results += validateVariants(playlist)
        results += validateRenditionGroups(playlist)
        results += validateGroupReferences(playlist)
        results += validateSessionData(playlist)
        return results
    }

    // MARK: - Media Playlist Rules

    /// Validates a media playlist against RFC 8216 rules.
    static func validate(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        results += validateTargetDuration(playlist)
        results += validateSegments(playlist)
        results += validateEncryption(playlist)
        results += validateVersionConsistency(playlist)
        results += validateLowLatency(playlist)
        return results
    }
}

// MARK: - Master Variant Validation

extension RFC8216Rules {

    private static func validateVariants(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if playlist.variants.isEmpty {
            results.append(
                ValidationResult(
                    severity: .warning,
                    message:
                        "Master playlist should have at least "
                        + "one variant.",
                    field: "variants",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-general-variants"
                ))
        }
        for (i, variant) in playlist.variants.enumerated() {
            if variant.bandwidth <= 0 {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "BANDWIDTH must be a positive integer.",
                        field: "variants[\(i)].bandwidth",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.2-bandwidth"
                    ))
            }
            if variant.uri.isEmpty {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message: "Variant stream must have a URI.",
                        field: "variants[\(i)].uri",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.2-uri"
                    ))
            }
            if variant.resolution == nil {
                results.append(
                    ValidationResult(
                        severity: .warning,
                        message:
                            "Variants with video should include "
                            + "RESOLUTION.",
                        field: "variants[\(i)].resolution",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.2-resolution"
                    ))
            }
        }
        return results
    }
}

// MARK: - Master Rendition Group Validation

extension RFC8216Rules {

    private static func validateRenditionGroups(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        let grouped = Dictionary(
            grouping: playlist.renditions,
            by: { "\($0.type.rawValue)|\($0.groupId)" }
        )
        for (key, renditions) in grouped {
            let names = renditions.map(\.name)
            if Set(names).count != names.count {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "Renditions with same TYPE and GROUP-ID "
                            + "must not duplicate NAME.",
                        field: "renditions[\(key)]",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.1-group-id"
                    ))
            }
            let defaultCount = renditions.filter(\.isDefault).count
            if defaultCount > 1 {
                results.append(
                    ValidationResult(
                        severity: .warning,
                        message:
                            "At most one rendition in a group "
                            + "should have DEFAULT=YES.",
                        field: "renditions[\(key)]",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.1-default"
                    ))
            }
        }
        return results
    }

    private static func validateGroupReferences(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        let audioGroups = Set(
            playlist.renditions
                .filter { $0.type == .audio }
                .map(\.groupId)
        )
        let subtitleGroups = Set(
            playlist.renditions
                .filter { $0.type == .subtitles }
                .map(\.groupId)
        )
        let ccGroups = Set(
            playlist.renditions
                .filter { $0.type == .closedCaptions }
                .map(\.groupId)
        )
        for (i, variant) in playlist.variants.enumerated() {
            results += validateVariantGroupRefs(
                variant, index: i,
                audioGroups: audioGroups,
                subtitleGroups: subtitleGroups,
                ccGroups: ccGroups
            )
        }
        return results
    }

    private static func validateVariantGroupRefs(
        _ variant: Variant,
        index i: Int,
        audioGroups: Set<String>,
        subtitleGroups: Set<String>,
        ccGroups: Set<String>
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if let audio = variant.audio,
            !audioGroups.contains(audio)
        {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "AUDIO attribute references undefined "
                        + "GROUP-ID \"\(audio)\".",
                    field: "variants[\(i)].audio",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.3.4.2-audio-ref"
                ))
        }
        if let subs = variant.subtitles,
            !subtitleGroups.contains(subs)
        {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "SUBTITLES attribute references undefined "
                        + "GROUP-ID \"\(subs)\".",
                    field: "variants[\(i)].subtitles",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.3.4.2-subtitle-ref"
                ))
        }
        if let cc = variant.closedCaptions,
            case .groupId(let groupId) = cc,
            !ccGroups.contains(groupId)
        {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "CLOSED-CAPTIONS attribute references "
                        + "undefined GROUP-ID \"\(groupId)\".",
                    field: "variants[\(i)].closedCaptions",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.3.4.2-cc-ref"
                ))
        }
        return results
    }
}

// MARK: - Master Session Data Validation

extension RFC8216Rules {

    private static func validateSessionData(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (i, data) in playlist.sessionData.enumerated() {
            if data.value != nil && data.uri != nil {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "SESSION-DATA must have VALUE or URI, "
                            + "not both.",
                        field: "sessionData[\(i)]",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.5-session-data-value"
                    ))
            }
            if data.value == nil && data.uri == nil {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "SESSION-DATA must have either VALUE "
                            + "or URI.",
                        field: "sessionData[\(i)]",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.5-session-data-value"
                    ))
            }
        }
        let grouped = Dictionary(
            grouping: playlist.sessionData,
            by: { $0.dataId }
        )
        for (dataId, items) in grouped {
            let langs = items.compactMap(\.language)
            if Set(langs).count != langs.count {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "SESSION-DATA with DATA-ID "
                            + "\"\(dataId)\" must not "
                            + "duplicate LANGUAGE.",
                        field: "sessionData",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.4.5-session-data-id"
                    ))
            }
        }
        return results
    }
}
