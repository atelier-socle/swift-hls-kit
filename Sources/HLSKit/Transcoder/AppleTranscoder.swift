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
            let startTime = Date().timeIntervalSinceReferenceDate

            let sourceInfo = try await SourceAnalyzer.analyze(input)
            let preset: QualityPreset =
                sourceInfo.hasVideo ? .p720 : .audioOnly
            let effectivePreset = SourceAnalyzer.effectivePreset(
                preset, source: sourceInfo
            )

            try prepareOutputDirectory(outputDirectory)

            let tempURL = outputDirectory.appendingPathComponent(
                "temp_\(effectivePreset.name).mp4"
            )

            let job = TranscodeJob(
                input: input,
                output: tempURL,
                preset: effectivePreset,
                config: config,
                sourceInfo: sourceInfo
            )
            try await performTranscode(
                job: job, progress: progress
            )

            let segmentation = try segmentOutput(
                tempURL: tempURL,
                outputDirectory: outputDirectory,
                config: config
            )

            let outputSize = fileSize(at: tempURL)
            let elapsed = Date().timeIntervalSinceReferenceDate - startTime

            try? FileManager.default.removeItem(at: tempURL)

            return TranscodingResult(
                preset: effectivePreset,
                outputDirectory: outputDirectory,
                segmentation: segmentation,
                transcodingDuration: elapsed,
                sourceDuration: sourceInfo.duration,
                outputSize: outputSize
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
            var results: [TranscodingResult] = []
            let totalVariants = Double(variants.count)

            for (index, preset) in variants.enumerated() {
                let variantDir =
                    outputDirectory
                    .appendingPathComponent(preset.name)
                let variantResult = try await transcode(
                    input: input,
                    outputDirectory: variantDir,
                    config: config,
                    progress: { variantProgress in
                        let base = Double(index) / totalVariants
                        let scaled =
                            variantProgress / totalVariants
                        progress?(base + scaled)
                    }
                )
                results.append(variantResult)
            }

            let builder = VariantPlaylistBuilder()
            let masterM3U8 = builder.buildMasterPlaylist(
                variants: results, config: config
            )

            return MultiVariantResult(
                variants: results,
                masterPlaylist: masterM3U8,
                outputDirectory: outputDirectory
            )
        }
    }

    // MARK: - Transcoding Pipeline

    extension AppleTranscoder {

        /// Groups the parameters for a single transcode pass.
        struct TranscodeJob {
            let input: URL
            let output: URL
            let preset: QualityPreset
            let config: TranscodingConfig
            let sourceInfo: SourceAnalyzer.SourceInfo
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
                outputURL: job.output, fileType: .mp4
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

    // MARK: - Track Filtering

    extension AppleTranscoder {

        /// Minimum dimension to qualify as real video.
        ///
        /// Cover art is typically 160x160 or 320x320. Any track
        /// smaller than this is treated as a still image.
        private static let minVideoDimension = 240

        /// Find the first real video track, excluding still images.
        ///
        /// Cover art tracks in M4A files are reported as video but
        /// have small dimensions (e.g. 160x160) and non-HLS codecs
        /// like jpeg. Filter them out by requiring minimum size.
        private func firstRealVideoTrack(
            _ tracks: [AVAssetTrack]
        ) async -> AVAssetTrack? {
            for track in tracks where track.mediaType == .video {
                let size =
                    (try? await track.load(.naturalSize))
                    ?? .zero
                let isLargeEnough =
                    Int(size.width) >= Self.minVideoDimension
                    && Int(size.height) >= Self.minVideoDimension
                guard isLargeEnough else { continue }
                return track
            }
            return nil
        }

    }

    // MARK: - Reader Setup

    extension AppleTranscoder {

        private func setupVideoReader(
            track: AVAssetTrack?,
            reader: AVAssetReader,
            passthrough: Bool = false
        ) -> AVAssetReaderTrackOutput? {
            guard let track else { return nil }
            let settings = EncodingSettings.videoReaderSettings(
                passthrough: passthrough
            )
            let output = AVAssetReaderTrackOutput(
                track: track, outputSettings: settings
            )
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                reader.add(output)
            }
            return output
        }

        private func setupAudioReader(
            track: AVAssetTrack?,
            reader: AVAssetReader,
            passthrough: Bool
        ) -> AVAssetReaderTrackOutput? {
            guard let track else { return nil }
            let settings = EncodingSettings.audioReaderSettings(
                passthrough: passthrough
            )
            let output = AVAssetReaderTrackOutput(
                track: track, outputSettings: settings
            )
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                reader.add(output)
            }
            return output
        }
    }

    // MARK: - Writer Setup

    extension AppleTranscoder {

        private func setupVideoWriter(
            preset: QualityPreset,
            config: TranscodingConfig,
            sourceResolution: Resolution?,
            writer: AVAssetWriter,
            sourceFormatHint: CMFormatDescription? = nil
        ) -> AVAssetWriterInput? {
            guard !preset.isAudioOnly else { return nil }

            let input: AVAssetWriterInput
            if config.videoPassthrough {
                input = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: nil,
                    sourceFormatHint: sourceFormatHint
                )
            } else {
                let settings = EncodingSettings.videoSettings(
                    preset: preset,
                    config: config,
                    sourceResolution: sourceResolution
                )
                input = AVAssetWriterInput(
                    mediaType: .video,
                    outputSettings: settings
                )
            }
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) {
                writer.add(input)
            }
            return input
        }

        private func setupAudioWriter(
            track: AVAssetTrack?,
            preset: QualityPreset,
            config: TranscodingConfig,
            writer: AVAssetWriter,
            sourceFormatHint: CMFormatDescription? = nil,
            sourceInfo: SourceAnalyzer.SourceInfo? = nil
        ) -> AVAssetWriterInput? {
            guard track != nil else { return nil }

            var settings = EncodingSettings.audioSettings(
                preset: preset, config: config
            )

            if var s = settings, let info = sourceInfo {
                info.audioChannels.map { s[AVNumberOfChannelsKey] = $0 }
                info.audioSampleRate.map { s[AVSampleRateKey] = Int($0) }
                settings = s
            }

            let input: AVAssetWriterInput
            if let settings {
                input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: settings
                )
            } else {
                input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: nil,
                    sourceFormatHint: sourceFormatHint
                )
            }
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) {
                writer.add(input)
            }
            return input
        }
    }

#endif
