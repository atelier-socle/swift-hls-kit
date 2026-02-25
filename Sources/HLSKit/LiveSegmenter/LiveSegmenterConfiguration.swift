// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for a ``LiveSegmenter``.
///
/// Controls segment duration, ring buffer size, keyframe alignment,
/// and other segmentation parameters.
///
/// ## Presets
/// ```swift
/// let config = LiveSegmenterConfiguration.standardLive
/// let lowLatency = LiveSegmenterConfiguration.lowLatencyPrep
/// let audioOnly = LiveSegmenterConfiguration.audioOnly
/// ```
public struct LiveSegmenterConfiguration: Sendable, Equatable {

    /// Target segment duration in seconds.
    ///
    /// The actual segment duration may be slightly longer due to
    /// keyframe alignment (video) or frame boundary alignment (audio).
    /// Default: 6.0 (Apple recommendation for standard HLS).
    public var targetDuration: TimeInterval

    /// Maximum allowed segment duration in seconds.
    ///
    /// If no keyframe arrives within this duration, the segmenter
    /// forces a boundary anyway. Must be >= targetDuration.
    /// Default: targetDuration x 1.5
    public var maxDuration: TimeInterval

    /// Number of recent segments to keep in the ring buffer.
    ///
    /// Controls the DVR window. Set to 0 for live-edge only
    /// (no rewind). Default: 5 (~30 seconds at 6s segments).
    public var ringBufferSize: Int

    /// Whether to align segments on video keyframes.
    ///
    /// When true (default for video), segments start at IDR frames.
    /// When false (audio-only), segments cut at any frame boundary.
    public var keyframeAligned: Bool

    /// Starting segment index.
    ///
    /// Default: 0. Set to a higher value for continued streams
    /// (e.g., after a discontinuity or resume).
    public var startIndex: Int

    /// Whether to track PROGRAM-DATE-TIME for each segment.
    ///
    /// When true, each segment records its wall-clock start time.
    /// Required for DVR and EXT-X-PROGRAM-DATE-TIME in playlists.
    /// Default: true.
    public var trackProgramDateTime: Bool

    /// Segment naming pattern.
    ///
    /// Use `%d` for the segment index (e.g., "segment_%d.m4s").
    /// Default: "segment_%d.m4s".
    public var namingPattern: String

    /// Creates a live segmenter configuration.
    ///
    /// - Parameters:
    ///   - targetDuration: Target segment duration in seconds.
    ///   - maxDuration: Maximum allowed segment duration.
    ///     Defaults to targetDuration x 1.5.
    ///   - ringBufferSize: Number of segments to retain for DVR.
    ///   - keyframeAligned: Whether to align on video keyframes.
    ///   - startIndex: Starting segment index.
    ///   - trackProgramDateTime: Whether to track wall-clock time.
    ///   - namingPattern: Filename pattern with `%d` placeholder.
    public init(
        targetDuration: TimeInterval = 6.0,
        maxDuration: TimeInterval? = nil,
        ringBufferSize: Int = 5,
        keyframeAligned: Bool = true,
        startIndex: Int = 0,
        trackProgramDateTime: Bool = true,
        namingPattern: String = "segment_%d.m4s"
    ) {
        self.targetDuration = targetDuration
        self.maxDuration = maxDuration ?? targetDuration * 1.5
        self.ringBufferSize = ringBufferSize
        self.keyframeAligned = keyframeAligned
        self.startIndex = startIndex
        self.trackProgramDateTime = trackProgramDateTime
        self.namingPattern = namingPattern
    }

    // MARK: - Convenience Presets

    /// Standard live: 6s segments, 5-segment buffer,
    /// keyframe aligned.
    public static let standardLive =
        LiveSegmenterConfiguration()

    /// Low-latency prep: 2s segments, 8-segment buffer,
    /// keyframe aligned.
    /// (Full LL-HLS with partial segments comes later.)
    public static let lowLatencyPrep =
        LiveSegmenterConfiguration(
            targetDuration: 2.0,
            ringBufferSize: 8,
            keyframeAligned: true
        )

    /// Audio-only: 6s segments, no keyframe alignment,
    /// 5-segment buffer.
    public static let audioOnly =
        LiveSegmenterConfiguration(
            keyframeAligned: false
        )

    /// Long DVR: 6s segments, 60-segment buffer
    /// (~6 minutes rewind).
    public static let longDVR =
        LiveSegmenterConfiguration(
            ringBufferSize: 60
        )

    /// Event recording: 6s segments, unlimited buffer
    /// (no eviction).
    public static let eventRecording =
        LiveSegmenterConfiguration(
            ringBufferSize: .max
        )
}
