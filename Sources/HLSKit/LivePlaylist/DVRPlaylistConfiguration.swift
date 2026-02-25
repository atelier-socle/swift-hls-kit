// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for a ``DVRPlaylist``.
///
/// Controls the DVR window duration, target segment duration,
/// and HLS version. Includes convenience presets for common
/// DVR scenarios.
///
/// ## Presets
/// - ``shortDVR``: 30 minutes
/// - ``standardDVR``: 2 hours (default)
/// - ``longDVR``: 8 hours (full event)
public struct DVRPlaylistConfiguration: Sendable, Equatable {

    /// DVR window duration in seconds.
    ///
    /// Segments older than this duration (from the live edge) are evicted.
    /// Default: 7200 (2 hours).
    public var dvrWindowDuration: TimeInterval

    /// Expected target segment duration (seconds).
    ///
    /// Used as fallback for `EXT-X-TARGETDURATION` when no segments
    /// are in the buffer. Default: 6.0.
    public var targetDuration: TimeInterval

    /// HLS version for the `EXT-X-VERSION` tag.
    ///
    /// Default: 7.
    public var version: Int

    /// URI for the fMP4 initialization segment.
    ///
    /// When set, `#EXT-X-MAP:URI="<value>"` is rendered in the
    /// playlist. Required for fMP4 (CMAF) content.
    /// Default: `nil` (no EXT-X-MAP tag).
    public var initSegmentURI: String?

    /// Creates a DVR playlist configuration.
    ///
    /// - Parameters:
    ///   - dvrWindowDuration: DVR window in seconds. Default: 7200.
    ///   - targetDuration: Target segment duration. Default: 6.0.
    ///   - version: HLS version. Default: 7.
    ///   - initSegmentURI: URI for fMP4 init segment.
    public init(
        dvrWindowDuration: TimeInterval = 7200,
        targetDuration: TimeInterval = 6.0,
        version: Int = 7,
        initSegmentURI: String? = nil
    ) {
        self.dvrWindowDuration = dvrWindowDuration
        self.targetDuration = targetDuration
        self.version = version
        self.initSegmentURI = initSegmentURI
    }

    // MARK: - Convenience Presets

    /// Short DVR: 30 minutes.
    public static let shortDVR = DVRPlaylistConfiguration(
        dvrWindowDuration: 1800
    )

    /// Standard DVR: 2 hours.
    public static let standardDVR = DVRPlaylistConfiguration()

    /// Long DVR: 8 hours (full event).
    public static let longDVR = DVRPlaylistConfiguration(
        dvrWindowDuration: 28800
    )
}
