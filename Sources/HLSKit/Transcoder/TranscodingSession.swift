// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    @preconcurrency import AVFoundation
    import Foundation

    /// Manages a single transcoding pass (reader → writer pipeline).
    ///
    /// Processes video and audio samples by interleaving reads from
    /// both tracks, using a pull-based loop with back-pressure via
    /// `isReadyForMoreMediaData`. Interleaving prevents AVAssetReader
    /// internal buffer deadlock when both tracks are present.
    ///
    /// - SeeAlso: ``AppleTranscoder``
    struct TranscodingSession: Sendable {

        /// Groups the reader/writer pipeline components.
        struct Pipeline {
            let reader: AVAssetReader
            let writer: AVAssetWriter
            let videoReaderOutput: AVAssetReaderTrackOutput?
            let audioReaderOutput: AVAssetReaderTrackOutput?
            let videoWriterInput: AVAssetWriterInput?
            let audioWriterInput: AVAssetWriterInput?
        }

        /// Total source duration for progress calculation.
        let sourceDuration: CMTime

        /// Progress callback.
        let progressHandler: (@Sendable (Double) -> Void)?

        // Uses synthesized memberwise initializer.

        /// Execute the transcoding pipeline.
        ///
        /// Starts the reader and writer, processes video and audio
        /// tracks by interleaving sample reads, and waits for
        /// completion. Interleaved processing drains both track
        /// buffers alternately, preventing AVAssetReader internal
        /// buffer deadlock.
        ///
        /// - Parameter pipeline: Configured reader/writer pipeline.
        /// - Throws: ``TranscodingError`` on failure.
        func execute(_ pipeline: Pipeline) async throws {
            guard pipeline.reader.startReading() else {
                throw TranscodingError.decodingFailed(
                    pipeline.reader.error?.localizedDescription
                        ?? "Failed to start reading"
                )
            }

            pipeline.writer.startWriting()
            pipeline.writer.startSession(atSourceTime: .zero)

            try await drainInterleaved(pipeline)

            await pipeline.writer.finishWriting()

            guard pipeline.writer.status == .completed else {
                throw TranscodingError.encodingFailed(
                    pipeline.writer.error?.localizedDescription
                        ?? "Writer finished with status: \(pipeline.writer.status.rawValue)"
                )
            }
        }

        // MARK: - Interleaved Drain

        /// Drain video and audio tracks by alternating reads.
        ///
        /// Reads one sample from each active track per iteration,
        /// preventing either output buffer from filling up.
        private func drainInterleaved(
            _ pipeline: Pipeline
        ) async throws {
            let durationSeconds = sourceDuration.seconds
            var videoActive =
                pipeline.videoReaderOutput != nil
                && pipeline.videoWriterInput != nil
            var audioActive =
                pipeline.audioReaderOutput != nil
                && pipeline.audioWriterInput != nil

            while videoActive || audioActive {
                if videoActive {
                    videoActive = try await drainOneSample(
                        output: pipeline.videoReaderOutput,
                        input: pipeline.videoWriterInput,
                        durationSeconds: durationSeconds
                    )
                }

                if audioActive {
                    audioActive = try await drainOneSample(
                        output: pipeline.audioReaderOutput,
                        input: pipeline.audioWriterInput,
                        durationSeconds: 0
                    )
                }
            }
        }

        /// Read and append one sample from a track pair.
        ///
        /// - Returns: `true` if the track has more samples,
        ///   `false` if exhausted (writer input marked finished).
        private func drainOneSample(
            output: AVAssetReaderTrackOutput?,
            input: AVAssetWriterInput?,
            durationSeconds: Double
        ) async throws -> Bool {
            guard let output, let input else { return false }

            guard
                let sample = output.copyNextSampleBuffer()
            else {
                input.markAsFinished()
                return false
            }

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 1_000_000)
            }

            guard input.append(sample) else {
                throw TranscodingError.encodingFailed(
                    "Failed to append sample buffer"
                )
            }

            if durationSeconds > 0 {
                let pts =
                    CMSampleBufferGetPresentationTimeStamp(
                        sample
                    )
                let progress = min(
                    pts.seconds / durationSeconds, 1.0
                )
                progressHandler?(progress)
            }

            return true
        }

        // MARK: - Track Processing

        /// Process samples from a reader output to a writer input.
        ///
        /// Generic over ``SampleReading`` and ``SampleWriting`` to
        /// support both real AVFoundation types and test mocks.
        ///
        /// - Parameters:
        ///   - readerOutput: Source of sample buffers.
        ///   - writerInput: Destination for sample buffers.
        ///   - reportProgress: Whether to report progress.
        func processTrack<R: SampleReading, W: SampleWriting>(
            readerOutput: R,
            writerInput: W,
            reportProgress: Bool
        ) async throws {
            let durationSeconds = sourceDuration.seconds

            while let sampleBuffer =
                readerOutput.copyNextSampleBuffer()
            {
                while !writerInput.isReadyForMoreMediaData {
                    try await Task.sleep(
                        nanoseconds: 1_000_000
                    )
                }

                guard writerInput.append(sampleBuffer) else {
                    throw TranscodingError.encodingFailed(
                        "Failed to append sample buffer"
                    )
                }

                if reportProgress, durationSeconds > 0 {
                    let currentTime =
                        CMSampleBufferGetPresentationTimeStamp(
                            sampleBuffer
                        )
                    let progress = min(
                        currentTime.seconds / durationSeconds,
                        1.0
                    )
                    progressHandler?(progress)
                }
            }

            writerInput.markAsFinished()
        }
    }

#endif
