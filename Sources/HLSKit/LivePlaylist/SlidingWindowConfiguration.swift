// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for a ``SlidingWindowPlaylist``.
public struct SlidingWindowConfiguration: Sendable, Equatable {

    /// Number of segments to keep in the playlist window.
    ///
    /// When the playlist exceeds this count, the oldest segment is evicted.
    /// Apple recommends at least 3 segments in a live playlist.
    /// Default: 5.
    public var windowSize: Int

    /// Expected target segment duration (seconds).
    ///
    /// Used as the fallback `EXT-X-TARGETDURATION` when no segments exist.
    /// The actual target duration is always computed from real segment
    /// durations.
    /// Default: 6.0.
    public var targetDuration: TimeInterval

    /// HLS version to declare in the playlist.
    ///
    /// Default: 7 (supports EXT-X-MAP for fMP4).
    public var version: Int

    /// Creates a sliding window configuration.
    ///
    /// - Parameters:
    ///   - windowSize: Number of segments to keep.
    ///   - targetDuration: Expected target segment duration.
    ///   - version: HLS version to declare.
    public init(
        windowSize: Int = 5,
        targetDuration: TimeInterval = 6.0,
        version: Int = 7
    ) {
        self.windowSize = windowSize
        self.targetDuration = targetDuration
        self.version = version
    }
}
