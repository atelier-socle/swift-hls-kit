// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Metadata that can be applied to a live playlist.
///
/// Used to configure playlist-level attributes like
/// independent segments hint, start offset, and custom tags.
public struct LivePlaylistMetadata: Sendable, Equatable {

    /// Whether all segments are independently decodable.
    ///
    /// When true, `EXT-X-INDEPENDENT-SEGMENTS` is added to the playlist.
    /// Required for certain multi-variant configurations.
    public var independentSegments: Bool

    /// Preferred start offset from the live edge (seconds).
    ///
    /// When set, renders `EXT-X-START:TIME-OFFSET=<value>`.
    /// Negative values indicate offset from the end.
    public var startOffset: TimeInterval?

    /// Whether the start offset is precise.
    ///
    /// When true, renders `PRECISE=YES` on the EXT-X-START tag.
    public var startPrecise: Bool

    /// Custom playlist-level tags to include.
    ///
    /// Each string is rendered as-is on its own line after the header.
    /// Example: `["#EXT-X-SESSION-DATA:DATA-ID=\"com.example.title\",VALUE=\"Live Show\""]`
    public var customTags: [String]

    /// Creates playlist metadata.
    ///
    /// - Parameters:
    ///   - independentSegments: Whether segments are independent.
    ///   - startOffset: Preferred start offset from live edge.
    ///   - startPrecise: Whether start offset is precise.
    ///   - customTags: Custom playlist-level tags.
    public init(
        independentSegments: Bool = false,
        startOffset: TimeInterval? = nil,
        startPrecise: Bool = false,
        customTags: [String] = []
    ) {
        self.independentSegments = independentSegments
        self.startOffset = startOffset
        self.startPrecise = startPrecise
        self.customTags = customTags
    }
}
