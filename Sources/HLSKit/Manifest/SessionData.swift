// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Arbitrary session-level data in a master playlist.
///
/// Corresponds to the `EXT-X-SESSION-DATA` tag (RFC 8216 Section 4.3.4.4).
/// Session data allows a master playlist to carry metadata that is not
/// part of the media content itself.
public struct SessionData: Sendable, Hashable, Codable {

    /// A unique identifier for this session data.
    public var dataId: String

    /// The value of the session data. Mutually exclusive with ``uri``.
    public var value: String?

    /// A URI to a JSON resource containing the session data.
    /// Mutually exclusive with ``value``.
    public var uri: String?

    /// The language of the session data as a BCP 47 language tag.
    public var language: String?

    /// Creates session data.
    ///
    /// - Parameters:
    ///   - dataId: A unique identifier.
    ///   - value: An optional inline value.
    ///   - uri: An optional URI to a JSON resource.
    ///   - language: An optional language tag.
    public init(
        dataId: String,
        value: String? = nil,
        uri: String? = nil,
        language: String? = nil
    ) {
        self.dataId = dataId
        self.value = value
        self.uri = uri
        self.language = language
    }
}
