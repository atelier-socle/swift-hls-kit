// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates EXT-X-MEDIA entries for spatial and multi-channel audio renditions.
///
/// Produces correctly formatted HLS rendition entries with proper CHANNELS,
/// CODECS, GROUP-ID, LANGUAGE, and DEFAULT/AUTOSELECT attributes.
///
/// ```swift
/// let generator = SpatialRenditionGenerator()
/// let renditions = generator.generateRenditions(
///     config: .atmos7_1_4,
///     language: "en",
///     name: "English (Atmos)"
/// )
/// // Returns: Atmos rendition + stereo AAC fallback
/// ```
public struct SpatialRenditionGenerator: Sendable {

    /// Creates a spatial rendition generator.
    public init() {}

    // MARK: - AudioRendition

    /// A generated audio rendition entry.
    public struct AudioRendition: Sendable, Equatable {
        /// Rendition name (e.g., "English (Atmos)").
        public let name: String
        /// Language code (e.g., "en").
        public let language: String?
        /// GROUP-ID for linking to variants.
        public let groupID: String
        /// URI to the media playlist.
        public let uri: String?
        /// Whether this is the default rendition.
        public let isDefault: Bool
        /// Whether this rendition auto-selects.
        public let autoSelect: Bool
        /// CHANNELS attribute (e.g., "6", "16/JOC").
        public let channels: String
        /// CODECS string (e.g., "ec+3", "ac-3", "mp4a.40.2").
        public let codecs: String
        /// Descriptive characteristics.
        public let characteristics: String?

        /// Creates an audio rendition.
        public init(
            name: String,
            language: String?,
            groupID: String,
            uri: String?,
            isDefault: Bool,
            autoSelect: Bool,
            channels: String,
            codecs: String,
            characteristics: String? = nil
        ) {
            self.name = name
            self.language = language
            self.groupID = groupID
            self.uri = uri
            self.isDefault = isDefault
            self.autoSelect = autoSelect
            self.channels = channels
            self.codecs = codecs
            self.characteristics = characteristics
        }

        /// Formats as an EXT-X-MEDIA tag string.
        public func formatAsTag() -> String {
            var attrs: [String] = [
                "TYPE=AUDIO",
                "GROUP-ID=\"\(groupID)\"",
                "NAME=\"\(name)\"",
                "CHANNELS=\"\(channels)\"",
                "DEFAULT=\(isDefault ? "YES" : "NO")",
                "AUTOSELECT=\(autoSelect ? "YES" : "NO")"
            ]
            if let language {
                attrs.append("LANGUAGE=\"\(language)\"")
            }
            if let uri {
                attrs.append("URI=\"\(uri)\"")
            }
            if let characteristics {
                attrs.append(
                    "CHARACTERISTICS=\"\(characteristics)\""
                )
            }
            return "#EXT-X-MEDIA:" + attrs.joined(separator: ",")
        }
    }

    // MARK: - Generation

    /// Generate renditions for a spatial audio configuration.
    ///
    /// - Parameters:
    ///   - config: Spatial audio configuration.
    ///   - language: Optional ISO 639-1 language code.
    ///   - name: Human-readable name for the rendition.
    ///   - uri: Media playlist URI pattern.
    ///   - isDefault: Whether this is the default audio.
    /// - Returns: Array of AudioRendition (spatial + optional stereo fallback).
    public func generateRenditions(
        config: SpatialAudioConfig,
        language: String? = nil,
        name: String,
        uri: String? = nil,
        isDefault: Bool = true
    ) -> [AudioRendition] {
        var renditions: [AudioRendition] = []

        let spatial = AudioRendition(
            name: name,
            language: language,
            groupID: config.groupID,
            uri: uri,
            isDefault: isDefault,
            autoSelect: true,
            channels: config.hlsChannelsAttribute,
            codecs: config.hlsCodecString
        )
        renditions.append(spatial)

        if config.generateStereoFallback {
            let fallback = generateStereoFallback(
                language: language,
                groupID: config.groupID,
                uri: uri.map { deriveFallbackURI($0) },
                isDefault: false
            )
            renditions.append(fallback)
        }

        return renditions
    }

    /// Generate multi-language renditions for simultaneous live audio tracks.
    ///
    /// - Parameter tracks: Array of audio track descriptors.
    /// - Returns: All renditions, with first track as DEFAULT.
    public func generateMultiLanguageRenditions(
        tracks: [AudioTrackDescriptor]
    ) -> [AudioRendition] {
        var renditions: [AudioRendition] = []

        for (index, track) in tracks.enumerated() {
            let isFirst = index == 0
            let trackRenditions = generateRenditions(
                config: track.config,
                language: track.language,
                name: track.name,
                uri: track.uri,
                isDefault: isFirst
            )
            renditions.append(contentsOf: trackRenditions)
        }

        return renditions
    }

    /// Generate a stereo AAC fallback rendition.
    ///
    /// - Parameters:
    ///   - language: Optional language code.
    ///   - groupID: GROUP-ID for the rendition.
    ///   - uri: URI for the fallback playlist.
    ///   - isDefault: Whether this is the default.
    /// - Returns: A stereo AAC audio rendition.
    public func generateStereoFallback(
        language: String?,
        groupID: String,
        uri: String?,
        isDefault: Bool
    ) -> AudioRendition {
        AudioRendition(
            name: "Stereo",
            language: language,
            groupID: groupID,
            uri: uri,
            isDefault: isDefault,
            autoSelect: true,
            channels: "2",
            codecs: "mp4a.40.2"
        )
    }

    // MARK: - AudioTrackDescriptor

    /// Describes an audio track for multi-language rendition generation.
    public struct AudioTrackDescriptor: Sendable {
        /// ISO 639-1 language code (e.g., "en", "fr").
        public let language: String
        /// Human-readable track name.
        public let name: String
        /// Spatial audio configuration.
        public let config: SpatialAudioConfig
        /// Media playlist URI.
        public let uri: String

        /// Creates an audio track descriptor.
        public init(
            language: String,
            name: String,
            config: SpatialAudioConfig,
            uri: String
        ) {
            self.language = language
            self.name = name
            self.config = config
            self.uri = uri
        }
    }

    // MARK: - Helpers

    /// Derives a stereo fallback URI from a spatial URI.
    private func deriveFallbackURI(_ uri: String) -> String {
        if uri.contains("atmos") {
            return uri.replacingOccurrences(of: "atmos", with: "stereo")
        }
        if uri.contains("spatial") {
            return uri.replacingOccurrences(of: "spatial", with: "stereo")
        }
        let ext = uri.hasSuffix(".m3u8") ? ".m3u8" : ""
        let base = uri.replacingOccurrences(of: ext, with: "")
        return base + "_stereo" + ext
    }
}
