// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import os

/// Specialized segmenter for audio-only live streams.
///
/// Wraps ``IncrementalSegmenter`` with automatic fMP4 container
/// formatting via ``CMAFWriter``. Produces segments with proper
/// CMAF-compliant moof+mdat boxes.
///
/// ## Container Formats
/// - `.fmp4`: Segments wrapped in fMP4 containers (default,
///   required for CMAF/LL-HLS)
/// - `.rawData`: Segments contain raw concatenated frame data
///   (for debugging or custom packaging)
///
/// ## Usage
/// ```swift
/// let segmenter = AudioSegmenter(
///     audioConfig: .init(sampleRate: 48000, channels: 2),
///     configuration: .audioOnly
/// )
/// Task {
///     for await segment in segmenter.segments {
///         // Write segment to disk, update playlist...
///     }
/// }
/// for await frame in encoder.outputFrames {
///     try await segmenter.ingest(frame)
/// }
/// let last = try await segmenter.finish()
/// ```
public actor AudioSegmenter: LiveSegmenter {

    /// Container format for output segments.
    public enum ContainerFormat: Sendable {

        /// fMP4 container (styp + moof + mdat).
        case fmp4

        /// Raw concatenated frame data (no container).
        case rawData
    }

    /// The audio configuration for fMP4 init segments.
    nonisolated public let audioConfig: CMAFWriter.AudioConfig

    /// The container format for output segments.
    nonisolated public let containerFormat: ContainerFormat

    /// The segmenter configuration.
    nonisolated public let configuration: LiveSegmenterConfiguration

    /// Pre-generated initialization segment (ftyp + moov).
    ///
    /// Non-nil only when ``containerFormat`` is `.fmp4`.
    nonisolated public let initSegment: Data?

    /// Stream of completed segments.
    nonisolated public let segments: AsyncStream<LiveSegment>

    // MARK: - Private

    private let inner: IncrementalSegmenter
    private let sequenceCounter: OSAllocatedUnfairLock<UInt32>

    /// Creates an audio segmenter.
    ///
    /// - Parameters:
    ///   - audioConfig: Audio codec configuration for fMP4.
    ///   - configuration: Segmentation configuration.
    ///     Defaults to ``LiveSegmenterConfiguration/audioOnly``.
    ///   - containerFormat: Container format for segments.
    ///     Defaults to `.fmp4`.
    public init(
        audioConfig: CMAFWriter.AudioConfig,
        configuration: LiveSegmenterConfiguration = .audioOnly,
        containerFormat: ContainerFormat = .fmp4
    ) {
        self.audioConfig = audioConfig
        self.containerFormat = containerFormat
        self.configuration = configuration

        let cmafWriter = CMAFWriter()
        let counter = OSAllocatedUnfairLock(initialState: UInt32(0))
        self.sequenceCounter = counter

        switch containerFormat {
        case .fmp4:
            self.initSegment = cmafWriter.generateAudioInitSegment(
                config: audioConfig
            )
            let timescale = audioConfig.timescale
            let trackID = audioConfig.trackID
            let transform: @Sendable (LiveSegment, [EncodedFrame]) -> LiveSegment =
                { segment, frames in
                    let seq = counter.withLock { value -> UInt32 in
                        value += 1
                        return value
                    }
                    let mediaData = cmafWriter.generateMediaSegment(
                        frames: frames,
                        sequenceNumber: seq,
                        trackID: trackID,
                        timescale: timescale
                    )
                    return LiveSegment(
                        index: segment.index,
                        data: mediaData,
                        duration: segment.duration,
                        timestamp: segment.timestamp,
                        isIndependent: segment.isIndependent,
                        programDateTime: segment.programDateTime,
                        filename: segment.filename,
                        frameCount: segment.frameCount,
                        codecs: segment.codecs
                    )
                }
            self.inner = IncrementalSegmenter(
                configuration: configuration,
                segmentTransform: transform
            )

        case .rawData:
            self.initSegment = nil
            self.inner = IncrementalSegmenter(
                configuration: configuration
            )
        }

        self.segments = inner.segments
    }

    // MARK: - LiveSegmenter

    /// Ingest an encoded audio frame.
    ///
    /// - Parameter frame: An encoded audio frame.
    /// - Throws: ``LiveSegmenterError`` on failure.
    public func ingest(_ frame: EncodedFrame) async throws {
        try await inner.ingest(frame)
    }

    /// Force the current segment to close immediately.
    ///
    /// - Throws: ``LiveSegmenterError`` if no frames pending.
    public func forceSegmentBoundary() async throws {
        try await inner.forceSegmentBoundary()
    }

    /// Finalize the last segment and stop the segmenter.
    ///
    /// - Returns: The final segment, or nil if no frames pending.
    public func finish() async throws -> LiveSegment? {
        try await inner.finish()
    }

    // MARK: - Ring Buffer Access

    /// Access recent segments from the ring buffer.
    public var recentSegments: [LiveSegment] {
        get async {
            await inner.recentSegments
        }
    }

    /// Total number of segments emitted.
    public var segmentCount: Int {
        get async {
            await inner.segmentCount
        }
    }
}
