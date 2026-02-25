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
    public init(
        partTargetDuration: TimeInterval = 0.33334,
        maxPartialsPerSegment: Int = 6,
        segmentTargetDuration: TimeInterval = 2.0,
        retainedPartialSegments: Int = 3,
        partialURITemplate: String = "seg{segment}.{part}.{ext}",
        fileExtension: String = "mp4",
        includeProgramDateTime: Bool = false
    ) {
        self.partTargetDuration = partTargetDuration
        self.maxPartialsPerSegment = maxPartialsPerSegment
        self.segmentTargetDuration = segmentTargetDuration
        self.retainedPartialSegments = retainedPartialSegments
        self.partialURITemplate = partialURITemplate
        self.fileExtension = fileExtension
        self.includeProgramDateTime = includeProgramDateTime
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
    public static let ultraLowLatency = LLHLSConfiguration(
        partTargetDuration: 0.2,
        maxPartialsPerSegment: 5,
        segmentTargetDuration: 1.0,
        retainedPartialSegments: 4
    )

    /// Low-latency preset: 0.33 s parts, 2 s segments.
    ///
    /// Suitable for sports and live news.
    public static let lowLatency = LLHLSConfiguration(
        partTargetDuration: 0.33334,
        maxPartialsPerSegment: 6,
        segmentTargetDuration: 2.0,
        retainedPartialSegments: 3
    )

    /// Balanced preset: 0.5 s parts, 4 s segments.
    ///
    /// Suitable for general-purpose live streaming.
    public static let balanced = LLHLSConfiguration(
        partTargetDuration: 0.5,
        maxPartialsPerSegment: 8,
        segmentTargetDuration: 4.0,
        retainedPartialSegments: 3
    )
}
