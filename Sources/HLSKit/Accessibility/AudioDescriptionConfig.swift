// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for audio description tracks in HLS.
///
/// Audio descriptions are alternative audio renditions with narration
/// describing visual elements for visually impaired viewers.
///
/// ```swift
/// let config = AudioDescriptionConfig(
///     language: "en",
///     name: "English Audio Description"
/// )
/// let entry = config.renditionEntry(uri: "audio/ad/en/main.m3u8")
/// ```
public struct AudioDescriptionConfig: Sendable, Equatable {

    /// Language code.
    public var language: String

    /// Track name.
    public var name: String

    /// Audio GROUP-ID.
    public var groupID: String

    /// Accessibility characteristics.
    public var characteristics: String

    /// Creates an audio description configuration.
    ///
    /// - Parameters:
    ///   - language: The ISO 639-1 language code.
    ///   - name: A human-readable track name.
    ///   - groupID: The audio GROUP-ID.
    ///   - characteristics: The accessibility characteristics string.
    public init(
        language: String = "en",
        name: String = "English Audio Description",
        groupID: String = "audio-ad",
        characteristics: String = "public.accessibility.describes-video"
    ) {
        self.language = language
        self.name = name
        self.groupID = groupID
        self.characteristics = characteristics
    }

    // MARK: - Rendition Entry

    /// Generate the EXT-X-MEDIA rendition entry.
    ///
    /// - Parameters:
    ///   - uri: The URI of the audio description playlist.
    ///   - isDefault: Whether this is the default audio track.
    /// - Returns: The formatted EXT-X-MEDIA tag string.
    public func renditionEntry(uri: String, isDefault: Bool = false) -> String {
        let attrs: [String] = [
            "TYPE=AUDIO",
            "GROUP-ID=\"\(groupID)\"",
            "LANGUAGE=\"\(language)\"",
            "NAME=\"\(name)\"",
            "DEFAULT=\(isDefault ? "YES" : "NO")",
            "AUTOSELECT=YES",
            "CHARACTERISTICS=\"\(characteristics)\"",
            "URI=\"\(uri)\""
        ]
        return "#EXT-X-MEDIA:" + attrs.joined(separator: ",")
    }

    // MARK: - Presets

    /// English audio description preset.
    public static let english = AudioDescriptionConfig(
        language: "en",
        name: "English Audio Description"
    )

    /// French audio description preset.
    public static let french = AudioDescriptionConfig(
        language: "fr",
        name: "Audiodescription français"
    )

    /// Spanish audio description preset.
    public static let spanish = AudioDescriptionConfig(
        language: "es",
        name: "Audiodescripción en español"
    )
}
