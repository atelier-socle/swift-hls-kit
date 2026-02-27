// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Specialized segmenter for video (with optional audio) live streams.
///
/// Manages dual ``IncrementalSegmenter`` instances — one for video
/// (keyframe-aligned) and one for audio (duration-aligned).
/// Audio segments are synchronized to video segment boundaries.
///
/// ## Segment Output
/// Each ``SegmentOutput`` pairs a video segment with its corresponding
/// audio segment (if audio is being ingested). Outputs are emitted
/// via the ``segmentOutputs`` async stream.
///
/// ## Usage
/// ```swift
/// let segmenter = VideoSegmenter(
///     videoConfig: .init(codec: .h264, width: 1920, height: 1080,
///                        sps: spsData, pps: ppsData),
///     audioConfig: .init(sampleRate: 48000, channels: 2)
/// )
/// Task {
///     for await output in segmenter.segmentOutputs {
///         // Write video + audio segments...
///     }
/// }
/// // Ingest frames from encoders
/// try await segmenter.ingestVideo(videoFrame)
/// try await segmenter.ingestAudio(audioFrame)
/// let final = try await segmenter.finish()
/// ```
public actor VideoSegmenter {

    /// A paired output of video and optional audio segments.
    public struct SegmentOutput: Sendable {

        /// The video segment.
        public let videoSegment: LiveSegment

        /// The audio segment, if audio is being segmented.
        public let audioSegment: LiveSegment?

        /// Output index (matches video segment index).
        public let index: Int
    }

    /// Video codec configuration.
    nonisolated public let videoConfig: CMAFWriter.VideoConfig

    /// Audio codec configuration (nil for video-only).
    nonisolated public let audioConfig: CMAFWriter.AudioConfig?

    /// Pre-generated video initialization segment (ftyp + moov).
    nonisolated public let videoInitSegment: Data

    /// Pre-generated audio initialization segment (ftyp + moov).
    /// Nil for video-only streams.
    nonisolated public let audioInitSegment: Data?

    /// Stream of paired segment outputs.
    nonisolated public let segmentOutputs: AsyncStream<SegmentOutput>

    // MARK: - Private

    private let videoSegmenter: IncrementalSegmenter
    private let audioSegmenter: IncrementalSegmenter?
    private let outputContinuation: AsyncStream<SegmentOutput>.Continuation
    private var videoSegmentCount: Int = 0
    private var isFinished = false
    private var syncTask: Task<Void, Never>?

    /// Creates a video segmenter.
    ///
    /// - Parameters:
    ///   - videoConfig: Video codec configuration.
    ///   - audioConfig: Audio codec configuration. Pass nil for
    ///     video-only streams.
    ///   - configuration: Segmentation configuration.
    ///     Defaults to ``LiveSegmenterConfiguration/standardLive``.
    public init(
        videoConfig: CMAFWriter.VideoConfig,
        audioConfig: CMAFWriter.AudioConfig? = nil,
        configuration: LiveSegmenterConfiguration = .standardLive
    ) {
        self.videoConfig = videoConfig
        self.audioConfig = audioConfig

        let cmafWriter = CMAFWriter()

        self.videoInitSegment =
            cmafWriter.generateVideoInitSegment(config: videoConfig)
        self.audioInitSegment = audioConfig.map {
            cmafWriter.generateAudioInitSegment(config: $0)
        }

        // Video segmenter (keyframe-aligned)
        var videoConf = configuration
        videoConf.keyframeAligned = true
        self.videoSegmenter = IncrementalSegmenter(
            configuration: videoConf,
            segmentTransform: Self.makeTransform(
                writer: cmafWriter,
                trackID: videoConfig.trackID,
                timescale: videoConfig.timescale
            )
        )

        // Audio segmenter (non-keyframe-aligned)
        if let audioConfig {
            var audioConf = configuration
            audioConf.keyframeAligned = false
            self.audioSegmenter = IncrementalSegmenter(
                configuration: audioConf,
                segmentTransform: Self.makeTransform(
                    writer: cmafWriter,
                    trackID: audioConfig.trackID,
                    timescale: audioConfig.timescale
                )
            )
        } else {
            self.audioSegmenter = nil
        }

        let (stream, continuation) = AsyncStream.makeStream(
            of: SegmentOutput.self
        )
        self.segmentOutputs = stream
        self.outputContinuation = continuation
    }

    // MARK: - Transform Builder

    private static func makeTransform(
        writer: CMAFWriter,
        trackID: UInt32,
        timescale: UInt32
    ) -> @Sendable (LiveSegment, [EncodedFrame]) -> LiveSegment {
        let counter = LockedState(
            initialState: UInt32(0)
        )
        return { segment, frames in
            let seq = counter.withLock { val -> UInt32 in
                val += 1
                return val
            }
            let data = writer.generateMediaSegment(
                frames: frames,
                sequenceNumber: seq,
                trackID: trackID,
                timescale: timescale
            )
            return LiveSegment(
                index: segment.index,
                data: data,
                duration: segment.duration,
                timestamp: segment.timestamp,
                isIndependent: segment.isIndependent,
                programDateTime: segment.programDateTime,
                filename: segment.filename,
                frameCount: segment.frameCount,
                codecs: segment.codecs
            )
        }
    }

    // MARK: - Ingest

    /// Ingest a video frame.
    ///
    /// - Parameter frame: An encoded video frame.
    /// - Throws: ``LiveSegmenterError`` if the codec is not video
    ///   or the segmenter is finished.
    public func ingestVideo(
        _ frame: EncodedFrame
    ) async throws {
        guard frame.codec.isVideo else {
            throw LiveSegmenterError.invalidConfiguration(
                "Expected video codec, got \(frame.codec)"
            )
        }
        guard !isFinished else {
            throw LiveSegmenterError.notActive
        }

        let countBefore = await videoSegmenter.segmentCount
        try await videoSegmenter.ingest(frame)
        let countAfter = await videoSegmenter.segmentCount

        // Video emitted a new segment — sync audio
        if countAfter > countBefore {
            if let audioSeg = audioSegmenter {
                try? await audioSeg.forceSegmentBoundary()
            }
            await emitOutput()
        }
    }

    /// Ingest an audio frame.
    ///
    /// - Parameter frame: An encoded audio frame.
    /// - Throws: ``LiveSegmenterError`` if the codec is not audio,
    ///   no audio config was provided, or the segmenter is finished.
    public func ingestAudio(
        _ frame: EncodedFrame
    ) async throws {
        guard frame.codec.isAudio else {
            throw LiveSegmenterError.invalidConfiguration(
                "Expected audio codec, got \(frame.codec)"
            )
        }
        guard let audioSeg = audioSegmenter else {
            throw LiveSegmenterError.invalidConfiguration(
                "No audio config provided"
            )
        }
        guard !isFinished else {
            throw LiveSegmenterError.notActive
        }
        try await audioSeg.ingest(frame)
    }

    // MARK: - Finish

    /// Finalize the segmenter and return the last output.
    ///
    /// - Returns: The final segment output, or nil if no frames
    ///   were pending.
    public func finish() async throws -> SegmentOutput? {
        guard !isFinished else { return nil }
        isFinished = true

        let videoFinal = try await videoSegmenter.finish()
        let audioFinal: LiveSegment?
        if let audioSeg = audioSegmenter {
            audioFinal = try await audioSeg.finish()
        } else {
            audioFinal = nil
        }

        let output: SegmentOutput?
        if let videoFinal {
            let result = SegmentOutput(
                videoSegment: videoFinal,
                audioSegment: audioFinal,
                index: videoFinal.index
            )
            outputContinuation.yield(result)
            output = result
        } else {
            output = nil
        }
        outputContinuation.finish()
        return output
    }

    // MARK: - Private

    private func emitOutput() async {
        let videoSegments = await videoSegmenter.recentSegments
        guard let latestVideo = videoSegments.last else {
            return
        }
        let latestAudio: LiveSegment?
        if let audioSeg = audioSegmenter {
            let audioSegments = await audioSeg.recentSegments
            latestAudio = audioSegments.last
        } else {
            latestAudio = nil
        }
        let output = SegmentOutput(
            videoSegment: latestVideo,
            audioSegment: latestAudio,
            index: latestVideo.index
        )
        outputContinuation.yield(output)
    }
}
