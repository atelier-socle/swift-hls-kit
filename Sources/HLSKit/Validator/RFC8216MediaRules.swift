// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Media Target Duration Validation

extension RFC8216Rules {

    static func validateTargetDuration(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if playlist.targetDuration <= 0 {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "TARGETDURATION must be a positive "
                        + "integer.",
                    field: "targetDuration",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.3.3.1-integer"
                ))
        }
        for (i, segment) in playlist.segments.enumerated() {
            let rounded = Int(segment.duration.rounded())
            if rounded > playlist.targetDuration {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "Segment duration \(segment.duration)s "
                            + "exceeds TARGETDURATION "
                            + "\(playlist.targetDuration)s.",
                        field: "segments[\(i)].duration",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.3.1-segment-duration"
                    ))
            }
        }
        return results
    }
}

// MARK: - Media Segment Validation

extension RFC8216Rules {

    static func validateSegments(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        if playlist.segments.isEmpty {
            results.append(
                ValidationResult(
                    severity: .warning,
                    message:
                        "Playlist should have at least one "
                        + "segment.",
                    field: "segments",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-general-empty"
                ))
        }
        for (i, segment) in playlist.segments.enumerated() {
            if segment.duration < 0 {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "Segment duration must not be "
                            + "negative.",
                        field: "segments[\(i)].duration",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.2.1-extinf"
                    ))
            }
            if segment.uri.isEmpty {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message: "Segment URI must not be empty.",
                        field: "segments[\(i)].uri",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.2.1-uri"
                    ))
            }
        }
        if playlist.playlistType == .vod && !playlist.hasEndList {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "VOD playlists must contain "
                        + "EXT-X-ENDLIST.",
                    field: "hasEndList",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.3.3.5-endlist-vod"
                ))
        }
        return results
    }
}

// MARK: - Media Encryption Validation

extension RFC8216Rules {

    static func validateEncryption(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        let version = playlist.version
        for (i, segment) in playlist.segments.enumerated() {
            guard let key = segment.key else { continue }
            if key.method != .none && key.uri == nil {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "EXT-X-KEY with METHOD != NONE "
                            + "must have URI.",
                        field: "segments[\(i)].key.uri",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.2.4-key-uri"
                    ))
            }
            if let v = version, key.iv != nil, v < .v2 {
                results.append(
                    ValidationResult(
                        severity: .error,
                        message:
                            "EXT-X-KEY with IV requires "
                            + "version >= 2.",
                        field: "segments[\(i)].key.iv",
                        ruleSet: .rfc8216,
                        ruleId: "RFC8216-4.3.2.4-key-iv"
                    ))
            }
        }
        results += validateVersionFeatures(playlist)
        return results
    }

    private static func validateVersionFeatures(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        guard let version = playlist.version else {
            return results
        }
        if playlist.segments.contains(where: {
            $0.byteRange != nil
        }), version < .v4 {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "EXT-X-BYTERANGE requires version >= 4.",
                    field: "version",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.3.2.2-byterange-version"
                ))
        }
        let hasMap = playlist.segments.contains { $0.map != nil }
        if hasMap && !playlist.iFramesOnly && version < .v6 {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "EXT-X-MAP without I-FRAMES-ONLY "
                        + "requires version >= 6.",
                    field: "version",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.3.2.5-map-version"
                ))
        }
        return results
    }
}

// MARK: - Media Version Consistency

extension RFC8216Rules {

    static func validateVersionConsistency(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        guard let version = playlist.version else { return [] }
        let required = requiredVersion(for: playlist)
        if version.rawValue < required {
            return [
                ValidationResult(
                    severity: .warning,
                    message:
                        "Features used require version >= "
                        + "\(required) but declared version "
                        + "is \(version.rawValue).",
                    field: "version",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216-4.4.3-version-match"
                )
            ]
        }
        return []
    }

    private static func requiredVersion(
        for playlist: MediaPlaylist
    ) -> Int {
        var required = 1
        let hasDecimal = playlist.segments.contains {
            $0.duration.truncatingRemainder(dividingBy: 1) != 0
        }
        if hasDecimal { required = max(required, 3) }
        if playlist.segments.contains(where: {
            $0.byteRange != nil
        }) {
            required = max(required, 4)
        }
        if playlist.iFramesOnly {
            required = max(required, 4)
        }
        required = max(
            required,
            requiredVersionForEncryption(playlist)
        )
        if !playlist.iFramesOnly
            && playlist.segments.contains(where: {
                $0.map != nil
            })
        {
            required = max(required, 6)
        }
        if !playlist.definitions.isEmpty {
            required = max(required, 8)
        }
        return required
    }

    private static func requiredVersionForEncryption(
        _ playlist: MediaPlaylist
    ) -> Int {
        var required = 1
        for segment in playlist.segments {
            guard let key = segment.key else { continue }
            if key.iv != nil { required = max(required, 2) }
            if key.keyFormat != nil
                || key.keyFormatVersions != nil
            {
                required = max(required, 5)
            }
        }
        return required
    }
}

// MARK: - LL-HLS Validation

extension RFC8216Rules {

    static func validateLowLatency(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        let hasLLHLS =
            playlist.serverControl != nil
            || playlist.partTargetDuration != nil
            || !playlist.partialSegments.isEmpty
            || !playlist.preloadHints.isEmpty
        guard hasLLHLS else { return [] }
        var results: [ValidationResult] = []
        if !playlist.partialSegments.isEmpty
            && playlist.partTargetDuration == nil
        {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "Playlists with PART tags must have "
                        + "EXT-X-PART-INF.",
                    field: "partTargetDuration",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216bis-part-inf"
                ))
        }
        if let partTarget = playlist.partTargetDuration {
            results += validatePartDurations(
                playlist.partialSegments,
                partTarget: partTarget
            )
        }
        if playlist.serverControl == nil {
            results.append(
                ValidationResult(
                    severity: .warning,
                    message:
                        "LL-HLS playlists should have "
                        + "EXT-X-SERVER-CONTROL.",
                    field: "serverControl",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216bis-server-control"
                ))
        }
        results += validateHoldBack(playlist)
        results += validateLLHLSVersion(playlist)
        return results
    }

    private static func validatePartDurations(
        _ parts: [PartialSegment],
        partTarget: Double
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (i, part) in parts.enumerated()
        where part.duration > partTarget {
            results.append(
                ValidationResult(
                    severity: .error,
                    message:
                        "PART duration \(part.duration)s "
                        + "exceeds PART-TARGET \(partTarget)s.",
                    field: "partialSegments[\(i)].duration",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216bis-part-duration"
                ))
        }
        return results
    }

    private static func validateHoldBack(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        guard let control = playlist.serverControl,
            let holdBack = control.partHoldBack,
            let partTarget = playlist.partTargetDuration
        else { return [] }
        if holdBack < partTarget * 3 {
            return [
                ValidationResult(
                    severity: .warning,
                    message:
                        "PART-HOLD-BACK should be >= 3x "
                        + "PART-TARGET.",
                    field: "serverControl.partHoldBack",
                    ruleSet: .rfc8216,
                    ruleId: "RFC8216bis-hold-back"
                )
            ]
        }
        return []
    }

    private static func validateLLHLSVersion(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        guard let version = playlist.version,
            version < .v9
        else { return [] }
        return [
            ValidationResult(
                severity: .error,
                message:
                    "LL-HLS features require version >= 9.",
                field: "version",
                ruleSet: .rfc8216,
                ruleId: "RFC8216bis-version"
            )
        ]
    }
}
