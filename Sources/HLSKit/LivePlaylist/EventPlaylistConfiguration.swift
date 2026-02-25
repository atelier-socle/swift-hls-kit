// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for an ``EventPlaylist``.
public struct EventPlaylistConfiguration: Sendable, Equatable {

    /// Expected target segment duration (seconds).
    ///
    /// Default: 6.0.
    public var targetDuration: TimeInterval

    /// HLS version to declare.
    ///
    /// Default: 7.
    public var version: Int

    /// URI for the fMP4 initialization segment.
    ///
    /// When set, `#EXT-X-MAP:URI="<value>"` is rendered in the
    /// playlist. Required for fMP4 (CMAF) content.
    /// Default: `nil` (no EXT-X-MAP tag).
    public var initSegmentURI: String?

    /// Creates an event playlist configuration.
    ///
    /// - Parameters:
    ///   - targetDuration: Expected target segment duration.
    ///   - version: HLS version to declare.
    ///   - initSegmentURI: URI for fMP4 init segment.
    public init(
        targetDuration: TimeInterval = 6.0,
        version: Int = 7,
        initSegmentURI: String? = nil
    ) {
        self.targetDuration = targetDuration
        self.version = version
        self.initSegmentURI = initSegmentURI
    }
}
