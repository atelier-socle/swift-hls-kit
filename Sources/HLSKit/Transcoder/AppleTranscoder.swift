// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
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
            let startTime = CFAbsoluteTimeGetCurrent()

            let sourceInfo = try await SourceAnalyzer.analyze(input)
            let preset = resolvePreset(
                config: config, source: sourceInfo
            )
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
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime

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
                let variantConfig = configWith(
                    preset: preset, base: config
                )
                let variantResult = try await transcode(
                    input: input,
                    outputDirectory: variantDir,
                    config: variantConfig,
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
            let asset = AVURLAsset(url: job.input)
            let tracks = try await asset.load(.tracks)
            let duration = try await asset.load(.duration)

            let videoTrack = tracks.first { $0.mediaType == .video }
            let audioTrack =
                job.config.includeAudio
                ? tracks.first(where: { $0.mediaType == .audio })
                : nil

            let reader = try AVAssetReader(asset: asset)
            let writer = try AVAssetWriter(
                outputURL: job.output, fileType: .mp4
            )

            let pipeline = TranscodingSession.Pipeline(
                reader: reader,
                writer: writer,
                videoReaderOutput: setupVideoReader(
                    track: videoTrack, reader: reader
                ),
                audioReaderOutput: setupAudioReader(
                    track: audioTrack,
                    reader: reader,
                    passthrough: job.config.audioPassthrough
                ),
                videoWriterInput: setupVideoWriter(
                    preset: job.preset,
                    config: job.config,
                    sourceResolution: job.sourceInfo.videoResolution,
                    writer: writer
                ),
                audioWriterInput: setupAudioWriter(
                    track: audioTrack,
                    preset: job.preset,
                    config: job.config,
                    writer: writer
                )
            )

            let session = TranscodingSession(
                sourceDuration: duration,
                progressHandler: progress
            )

            try await session.execute(pipeline)
        }
    }

    // MARK: - Reader Setup

    extension AppleTranscoder {

        private func setupVideoReader(
            track: AVAssetTrack?,
            reader: AVAssetReader
        ) -> AVAssetReaderTrackOutput? {
            guard let track else { return nil }
            let settings = EncodingSettings.videoReaderSettings()
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
            writer: AVAssetWriter
        ) -> AVAssetWriterInput? {
            guard !preset.isAudioOnly else { return nil }
            let settings = EncodingSettings.videoSettings(
                preset: preset,
                config: config,
                sourceResolution: sourceResolution
            )
            let input = AVAssetWriterInput(
                mediaType: .video,
                outputSettings: settings
            )
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
            writer: AVAssetWriter
        ) -> AVAssetWriterInput? {
            guard track != nil else { return nil }

            let settings = EncodingSettings.audioSettings(
                preset: preset, config: config
            )

            let input: AVAssetWriterInput
            if settings != nil {
                input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: settings
                )
            } else {
                input = AVAssetWriterInput(
                    mediaType: .audio,
                    outputSettings: nil
                )
            }
            input.expectsMediaDataInRealTime = false
            if writer.canAdd(input) {
                writer.add(input)
            }
            return input
        }
    }

    // MARK: - Segmentation

    extension AppleTranscoder {

        private func segmentOutput(
            tempURL: URL,
            outputDirectory: URL,
            config: TranscodingConfig
        ) throws -> SegmentationResult? {
            let data: Data
            do {
                data = try Data(contentsOf: tempURL)
            } catch {
                return nil
            }

            let segConfig = SegmentationConfig(
                targetSegmentDuration: config.segmentDuration,
                containerFormat: config.containerFormat,
                generatePlaylist: config.generatePlaylist,
                playlistType: config.playlistType
            )

            switch config.containerFormat {
            case .fragmentedMP4:
                return try? MP4Segmenter()
                    .segmentToDirectory(
                        data: data,
                        outputDirectory: outputDirectory,
                        config: segConfig
                    )
            case .mpegTS:
                return try? TSSegmenter()
                    .segmentToDirectory(
                        data: data,
                        outputDirectory: outputDirectory,
                        config: segConfig
                    )
            }
        }
    }

    // MARK: - Helpers

    extension AppleTranscoder {

        private func resolvePreset(
            config: TranscodingConfig,
            source: SourceAnalyzer.SourceInfo
        ) -> QualityPreset {
            if source.hasVideo {
                return .p720
            }
            return .audioOnly
        }

        private func configWith(
            preset: QualityPreset,
            base: TranscodingConfig
        ) -> TranscodingConfig {
            base
        }

        private func prepareOutputDirectory(
            _ url: URL
        ) throws {
            var isDir: ObjCBool = false
            if !FileManager.default.fileExists(
                atPath: url.path, isDirectory: &isDir
            ) {
                do {
                    try FileManager.default.createDirectory(
                        at: url,
                        withIntermediateDirectories: true
                    )
                } catch {
                    throw TranscodingError.outputDirectoryError(
                        error.localizedDescription
                    )
                }
            } else if !isDir.boolValue {
                throw TranscodingError.outputDirectoryError(
                    "Path exists but is not a directory: \(url.path)"
                )
            }
        }

        private func fileSize(at url: URL) -> UInt64 {
            let attrs = try? FileManager.default.attributesOfItem(
                atPath: url.path
            )
            return attrs?[.size] as? UInt64 ?? 0
        }
    }

#endif
