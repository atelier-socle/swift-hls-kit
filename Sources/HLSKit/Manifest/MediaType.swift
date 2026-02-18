// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// The media type of a rendition group as declared by `EXT-X-MEDIA`.
///
/// Per RFC 8216 Section 4.3.4.1, the `TYPE` attribute specifies
/// the media type of the rendition.
public enum MediaType: String, Sendable, Hashable, Codable, CaseIterable {

    /// An audio rendition.
    case audio = "AUDIO"

    /// A video rendition.
    case video = "VIDEO"

    /// A subtitle rendition.
    case subtitles = "SUBTITLES"

    /// A closed-captions rendition. These renditions do not have a URI
    /// because closed captions are carried in the video stream.
    case closedCaptions = "CLOSED-CAPTIONS"
}
