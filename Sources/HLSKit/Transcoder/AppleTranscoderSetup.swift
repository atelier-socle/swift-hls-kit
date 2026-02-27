// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    @preconcurrency import AVFoundation

    // MARK: - Track Filtering

    extension AppleTranscoder {

        /// Minimum dimension to qualify as real video.
        ///
        /// Cover art is typically 160x160 or 320x320. Any track
        /// smaller than this is treated as a still image.
        static let minVideoDimension = 240

        /// Find the first real video track, excluding still images.
        ///
        /// Cover art tracks in M4A files are reported as video but
        /// have small dimensions (e.g. 160x160) and non-HLS codecs
        /// like jpeg. Filter them out by requiring minimum size.
        func firstRealVideoTrack(
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

        func setupVideoReader(
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

        func setupAudioReader(
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

        func setupVideoWriter(
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

        func setupAudioWriter(
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
                info.audioChannels.map {
                    s[AVNumberOfChannelsKey] = $0
                }
                info.audioSampleRate.map {
                    s[AVSampleRateKey] = Int($0)
                }
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
