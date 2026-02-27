// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    @preconcurrency import AVFoundation
    import Foundation

    /// Hardware-accelerated transcoder using Apple's AVFoundation.
    ///
    /// Uses `AVAssetReader` for decoding and `AVAssetWriter` for encoding,
    /// with VideoToolbox providing hardware-accelerated H.264/H.265
    /// encoding. After transcoding, delegates to ``MP4Segmenter`` or
    /// ``TSSegmenter`` for HLS segmentation.
    ///
    /// Available on macOS, iOS, tvOS, and visionOS.
    ///
    /// ```swift
    /// let transcoder = AppleTranscoder()
    /// let result = try await transcoder.transcode(
    ///     input: sourceURL,
    ///     outputDirectory: outputDir,
    ///     config: TranscodingConfig(),
    ///     progress: { print("Progress: \($0 * 100)%") }
    /// )
    /// ```
    ///
    /// - SeeAlso: ``Transcoder``, ``TranscodingConfig``
    public struct AppleTranscoder: Transcoder, Sendable {

        /// Creates an Apple transcoder.
        public init() {}

        /// Whether this transcoder is available.
        public static var isAvailable: Bool { true }

        /// Human-readable name.
        public static var name: String { "Apple VideoToolbox" }

        /// Transcode a single file at a specific quality.
        public func transcode(
            input: URL,
            outputDirectory: URL,
            config: TranscodingConfig,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> TranscodingResult {
            let sourceInfo = try await SourceAnalyzer.analyze(input)
            let preset: QualityPreset =
                sourceInfo.hasVideo ? .p720 : .audioOnly
            let job = TranscodeJob(
                input: input,
                outputDirectory: outputDirectory,
                preset: preset,
                config: config,
                sourceInfo: sourceInfo
            )
            return try await executeTranscode(
                job: job, progress: progress
            )
        }

        /// Transcode to multiple quality variants.
        public func transcodeVariants(
            input: URL,
            outputDirectory: URL,
            variants: [QualityPreset],
            config: TranscodingConfig,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> MultiVariantResult {
            let sourceInfo = try await SourceAnalyzer.analyze(input)
            var results: [TranscodingResult] = []
            let total = Double(variants.count)

            for (idx, preset) in variants.enumerated() {
                let dir =
                    outputDirectory
                    .appendingPathComponent(preset.name)
                let job = TranscodeJob(
                    input: input,
                    outputDirectory: dir,
                    preset: preset,
                    config: config,
                    sourceInfo: sourceInfo
                )
                let result = try await executeTranscode(
                    job: job,
                    progress: { p in
                        let base = Double(idx) / total
                        progress?(base + p / total)
                    }
                )
                results.append(result)
            }

            let m3u8 = VariantPlaylistBuilder()
                .buildMasterPlaylist(
                    variants: results, config: config
                )
            return MultiVariantResult(
                variants: results,
                masterPlaylist: m3u8,
                outputDirectory: outputDirectory
            )
        }
    }

    // MARK: - Transcoding Pipeline

    extension AppleTranscoder {

        /// Groups the parameters for a single transcode pass.
        struct TranscodeJob {
            let input: URL
            let outputDirectory: URL
            let preset: QualityPreset
            let config: TranscodingConfig
            let sourceInfo: SourceAnalyzer.SourceInfo

            var tempOutput: URL {
                outputDirectory.appendingPathComponent(
                    "temp_\(preset.name).mp4"
                )
            }
        }

        /// Internal transcode that accepts an explicit preset.
        func executeTranscode(
            job: TranscodeJob,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> TranscodingResult {
            let startTime = CFAbsoluteTimeGetCurrent()
            let effective = SourceAnalyzer.effectivePreset(
                job.preset, source: job.sourceInfo
            )
            let effectiveJob = TranscodeJob(
                input: job.input,
                outputDirectory: job.outputDirectory,
                preset: effective,
                config: job.config,
                sourceInfo: job.sourceInfo
            )

            try prepareOutputDirectory(
                effectiveJob.outputDirectory
            )

            let encodeTime = try await encodeJob(
                effectiveJob, progress: progress
            )

            let segStart = CFAbsoluteTimeGetCurrent()
            let segmentation = try segmentOutput(
                tempURL: effectiveJob.tempOutput,
                outputDirectory: effectiveJob.outputDirectory,
                config: effectiveJob.config
            )
            let segTime = CFAbsoluteTimeGetCurrent() - segStart

            let outputSize = fileSize(
                at: effectiveJob.tempOutput
            )
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            try? FileManager.default.removeItem(
                at: effectiveJob.tempOutput
            )

            Self.logPerformance(
                analysis: 0,
                encode: encodeTime,
                segmentation: segTime,
                total: elapsed,
                source: effectiveJob.sourceInfo
            )

            return TranscodingResult(
                preset: effective,
                outputDirectory: effectiveJob.outputDirectory,
                segmentation: segmentation,
                transcodingDuration: elapsed,
                sourceDuration: effectiveJob.sourceInfo.duration,
                outputSize: outputSize
            )
        }

        /// Run encoding via fast path or standard pipeline.
        ///
        /// - Returns: Elapsed encoding time in seconds.
        func encodeJob(
            _ job: TranscodeJob,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> Double {
            let start = CFAbsoluteTimeGetCurrent()
            var usedFastPath = false
            if job.config.preferFastPath {
                if let ok = try await tryFastPath(
                    job: job, progress: progress
                ) {
                    usedFastPath = ok
                }
            }
            if !usedFastPath {
                try await performTranscode(
                    job: job, progress: progress
                )
            }
            return CFAbsoluteTimeGetCurrent() - start
        }

        private func performTranscode(
            job: TranscodeJob,
            progress: (@Sendable (Double) -> Void)?
        ) async throws {
            let timeout = job.config.timeout
            if timeout > 0 {
                try await withThrowingTaskGroup(
                    of: Void.self
                ) { group in
                    group.addTask {
                        try await self.runTranscodePipeline(
                            job: job, progress: progress
                        )
                    }
                    group.addTask {
                        try await Task.sleep(
                            nanoseconds: UInt64(timeout * 1e9)
                        )
                        throw TranscodingError.timeout(
                            "Transcoding timed out after"
                                + " \(Int(timeout))s"
                        )
                    }
                    // First to finish wins; cancel the other
                    try await group.next()
                    group.cancelAll()
                }
            } else {
                try await runTranscodePipeline(
                    job: job, progress: progress
                )
            }
        }

        private func runTranscodePipeline(
            job: TranscodeJob,
            progress: (@Sendable (Double) -> Void)?
        ) async throws {
            let asset = AVURLAsset(url: job.input)
            let tracks = try await asset.load(.tracks)
            let duration = try await asset.load(.duration)

            let videoTrack =
                job.preset.isAudioOnly
                ? nil
                : await firstRealVideoTrack(tracks)
            let audioTrack =
                job.config.includeAudio
                ? tracks.first(where: { $0.mediaType == .audio })
                : nil

            let audioFormatHint = try await audioTrack?
                .load(.formatDescriptions).first
            let videoFormatHint = try await videoTrack?
                .load(.formatDescriptions).first

            let filtered = try filteredComposition(
                duration: duration,
                videoTrack: videoTrack,
                audioTrack: audioTrack
            )

            let reader = try AVAssetReader(
                asset: filtered.asset
            )
            let writer = try AVAssetWriter(
                outputURL: job.tempOutput, fileType: .mp4
            )

            let pipeline = TranscodingSession.Pipeline(
                reader: reader,
                writer: writer,
                videoReaderOutput: setupVideoReader(
                    track: filtered.videoTrack,
                    reader: reader,
                    passthrough: job.config.videoPassthrough
                ),
                audioReaderOutput: setupAudioReader(
                    track: filtered.audioTrack,
                    reader: reader,
                    passthrough: job.config.audioPassthrough
                ),
                videoWriterInput: setupVideoWriter(
                    preset: job.preset,
                    config: job.config,
                    sourceResolution: job.sourceInfo.videoResolution,
                    writer: writer,
                    sourceFormatHint: videoFormatHint
                ),
                audioWriterInput: setupAudioWriter(
                    track: filtered.audioTrack,
                    preset: job.preset,
                    config: job.config,
                    writer: writer,
                    sourceFormatHint: audioFormatHint,
                    sourceInfo: job.sourceInfo
                )
            )

            let session = TranscodingSession(
                sourceDuration: duration,
                progressHandler: progress
            )

            try await session.execute(pipeline)
        }
    }

#endif
