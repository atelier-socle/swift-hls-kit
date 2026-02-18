// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Validation rules derived from the Apple HLS Authoring Specification.
///
/// These rules check Apple-specific requirements such as codec
/// declarations, I-frame playlists, and audio group conventions.
enum AppleHLSRules {

    // MARK: - Master Playlist Rules

    /// Validates a master playlist against Apple HLS authoring rules.
    static func validate(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        results += validateCodecs(playlist)
        results += validateFrameRate(playlist)
        results += validateIFramePlaylists(playlist)
        results += validateAudioRenditions(playlist)
        results += validateResolutionLadder(playlist)
        results += validateBandwidthOrder(playlist)
        results += validateHDCP(playlist)
        return results
    }

    // MARK: - Media Playlist Rules

    /// Validates a media playlist against Apple HLS authoring rules.
    static func validate(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        results += validateSegmentDurations(playlist)
        results += validateTargetDuration(playlist)
        results += validateIndependentSegments(playlist)
        results += validateFMP4(playlist)
        return results
    }
}

// MARK: - Master Codec Validation

extension AppleHLSRules {

    private static func validateCodecs(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (i, variant) in playlist.variants.enumerated()
        where variant.codecs == nil {
            results.append(
                ValidationResult(
                    severity: .warning,
                    message:
                        "Apple recommends including CODECS "
                        + "attribute for all variant streams.",
                    field: "variants[\(i)].codecs",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-2.1-codecs"
                ))
        }
        return results
    }

    private static func validateFrameRate(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (i, variant) in playlist.variants.enumerated()
        where variant.frameRate == nil && variant.resolution != nil {
            results.append(
                ValidationResult(
                    severity: .warning,
                    message:
                        "Video variants should include FRAME-RATE.",
                    field: "variants[\(i)].frameRate",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-2.1-frame-rate"
                ))
        }
        return results
    }
}

// MARK: - Master I-Frame and Audio Validation

extension AppleHLSRules {

    private static func validateIFramePlaylists(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        if playlist.iFrameVariants.isEmpty
            && !playlist.variants.isEmpty
        {
            return [
                ValidationResult(
                    severity: .info,
                    message:
                        "Master playlist should include "
                        + "I-frame playlists.",
                    field: "iFrameVariants",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-2.2-iframe"
                )
            ]
        }
        return []
    }

    private static func validateAudioRenditions(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        let audioRenditions = playlist.renditions.filter {
            $0.type == .audio
        }
        for (i, rendition) in audioRenditions.enumerated()
        where rendition.language == nil {
            results.append(
                ValidationResult(
                    severity: .warning,
                    message:
                        "Audio renditions should specify LANGUAGE.",
                    field: "renditions[\(i)].language",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-2.3-audio-group"
                ))
        }
        return results
    }
}

// MARK: - Master Resolution and Bandwidth Validation

extension AppleHLSRules {

    private static func validateResolutionLadder(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        let resolutions = playlist.variants.compactMap(\.resolution)
        guard !resolutions.isEmpty else { return [] }
        let heights = Set(resolutions.map(\.height))
        let tiers = [480, 720, 1080]
        let coveredTiers = tiers.filter { tier in
            heights.contains { $0 >= tier }
        }
        if coveredTiers.count < 3 && playlist.variants.count >= 3 {
            return [
                ValidationResult(
                    severity: .info,
                    message:
                        "At least 3 quality tiers recommended "
                        + "(480p, 720p, 1080p).",
                    field: "variants",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-2.4-resolution-ladder"
                )
            ]
        }
        return []
    }

    private static func validateBandwidthOrder(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        let bandwidths = playlist.variants.map(\.bandwidth)
        guard bandwidths.count > 1 else { return [] }
        let isSorted = zip(bandwidths, bandwidths.dropFirst()).allSatisfy {
            $0 <= $1
        }
        if !isSorted {
            return [
                ValidationResult(
                    severity: .info,
                    message:
                        "Variants should be listed in "
                        + "ascending bandwidth order.",
                    field: "variants",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-2.5-bandwidth-order"
                )
            ]
        }
        return []
    }

    private static func validateHDCP(
        _ playlist: MasterPlaylist
    ) -> [ValidationResult] {
        var results: [ValidationResult] = []
        for (i, variant) in playlist.variants.enumerated() {
            if let resolution = variant.resolution,
                resolution.height >= 2160,
                variant.hdcpLevel == nil
            {
                results.append(
                    ValidationResult(
                        severity: .info,
                        message:
                            "4K content should specify HDCP-LEVEL.",
                        field: "variants[\(i)].hdcpLevel",
                        ruleSet: .appleHLS,
                        ruleId: "APPLE-2.6-hdcp"
                    ))
            }
        }
        return results
    }
}

// MARK: - Media Playlist Validation

extension AppleHLSRules {

    private static func validateSegmentDurations(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        guard !playlist.segments.isEmpty else { return [] }
        let avgDuration =
            playlist.segments.map(\.duration)
            .reduce(0, +) / Double(playlist.segments.count)
        if avgDuration < 4.0 || avgDuration > 8.0 {
            return [
                ValidationResult(
                    severity: .info,
                    message:
                        "Segment durations should be "
                        + "approximately 6 seconds.",
                    field: "segments",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-3.1-segment-duration"
                )
            ]
        }
        return []
    }

    private static func validateTargetDuration(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        let hasLLHLS =
            playlist.serverControl != nil
            || playlist.partTargetDuration != nil
        if hasLLHLS && playlist.targetDuration > 4 {
            return [
                ValidationResult(
                    severity: .info,
                    message:
                        "TARGETDURATION should be <= 4 "
                        + "for LL-HLS.",
                    field: "targetDuration",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-3.2-target-duration"
                )
            ]
        }
        if !hasLLHLS && playlist.targetDuration != 6
            && !playlist.segments.isEmpty
        {
            return [
                ValidationResult(
                    severity: .info,
                    message:
                        "TARGETDURATION should be 6 for "
                        + "standard playlists.",
                    field: "targetDuration",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-3.2-target-duration"
                )
            ]
        }
        return []
    }

    private static func validateIndependentSegments(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        if !playlist.independentSegments {
            return [
                ValidationResult(
                    severity: .warning,
                    message:
                        "EXT-X-INDEPENDENT-SEGMENTS "
                        + "recommended.",
                    field: "independentSegments",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-3.5-independent"
                )
            ]
        }
        return []
    }

    private static func validateFMP4(
        _ playlist: MediaPlaylist
    ) -> [ValidationResult] {
        if !playlist.segments.isEmpty
            && !playlist.segments.contains(where: { $0.map != nil })
        {
            return [
                ValidationResult(
                    severity: .info,
                    message:
                        "fMP4 (EXT-X-MAP) preferred over "
                        + "MPEG-TS.",
                    field: "segments",
                    ruleSet: .appleHLS,
                    ruleId: "APPLE-3.4-fmp4"
                )
            ]
        }
        return []
    }
}
