// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    @preconcurrency import AVFoundation
    import Foundation

    /// Manages a single transcoding pass (reader → writer pipeline).
    ///
    /// Processes video samples first, then audio samples sequentially,
    /// using a pull-based loop with back-pressure via
    /// `isReadyForMoreMediaData`.
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
        private let sourceDuration: CMTime

        /// Progress callback.
        private let progressHandler: (@Sendable (Double) -> Void)?

        /// Creates a transcoding session.
        ///
        /// - Parameters:
        ///   - sourceDuration: Total source duration.
        ///   - progressHandler: Optional progress callback (0.0–1.0).
        init(
            sourceDuration: CMTime,
            progressHandler: (@Sendable (Double) -> Void)?
        ) {
            self.sourceDuration = sourceDuration
            self.progressHandler = progressHandler
        }

        /// Execute the transcoding pipeline.
        ///
        /// Starts the reader and writer, processes video then audio
        /// tracks, and waits for completion.
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

            if let videoOutput = pipeline.videoReaderOutput,
                let videoInput = pipeline.videoWriterInput
            {
                try await processTrack(
                    readerOutput: videoOutput,
                    writerInput: videoInput,
                    reportProgress: true
                )
            }

            if let audioOutput = pipeline.audioReaderOutput,
                let audioInput = pipeline.audioWriterInput
            {
                try await processTrack(
                    readerOutput: audioOutput,
                    writerInput: audioInput,
                    reportProgress: false
                )
            }

            await pipeline.writer.finishWriting()

            guard pipeline.writer.status == .completed else {
                throw TranscodingError.encodingFailed(
                    pipeline.writer.error?.localizedDescription
                        ?? "Writer finished with status: \(pipeline.writer.status.rawValue)"
                )
            }
        }

        // MARK: - Track Processing

        private func processTrack(
            readerOutput: AVAssetReaderTrackOutput,
            writerInput: AVAssetWriterInput,
            reportProgress: Bool
        ) async throws {
            let durationSeconds = sourceDuration.seconds

            while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                while !writerInput.isReadyForMoreMediaData {
                    await Task.yield()
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
                        currentTime.seconds / durationSeconds, 1.0
                    )
                    progressHandler?(progress)
                }
            }

            writerInput.markAsFinished()
        }
    }

#endif
