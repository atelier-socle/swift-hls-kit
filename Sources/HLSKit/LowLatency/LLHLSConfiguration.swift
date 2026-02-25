// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for the Low-Latency HLS pipeline.
///
/// Controls partial segment timing, URI generation, and retention
/// policy. Presets are provided for common use cases.
///
/// ## Presets
/// - ``ultraLowLatency`` — 0.2 s parts, 1 s segments (gaming, auctions)
/// - ``lowLatency`` — 0.33 s parts, 2 s segments (sports, news)
/// - ``balanced`` — 0.5 s parts, 4 s segments (general live)
///
/// ## URI Template
/// The ``partialURITemplate`` supports these placeholders:
/// - `{segment}` — segment index
/// - `{part}` — partial index within the segment
/// - `{ext}` — file extension (``fileExtension``)
///
/// ```swift
/// let config = LLHLSConfiguration(
///     partTargetDuration: 0.33334,
///     partialURITemplate: "seg{segment}.{part}.{ext}"
/// )
/// let uri = config.resolveURI(segmentIndex: 3, partialIndex: 1)
/// // "seg3.1.mp4"
/// ```
public struct LLHLSConfiguration: Sendable, Equatable {

    /// Target duration for partial segments in seconds.
    ///
    /// Advertised via `EXT-X-PART-INF:PART-TARGET=`.
    /// Typical values: 0.2–1.0 s.
    public var partTargetDuration: TimeInterval

    /// Maximum number of partials allowed per full segment.
    public var maxPartialsPerSegment: Int

    /// Target duration for full segments in seconds.
    public var segmentTargetDuration: TimeInterval

    /// Number of recent completed segments whose partials are
    /// retained for playlist rendering.
    public var retainedPartialSegments: Int

    /// URI template for auto-generated partial URIs.
    ///
    /// Placeholders: `{segment}`, `{part}`, `{ext}`.
    public var partialURITemplate: String

    /// File extension for partial segments (without leading dot).
    public var fileExtension: String

    /// Whether to include `EXT-X-PROGRAM-DATE-TIME` tags.
    public var includeProgramDateTime: Bool

    /// Server control configuration.
    ///
    /// If `nil`, a default ``ServerControlConfig/standard(targetDuration:partTargetDuration:)``
    /// configuration is used at render time.
    public var serverControl: ServerControlConfig?

    /// Creates a LL-HLS configuration.
    ///
    /// - Parameters:
    ///   - partTargetDuration: Target partial duration. Default `0.33334`.
    ///   - maxPartialsPerSegment: Max partials per segment. Default `6`.
    ///   - segmentTargetDuration: Target full-segment duration. Default `2.0`.
    ///   - retainedPartialSegments: Segments whose partials to keep. Default `3`.
    ///   - partialURITemplate: URI template. Default `"seg{segment}.{part}.{ext}"`.
    ///   - fileExtension: File extension. Default `"mp4"`.
    ///   - includeProgramDateTime: Include PROGRAM-DATE-TIME. Default `false`.
    ///   - serverControl: Server control configuration. Default `nil`.
    public init(
        partTargetDuration: TimeInterval = 0.33334,
        maxPartialsPerSegment: Int = 6,
        segmentTargetDuration: TimeInterval = 2.0,
        retainedPartialSegments: Int = 3,
        partialURITemplate: String = "seg{segment}.{part}.{ext}",
        fileExtension: String = "mp4",
        includeProgramDateTime: Bool = false,
        serverControl: ServerControlConfig? = nil
    ) {
        self.partTargetDuration = partTargetDuration
        self.maxPartialsPerSegment = maxPartialsPerSegment
        self.segmentTargetDuration = segmentTargetDuration
        self.retainedPartialSegments = retainedPartialSegments
        self.partialURITemplate = partialURITemplate
        self.fileExtension = fileExtension
        self.includeProgramDateTime = includeProgramDateTime
        self.serverControl = serverControl
    }

    // MARK: - URI Resolution

    /// Resolves a URI from the template for the given indices.
    ///
    /// - Parameters:
    ///   - segmentIndex: The segment index.
    ///   - partialIndex: The partial index within the segment.
    /// - Returns: A resolved URI string.
    public func resolveURI(
        segmentIndex: Int, partialIndex: Int
    ) -> String {
        partialURITemplate
            .replacingOccurrences(
                of: "{segment}", with: "\(segmentIndex)"
            )
            .replacingOccurrences(
                of: "{part}", with: "\(partialIndex)"
            )
            .replacingOccurrences(
                of: "{ext}", with: fileExtension
            )
    }

    // MARK: - Presets

    /// Ultra-low-latency preset: 0.2 s parts, 1 s segments.
    ///
    /// Suitable for gaming, auctions, and interactive scenarios.
    /// Includes server control with delta updates.
    public static let ultraLowLatency = LLHLSConfiguration(
        partTargetDuration: 0.2,
        maxPartialsPerSegment: 5,
        segmentTargetDuration: 1.0,
        retainedPartialSegments: 4,
        serverControl: .withDeltaUpdates(
            targetDuration: 1.0, partTargetDuration: 0.2
        )
    )

    /// Low-latency preset: 0.33 s parts, 2 s segments.
    ///
    /// Suitable for sports and live news.
    /// Includes server control with delta updates.
    public static let lowLatency = LLHLSConfiguration(
        partTargetDuration: 0.33334,
        maxPartialsPerSegment: 6,
        segmentTargetDuration: 2.0,
        retainedPartialSegments: 3,
        serverControl: .withDeltaUpdates(
            targetDuration: 2.0, partTargetDuration: 0.33334
        )
    )

    /// Balanced preset: 0.5 s parts, 4 s segments.
    ///
    /// Suitable for general-purpose live streaming.
    /// Includes standard server control (no delta updates).
    public static let balanced = LLHLSConfiguration(
        partTargetDuration: 0.5,
        maxPartialsPerSegment: 8,
        segmentTargetDuration: 4.0,
        retainedPartialSegments: 3,
        serverControl: .standard(
            targetDuration: 4.0, partTargetDuration: 0.5
        )
    )
}

// MARK: - Version

extension LLHLSConfiguration {

    /// HLS version for LL-HLS playlists (always 7+).
    var version: Int { 7 }
}
