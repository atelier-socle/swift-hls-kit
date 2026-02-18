// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Result of a single-variant transcoding operation.
///
/// Contains output file information, timing data, and optionally
/// the segmentation result for the transcoded content.
///
/// ```swift
/// let result = try await transcoder.transcode(
///     input: sourceURL,
///     outputDirectory: outputDir,
///     config: config
/// )
/// print("Speed: \(result.speedFactor)x")
/// ```
///
/// - SeeAlso: ``Transcoder``, ``MultiVariantResult``
public struct TranscodingResult: Sendable {

    /// The quality preset that was used.
    public let preset: QualityPreset

    /// Output directory containing the transcoded files.
    public let outputDirectory: URL

    /// Segmentation result (init segment + media segments + playlist).
    public let segmentation: SegmentationResult?

    /// Output media file URL (before segmentation, if kept).
    public let outputFile: URL?

    /// Transcoding duration in seconds.
    public let transcodingDuration: Double

    /// Source file duration in seconds.
    public let sourceDuration: Double

    /// Speed factor (e.g., 2.5x means 2.5 seconds of video
    /// per second of encoding).
    public var speedFactor: Double {
        guard transcodingDuration > 0 else { return 0 }
        return sourceDuration / transcodingDuration
    }

    /// Actual output video bitrate.
    public let actualVideoBitrate: Int?

    /// Actual output audio bitrate.
    public let actualAudioBitrate: Int?

    /// Output file size in bytes.
    public let outputSize: UInt64

    /// Creates a transcoding result.
    ///
    /// - Parameters:
    ///   - preset: The quality preset used.
    ///   - outputDirectory: Output directory URL.
    ///   - segmentation: Segmentation result.
    ///   - outputFile: Output media file URL.
    ///   - transcodingDuration: Time spent transcoding.
    ///   - sourceDuration: Duration of the source file.
    ///   - actualVideoBitrate: Actual output video bitrate.
    ///   - actualAudioBitrate: Actual output audio bitrate.
    ///   - outputSize: Output file size in bytes.
    public init(
        preset: QualityPreset,
        outputDirectory: URL,
        segmentation: SegmentationResult? = nil,
        outputFile: URL? = nil,
        transcodingDuration: Double,
        sourceDuration: Double,
        actualVideoBitrate: Int? = nil,
        actualAudioBitrate: Int? = nil,
        outputSize: UInt64
    ) {
        self.preset = preset
        self.outputDirectory = outputDirectory
        self.segmentation = segmentation
        self.outputFile = outputFile
        self.transcodingDuration = transcodingDuration
        self.sourceDuration = sourceDuration
        self.actualVideoBitrate = actualVideoBitrate
        self.actualAudioBitrate = actualAudioBitrate
        self.outputSize = outputSize
    }
}

// MARK: - MultiVariantResult

/// Result of multi-variant transcoding (adaptive bitrate).
///
/// Contains results for each quality variant, plus the generated
/// master playlist that ties them together.
///
/// - SeeAlso: ``TranscodingResult``
public struct MultiVariantResult: Sendable {

    /// Per-variant results.
    public let variants: [TranscodingResult]

    /// Generated master playlist M3U8 content.
    public let masterPlaylist: String?

    /// Output directory containing all variants.
    public let outputDirectory: URL

    /// Total transcoding duration across all variants.
    public var totalTranscodingDuration: Double {
        variants.reduce(0) { $0 + $1.transcodingDuration }
    }

    /// Total output size across all variants.
    public var totalOutputSize: UInt64 {
        variants.reduce(0) { $0 + $1.outputSize }
    }

    /// Creates a multi-variant result.
    ///
    /// - Parameters:
    ///   - variants: Per-variant transcoding results.
    ///   - masterPlaylist: Generated master playlist string.
    ///   - outputDirectory: Root output directory.
    public init(
        variants: [TranscodingResult],
        masterPlaylist: String?,
        outputDirectory: URL
    ) {
        self.variants = variants
        self.masterPlaylist = masterPlaylist
        self.outputDirectory = outputDirectory
    }
}
