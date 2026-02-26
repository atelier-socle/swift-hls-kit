// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates all accessibility-related rendition entries for a master playlist.
///
/// Orchestrates closed captions, subtitles, and audio descriptions
/// into correctly formatted `EXT-X-MEDIA` entries.
///
/// ```swift
/// let generator = AccessibilityRenditionGenerator()
/// let entries = generator.generateAll(
///     captions: .englishSpanish708,
///     subtitles: [subtitlePlaylist],
///     audioDescriptions: [.english]
/// )
/// ```
public struct AccessibilityRenditionGenerator: Sendable {

    /// Creates an accessibility rendition generator.
    public init() {}

    // MARK: - AccessibilityEntry

    /// Generated accessibility entry.
    public struct AccessibilityEntry: Sendable, Equatable {
        /// The formatted EXT-X-MEDIA tag.
        public let tag: String
        /// Type: closedCaptions, subtitles, audioDescription.
        public let type: AccessibilityType
    }

    /// Accessibility types.
    public enum AccessibilityType: String, Sendable, CaseIterable {
        /// Closed captions (CEA-608/708).
        case closedCaptions
        /// WebVTT subtitles.
        case subtitles
        /// Audio description tracks.
        case audioDescription
    }

    // MARK: - Generation

    /// Generate closed caption rendition entries.
    ///
    /// - Parameter config: The closed caption configuration.
    /// - Returns: An array of accessibility entries for each caption service.
    public func generateCaptionEntries(
        config: ClosedCaptionConfig
    ) -> [AccessibilityEntry] {
        config.services.map { service in
            let instreamID = service.instreamID(standard: config.standard)
            let attrs: [String] = [
                "TYPE=CLOSED-CAPTIONS",
                "GROUP-ID=\"\(config.groupID)\"",
                "LANGUAGE=\"\(service.language)\"",
                "NAME=\"\(service.name)\"",
                "DEFAULT=\(service.isDefault ? "YES" : "NO")",
                "AUTOSELECT=YES",
                "INSTREAM-ID=\"\(instreamID)\""
            ]
            let tag = "#EXT-X-MEDIA:" + attrs.joined(separator: ",")
            return AccessibilityEntry(tag: tag, type: .closedCaptions)
        }
    }

    /// Generate subtitle rendition entries.
    ///
    /// - Parameter playlists: Pairs of subtitle playlists and their URIs.
    /// - Returns: An array of accessibility entries for each subtitle track.
    public func generateSubtitleEntries(
        playlists: [(playlist: LiveSubtitlePlaylist, uri: String)]
    ) -> [AccessibilityEntry] {
        playlists.enumerated().map { index, pair in
            let tag = pair.playlist.renditionEntry(
                uri: pair.uri,
                isDefault: index == 0
            )
            return AccessibilityEntry(tag: tag, type: .subtitles)
        }
    }

    /// Generate audio description entries.
    ///
    /// - Parameter configs: Pairs of audio description configs and their URIs.
    /// - Returns: An array of accessibility entries for each audio description track.
    public func generateAudioDescriptionEntries(
        configs: [(config: AudioDescriptionConfig, uri: String)]
    ) -> [AccessibilityEntry] {
        configs.map { pair in
            let tag = pair.config.renditionEntry(uri: pair.uri)
            return AccessibilityEntry(tag: tag, type: .audioDescription)
        }
    }

    /// Generate all accessibility entries.
    ///
    /// - Parameters:
    ///   - captions: Optional closed caption configuration.
    ///   - subtitles: Subtitle playlist and URI pairs.
    ///   - audioDescriptions: Audio description config and URI pairs.
    /// - Returns: All generated accessibility entries.
    public func generateAll(
        captions: ClosedCaptionConfig? = nil,
        subtitles: [(playlist: LiveSubtitlePlaylist, uri: String)] = [],
        audioDescriptions: [(config: AudioDescriptionConfig, uri: String)] = []
    ) -> [AccessibilityEntry] {
        var entries: [AccessibilityEntry] = []
        if let captions {
            entries.append(contentsOf: generateCaptionEntries(config: captions))
        }
        entries.append(contentsOf: generateSubtitleEntries(playlists: subtitles))
        entries.append(
            contentsOf: generateAudioDescriptionEntries(configs: audioDescriptions)
        )
        return entries
    }

    // MARK: - Validation

    /// Validate that variant CLOSED-CAPTIONS attribute matches caption config.
    ///
    /// - Parameters:
    ///   - closedCaptionsAttr: The CLOSED-CAPTIONS attribute from the variant.
    ///   - config: The closed caption configuration.
    /// - Returns: An array of validation error messages. Empty if valid.
    public func validateVariantCaptions(
        closedCaptionsAttr: String?,
        config: ClosedCaptionConfig?
    ) -> [String] {
        var errors: [String] = []

        if config != nil, closedCaptionsAttr == nil {
            errors.append(
                "Caption config provided but variant has no CLOSED-CAPTIONS attribute"
            )
        }

        if closedCaptionsAttr != nil, config == nil {
            errors.append(
                "Variant has CLOSED-CAPTIONS attribute but no caption config provided"
            )
        }

        if let attr = closedCaptionsAttr, let config {
            if attr != config.groupID {
                errors.append(
                    "CLOSED-CAPTIONS attribute '\(attr)' does not match config groupID '\(config.groupID)'"
                )
            }
        }

        return errors
    }
}
