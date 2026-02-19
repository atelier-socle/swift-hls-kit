// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation

    /// Transcoder using FFmpeg for encoding.
    ///
    /// Invokes the `ffmpeg` binary via `Process` for transcoding.
    /// FFmpeg must be installed and available in PATH.
    ///
    /// Works on macOS and Linux.
    ///
    /// ```swift
    /// guard FFmpegTranscoder.isAvailable else {
    ///     print("FFmpeg not found")
    ///     return
    /// }
    /// let transcoder = try FFmpegTranscoder()
    /// let result = try await transcoder.transcode(
    ///     input: sourceURL,
    ///     outputDirectory: outputDir,
    ///     config: TranscodingConfig(),
    ///     progress: { print("Progress: \($0 * 100)%") }
    /// )
    /// ```
    ///
    /// - SeeAlso: ``Transcoder``, ``AppleTranscoder``
    public struct FFmpegTranscoder: Transcoder, Sendable {

        private let runner: FFmpegProcessRunner
        private let commandBuilder: FFmpegCommandBuilder

        /// Initialize with auto-detected ffmpeg path.
        ///
        /// - Throws: ``TranscodingError/transcoderNotAvailable(_:)``
        ///   if ffmpeg not found.
        public init() throws {
            self.runner = try FFmpegProcessRunner()
            self.commandBuilder = FFmpegCommandBuilder()
        }

        /// Initialize with explicit ffmpeg path.
        ///
        /// - Parameters:
        ///   - ffmpegPath: Path to the ffmpeg binary.
        ///   - ffprobePath: Path to the ffprobe binary.
        public init(ffmpegPath: String, ffprobePath: String) {
            self.runner = FFmpegProcessRunner(
                ffmpegPath: ffmpegPath,
                ffprobePath: ffprobePath
            )
            self.commandBuilder = FFmpegCommandBuilder()
        }

        /// Whether ffmpeg is available in PATH.
        public static var isAvailable: Bool {
            FFmpegProcessRunner.isAvailable
        }

        /// Human-readable name.
        public static var name: String { "FFmpeg" }

        /// Transcode a single file.
        public func transcode(
            input: URL,
            outputDirectory: URL,
            config: TranscodingConfig,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> TranscodingResult {
            let startTime = Date().timeIntervalSinceReferenceDate

            try validateSource(input)
            try prepareOutputDirectory(outputDirectory)

            let sourceInfo = try await analyzeSource(input)
            let preset = resolvePreset(
                config: config, source: sourceInfo
            )
            let effectivePreset = Self.effectivePreset(
                preset, source: sourceInfo
            )

            let outputExtension =
                effectivePreset.isAudioOnly ? "m4a" : "mp4"
            let tempURL = outputDirectory.appendingPathComponent(
                "temp_\(effectivePreset.name).\(outputExtension)"
            )

            let args = commandBuilder.buildTranscodeArguments(
                input: input.path,
                output: tempURL.path,
                preset: effectivePreset,
                config: config
            )

            _ = try await runner.runFFmpeg(
                arguments: args,
                duration: sourceInfo.duration,
                progress: progress
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
    }

    // MARK: - Source Analysis

    extension FFmpegTranscoder {

        private func analyzeSource(
            _ url: URL
        ) async throws -> FFmpegSourceInfo {
            let analyzer = FFmpegSourceAnalyzer(runner: runner)
            return try await analyzer.analyze(url)
        }
    }

    // MARK: - Segmentation

    extension FFmpegTranscoder {

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

    // MARK: - Effective Preset

    extension FFmpegTranscoder {

        /// Determine effective preset, preventing upscaling.
        ///
        /// Same logic as ``SourceAnalyzer/effectivePreset(_:source:)``
        /// but works with ``FFmpegSourceInfo``.
        static func effectivePreset(
            _ preset: QualityPreset,
            source: FFmpegSourceInfo
        ) -> QualityPreset {
            guard let presetRes = preset.resolution,
                let sourceRes = source.videoResolution
            else {
                return preset
            }

            guard
                presetRes.width > sourceRes.width
                    || presetRes.height > sourceRes.height
            else {
                return preset
            }

            let effectiveBitrate: Int?
            if let presetBitrate = preset.videoBitrate,
                let sourceBitrate = source.videoBitrate
            {
                effectiveBitrate = min(
                    presetBitrate, sourceBitrate
                )
            } else {
                effectiveBitrate = preset.videoBitrate
            }

            return QualityPreset(
                name: preset.name,
                resolution: sourceRes,
                videoBitrate: effectiveBitrate,
                maxVideoBitrate: preset.maxVideoBitrate,
                audioBitrate: preset.audioBitrate,
                audioSampleRate: preset.audioSampleRate,
                audioChannels: preset.audioChannels,
                videoProfile: preset.videoProfile,
                videoLevel: preset.videoLevel,
                frameRate: preset.frameRate,
                keyFrameInterval: preset.keyFrameInterval
            )
        }
    }

    // MARK: - Helpers

    extension FFmpegTranscoder {

        private func resolvePreset(
            config: TranscodingConfig,
            source: FFmpegSourceInfo
        ) -> QualityPreset {
            if source.hasVideoTrack {
                return .p720
            }
            return .audioOnly
        }

        private func validateSource(_ url: URL) throws {
            guard
                FileManager.default.fileExists(
                    atPath: url.path
                )
            else {
                throw TranscodingError.sourceNotFound(
                    url.lastPathComponent
                )
            }
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
            let attrs =
                try? FileManager.default.attributesOfItem(
                    atPath: url.path
                )
            return attrs?[.size] as? UInt64 ?? 0
        }
    }

#endif
