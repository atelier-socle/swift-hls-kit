// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A media segment within an HLS media playlist.
///
/// Each segment is described by an `EXTINF` tag specifying its
/// duration, followed by a URI line pointing to the media resource.
/// Additional segment-level tags (byte range, encryption, etc.) may
/// precede the `EXTINF` tag. See RFC 8216 Section 4.3.2.
public struct Segment: Sendable, Hashable, Codable {

    /// The duration of the segment in seconds.
    ///
    /// Corresponds to the duration value of the `EXTINF` tag.
    /// In protocol versions 3 and above this is a floating-point value.
    public var duration: Double

    /// The URI of the media resource.
    public var uri: String

    /// An optional human-readable title for the segment.
    ///
    /// Corresponds to the title field of the `EXTINF` tag.
    public var title: String?

    /// The byte range within the resource, if this segment
    /// is a sub-range of a larger file.
    ///
    /// Corresponds to the `EXT-X-BYTERANGE` tag.
    public var byteRange: ByteRange?

    /// The encryption parameters for this segment.
    ///
    /// Corresponds to the `EXT-X-KEY` tag that applies to this segment.
    public var key: EncryptionKey?

    /// The media initialization section for this segment.
    ///
    /// Corresponds to the `EXT-X-MAP` tag.
    public var map: MapTag?

    /// The absolute date and time of the first sample.
    ///
    /// Corresponds to the `EXT-X-PROGRAM-DATE-TIME` tag.
    public var programDateTime: Date?

    /// Whether there is a discontinuity before this segment.
    ///
    /// Corresponds to the `EXT-X-DISCONTINUITY` tag.
    public var discontinuity: Bool

    /// Whether this segment represents a gap in the presentation.
    ///
    /// Corresponds to the `EXT-X-GAP` tag.
    public var isGap: Bool

    /// The approximate bitrate of this segment in bits per second.
    ///
    /// Corresponds to the `EXT-X-BITRATE` tag.
    public var bitrate: Int?

    /// Creates a new segment.
    ///
    /// - Parameters:
    ///   - duration: The segment duration in seconds.
    ///   - uri: The URI of the media resource.
    ///   - title: An optional title.
    ///   - byteRange: An optional byte range.
    ///   - key: Optional encryption parameters.
    ///   - map: An optional media initialization section.
    ///   - programDateTime: An optional absolute timestamp.
    ///   - discontinuity: Whether a discontinuity precedes this segment.
    ///   - isGap: Whether this segment is a gap.
    ///   - bitrate: An optional approximate bitrate.
    public init(
        duration: Double,
        uri: String,
        title: String? = nil,
        byteRange: ByteRange? = nil,
        key: EncryptionKey? = nil,
        map: MapTag? = nil,
        programDateTime: Date? = nil,
        discontinuity: Bool = false,
        isGap: Bool = false,
        bitrate: Int? = nil
    ) {
        self.duration = duration
        self.uri = uri
        self.title = title
        self.byteRange = byteRange
        self.key = key
        self.map = map
        self.programDateTime = programDateTime
        self.discontinuity = discontinuity
        self.isGap = isGap
        self.bitrate = bitrate
    }
}

// MARK: - ByteRange

/// A byte range within a resource, used by `EXT-X-BYTERANGE`.
///
/// Specifies a contiguous sub-range of a resource identified by its
/// length and an optional offset. If the offset is absent, the range
/// starts at the byte following the last byte of the previous sub-range.
public struct ByteRange: Sendable, Hashable, Codable {

    /// The number of bytes in the range.
    public let length: Int

    /// The byte offset from the beginning of the resource.
    /// If `nil`, the range begins at the end of the previous sub-range.
    public let offset: Int?

    /// Creates a byte range.
    ///
    /// - Parameters:
    ///   - length: The number of bytes.
    ///   - offset: The optional byte offset.
    public init(length: Int, offset: Int? = nil) {
        self.length = length
        self.offset = offset
    }
}

// MARK: - EncryptionKey

/// Encryption parameters for media segments, from `EXT-X-KEY`.
///
/// See RFC 8216 Section 4.3.2.4.
public struct EncryptionKey: Sendable, Hashable, Codable {

    /// The encryption method.
    public var method: EncryptionMethod

    /// The URI of the key resource.
    public var uri: String?

    /// The initialization vector as a hexadecimal string.
    public var iv: String?

    /// The key format identifier (e.g., `"identity"`).
    public var keyFormat: String?

    /// The key format versions.
    public var keyFormatVersions: String?

    /// Creates encryption key parameters.
    ///
    /// - Parameters:
    ///   - method: The encryption method.
    ///   - uri: The key URI.
    ///   - iv: The initialization vector.
    ///   - keyFormat: The key format identifier.
    ///   - keyFormatVersions: The key format versions.
    public init(
        method: EncryptionMethod,
        uri: String? = nil,
        iv: String? = nil,
        keyFormat: String? = nil,
        keyFormatVersions: String? = nil
    ) {
        self.method = method
        self.uri = uri
        self.iv = iv
        self.keyFormat = keyFormat
        self.keyFormatVersions = keyFormatVersions
    }
}

// MARK: - MapTag

/// A media initialization section from `EXT-X-MAP`.
///
/// The map tag specifies how to obtain the initialization section
/// required to parse the media segments. See RFC 8216 Section 4.3.2.5.
public struct MapTag: Sendable, Hashable, Codable {

    /// The URI of the initialization section.
    public var uri: String

    /// An optional byte range within the resource.
    public var byteRange: ByteRange?

    /// Creates a map tag.
    ///
    /// - Parameters:
    ///   - uri: The URI of the initialization section.
    ///   - byteRange: An optional byte range.
    public init(uri: String, byteRange: ByteRange? = nil) {
        self.uri = uri
        self.byteRange = byteRange
    }
}
