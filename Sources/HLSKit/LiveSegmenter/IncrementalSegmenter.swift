// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// General-purpose incremental segmenter for live HLS streams.
///
/// Accumulates ``EncodedFrame`` objects and produces ``LiveSegment``
/// objects when the target duration is reached and a keyframe
/// boundary is found.
///
/// ## Segmentation Algorithm
///
/// For **video** (keyframeAligned = true):
/// 1. Accumulate frames
/// 2. When accumulated duration >= targetDuration:
///    - Wait for the next keyframe
///    - Emit all frames up to (but not including) the keyframe
///    - Start a new segment with the keyframe
/// 3. If accumulated duration >= maxDuration and no keyframe:
///    - Force-emit the segment (may not start with keyframe)
///
/// For **audio-only** (keyframeAligned = false):
/// 1. Accumulate frames
/// 2. When accumulated duration >= targetDuration:
///    - Emit immediately (every audio frame is independent)
///
/// ## Usage
/// ```swift
/// let segmenter = IncrementalSegmenter(
///     configuration: .standardLive
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
public actor IncrementalSegmenter: LiveSegmenter {

    /// Configuration for this segmenter.
    public let configuration: LiveSegmenterConfiguration

    // MARK: - Segment Output Stream

    /// Stream of completed segments.
    nonisolated public let segments: AsyncStream<LiveSegment>

    private let segmentContinuation: AsyncStream<LiveSegment>.Continuation

    // MARK: - Current Segment State

    private var currentFrames: [EncodedFrame] = []
    private var currentDuration: TimeInterval = 0
    private var currentTimestamp: MediaTimestamp?
    private var currentCodecs: Set<EncodedCodec> = []
    private var currentStartDate: Date?

    // MARK: - Global State

    private var nextSegmentIndex: Int
    private var lastTimestamp: MediaTimestamp?
    private var isFinished = false
    private var totalSegmentsEmitted: Int = 0

    // MARK: - Ring Buffer

    private var ringBuffer: SegmentRingBuffer

    // MARK: - Segment Transform

    private let segmentTransform: (@Sendable (LiveSegment, [EncodedFrame]) -> LiveSegment)?

    /// Creates an incremental segmenter.
    ///
    /// - Parameters:
    ///   - configuration: Segmentation configuration.
    ///     Defaults to ``LiveSegmenterConfiguration/standardLive``.
    ///   - segmentTransform: Optional closure to transform a
    ///     completed segment (e.g., wrap raw data in fMP4 via
    ///     ``CMAFWriter``). Receives the raw segment and its
    ///     source frames. Defaults to nil (no transform).
    public init(
        configuration: LiveSegmenterConfiguration = .standardLive,
        segmentTransform:
            (@Sendable (LiveSegment, [EncodedFrame]) -> LiveSegment)? =
            nil
    ) {
        self.configuration = configuration
        self.nextSegmentIndex = configuration.startIndex
        self.ringBuffer = SegmentRingBuffer(
            capacity: configuration.ringBufferSize
        )
        self.segmentTransform = segmentTransform

        let (stream, continuation) = AsyncStream.makeStream(
            of: LiveSegment.self
        )
        self.segments = stream
        self.segmentContinuation = continuation
    }

    // MARK: - LiveSegmenter

    public func ingest(_ frame: EncodedFrame) async throws {
        guard !isFinished else {
            throw LiveSegmenterError.notActive
        }

        // Validate monotonic timestamps
        if let last = lastTimestamp, frame.timestamp < last {
            throw LiveSegmenterError.nonMonotonicTimestamp(
                "Frame timestamp \(frame.timestamp.seconds)s"
                    + " < last \(last.seconds)s"
            )
        }
        lastTimestamp = frame.timestamp

        // Initialize current segment on first frame
        if currentTimestamp == nil {
            currentTimestamp = frame.timestamp
            if configuration.trackProgramDateTime {
                currentStartDate = Date()
            }
        }

        let frameDuration = frame.duration.seconds
        let wouldExceedTarget =
            currentDuration + frameDuration
            >= configuration.targetDuration
        let wouldExceedMax =
            currentDuration + frameDuration
            >= configuration.maxDuration

        if wouldExceedTarget && shouldCutSegment(at: frame) {
            emitCurrentSegment()
            currentTimestamp = frame.timestamp
            if configuration.trackProgramDateTime {
                currentStartDate = Date()
            }
        } else if wouldExceedMax && !currentFrames.isEmpty {
            currentFrames.append(frame)
            currentDuration += frameDuration
            currentCodecs.insert(frame.codec)
            emitCurrentSegment()
            return
        }

        currentFrames.append(frame)
        currentDuration += frameDuration
        currentCodecs.insert(frame.codec)
    }

    public func forceSegmentBoundary() async throws {
        guard !isFinished else {
            throw LiveSegmenterError.notActive
        }
        guard !currentFrames.isEmpty else {
            throw LiveSegmenterError.noFramesPending
        }
        emitCurrentSegment()
    }

    public func finish() async throws -> LiveSegment? {
        guard !isFinished else { return nil }
        isFinished = true

        if currentFrames.isEmpty {
            segmentContinuation.finish()
            return nil
        }

        let segment = buildSegment()
        ringBuffer.append(segment)
        segmentContinuation.yield(segment)
        segmentContinuation.finish()
        totalSegmentsEmitted += 1
        resetCurrentSegment()
        return segment
    }

    // MARK: - Ring Buffer Access

    /// Access the ring buffer of recent segments.
    ///
    /// Useful for DVR window: retrieve the last N segments.
    public var recentSegments: [LiveSegment] {
        ringBuffer.allSegments
    }

    /// Retrieve a specific segment by index from the ring buffer.
    ///
    /// - Parameter index: The segment index.
    /// - Returns: The segment, or nil if evicted or not yet
    ///   produced.
    public func segment(at index: Int) -> LiveSegment? {
        ringBuffer.segment(at: index)
    }

    /// The current number of segments in the ring buffer.
    public var bufferedSegmentCount: Int {
        ringBuffer.count
    }

    /// Total number of segments emitted since the segmenter
    /// started.
    public var segmentCount: Int {
        totalSegmentsEmitted
    }

    // MARK: - Private

    private func shouldCutSegment(
        at frame: EncodedFrame
    ) -> Bool {
        if !configuration.keyframeAligned {
            return true
        }
        return frame.isKeyframe && frame.codec.isVideo
    }

    private func emitCurrentSegment() {
        guard !currentFrames.isEmpty else { return }

        let segment = buildSegment()
        ringBuffer.append(segment)
        segmentContinuation.yield(segment)
        totalSegmentsEmitted += 1
        resetCurrentSegment()
    }

    private func buildSegment() -> LiveSegment {
        let data = currentFrames.reduce(into: Data()) {
            $0.append($1.data)
        }
        let startsWithKeyframe: Bool
        if let first = currentFrames.first,
            first.codec.isVideo
        {
            startsWithKeyframe = first.isKeyframe
        } else {
            startsWithKeyframe = true
        }

        let filename = String(
            format: configuration.namingPattern,
            nextSegmentIndex
        )

        var segment = LiveSegment(
            index: nextSegmentIndex,
            data: data,
            duration: currentDuration,
            timestamp: currentTimestamp ?? .zero,
            isIndependent: startsWithKeyframe,
            programDateTime: currentStartDate,
            filename: filename,
            frameCount: currentFrames.count,
            codecs: currentCodecs
        )

        if let transform = segmentTransform {
            segment = transform(segment, currentFrames)
        }

        nextSegmentIndex += 1
        return segment
    }

    private func resetCurrentSegment() {
        currentFrames.removeAll()
        currentDuration = 0
        currentTimestamp = nil
        currentCodecs = []
        currentStartDate = nil
    }
}
