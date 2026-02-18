// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// A rendition within an `EXT-X-MEDIA` tag.
///
/// Renditions describe alternative media tracks (audio languages,
/// subtitle languages, camera angles, etc.) that a client can select.
/// They are grouped by `TYPE` and `GROUP-ID`. See RFC 8216 Section 4.3.4.1.
public struct Rendition: Sendable, Hashable, Codable {

    /// The media type of this rendition.
    public var type: MediaType

    /// The URI of the media playlist for this rendition.
    /// If `nil`, the rendition is included in every variant that
    /// references the group.
    public var uri: String?

    /// The group to which this rendition belongs.
    public var groupId: String

    /// The primary language of the rendition as a BCP 47 language tag.
    public var language: String?

    /// An associated language tag for a different role.
    public var assocLanguage: String?

    /// A human-readable name for the rendition.
    public var name: String

    /// If `true`, this is the default rendition for the group.
    public var isDefault: Bool

    /// If `true`, the client may play this rendition without explicit
    /// user selection.
    public var autoselect: Bool

    /// If `true`, the content of this rendition is considered essential
    /// for the presentation.
    public var forced: Bool

    /// The media initialization section for this rendition.
    public var instreamId: String?

    /// Characteristics of the rendition (e.g., accessibility descriptors).
    public var characteristics: String?

    /// The channels attribute (e.g., `"2"` for stereo, `"6"` for 5.1).
    public var channels: String?

    /// Creates a rendition.
    ///
    /// - Parameters:
    ///   - type: The media type.
    ///   - groupId: The group identifier.
    ///   - name: A human-readable name.
    ///   - uri: An optional media playlist URI.
    ///   - language: An optional BCP 47 language tag.
    ///   - assocLanguage: An optional associated language tag.
    ///   - isDefault: Whether this is the default rendition.
    ///   - autoselect: Whether the client may auto-select this rendition.
    ///   - forced: Whether this rendition is forced.
    ///   - instreamId: An optional instream identifier.
    ///   - characteristics: Optional rendition characteristics.
    ///   - channels: An optional channel configuration.
    public init(
        type: MediaType,
        groupId: String,
        name: String,
        uri: String? = nil,
        language: String? = nil,
        assocLanguage: String? = nil,
        isDefault: Bool = false,
        autoselect: Bool = false,
        forced: Bool = false,
        instreamId: String? = nil,
        characteristics: String? = nil,
        channels: String? = nil
    ) {
        self.type = type
        self.groupId = groupId
        self.name = name
        self.uri = uri
        self.language = language
        self.assocLanguage = assocLanguage
        self.isDefault = isDefault
        self.autoselect = autoselect
        self.forced = forced
        self.instreamId = instreamId
        self.characteristics = characteristics
        self.channels = channels
    }
}
