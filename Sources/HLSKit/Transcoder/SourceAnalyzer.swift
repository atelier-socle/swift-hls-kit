// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    @preconcurrency import AVFoundation

    /// Analyzes source media properties for transcoding decisions.
    ///
    /// Inspects the source file's tracks, codecs, resolution, frame rate,
    /// and bitrate to inform transcoding parameters.
    ///
    /// - SeeAlso: ``AppleTranscoder``, ``QualityPreset``
    struct SourceAnalyzer: Sendable {

        /// Analyzed source media properties.
        ///
        /// Contains only value-type data extracted from the source.
        struct SourceInfo: Sendable {
            let duration: Double
            let hasVideo: Bool
            let hasAudio: Bool
            let videoResolution: Resolution?
            let videoFrameRate: Double?
            let videoBitrate: Int?
            let audioBitrate: Int?
            let audioSampleRate: Double?
            let audioChannels: Int?
        }

        /// Analyze a source media file.
        ///
        /// - Parameter url: Source file URL.
        /// - Returns: Analyzed source info.
        /// - Throws: ``TranscodingError/sourceNotFound(_:)`` if the
        ///   source cannot be read.
        static func analyze(_ url: URL) async throws -> SourceInfo {
            let asset = AVURLAsset(url: url)

            let duration: CMTime
            let tracks: [AVAssetTrack]
            do {
                duration = try await asset.load(.duration)
                tracks = try await asset.load(.tracks)
            } catch {
                throw TranscodingError.sourceNotFound(
                    url.lastPathComponent
                )
            }

            let videoTrack = await firstRealVideoTrack(tracks)
            let audioTrack = tracks.first { $0.mediaType == .audio }

            let videoProps = try await analyzeVideo(videoTrack)
            let audioProps = try await analyzeAudio(audioTrack)

            return SourceInfo(
                duration: duration.seconds,
                hasVideo: videoTrack != nil,
                hasAudio: audioTrack != nil,
                videoResolution: videoProps.resolution,
                videoFrameRate: videoProps.frameRate,
                videoBitrate: videoProps.bitrate,
                audioBitrate: audioProps.bitrate,
                audioSampleRate: audioProps.sampleRate,
                audioChannels: audioProps.channels
            )
        }

        // MARK: - Video Analysis

        private struct VideoProps {
            var resolution: Resolution?
            var frameRate: Double?
            var bitrate: Int?
        }

        private static func analyzeVideo(
            _ track: AVAssetTrack?
        ) async throws -> VideoProps {
            guard let track else { return VideoProps() }
            let size = try await track.load(.naturalSize)
            let nominalRate = try await track.load(
                .nominalFrameRate
            )
            let estimatedRate = try await track.load(
                .estimatedDataRate
            )
            return VideoProps(
                resolution: Resolution(
                    width: Int(size.width),
                    height: Int(size.height)
                ),
                frameRate: Double(nominalRate),
                bitrate: Int(estimatedRate)
            )
        }

        // MARK: - Audio Analysis

        private struct AudioProps {
            var bitrate: Int?
            var sampleRate: Double?
            var channels: Int?
        }

        private static func analyzeAudio(
            _ track: AVAssetTrack?
        ) async throws -> AudioProps {
            guard let track else { return AudioProps() }
            let estimatedRate = try await track.load(
                .estimatedDataRate
            )
            let formatDescriptions = try await track.load(
                .formatDescriptions
            )
            var sampleRate: Double?
            var channels: Int?
            if let desc = formatDescriptions.first {
                let basicDesc =
                    CMAudioFormatDescriptionGetStreamBasicDescription(
                        desc
                    )
                if let asbd = basicDesc?.pointee {
                    sampleRate = asbd.mSampleRate
                    channels = Int(asbd.mChannelsPerFrame)
                }
            }
            return AudioProps(
                bitrate: Int(estimatedRate),
                sampleRate: sampleRate,
                channels: channels
            )
        }

        // MARK: - Track Filtering

        /// Minimum dimension to qualify as real video.
        private static let minVideoDimension = 240

        /// Find the first real video track, excluding still images.
        ///
        /// Cover art tracks in M4A files are reported as video but
        /// have small dimensions (e.g. 160x160) and non-HLS codecs
        /// like jpeg. Filter them out by requiring minimum size.
        private static func firstRealVideoTrack(
            _ tracks: [AVAssetTrack]
        ) async -> AVAssetTrack? {
            for track in tracks where track.mediaType == .video {
                let size =
                    (try? await track.load(.naturalSize))
                    ?? .zero
                let isLargeEnough =
                    Int(size.width) >= minVideoDimension
                    && Int(size.height) >= minVideoDimension
                guard isLargeEnough else { continue }
                return track
            }
            return nil
        }

        // MARK: - Effective Preset

        /// Determine effective preset, preventing upscaling.
        ///
        /// If the preset resolution exceeds the source resolution,
        /// the source resolution is used instead (don't upscale).
        ///
        /// - Parameters:
        ///   - preset: Desired quality preset.
        ///   - source: Analyzed source info.
        /// - Returns: Adjusted quality preset.
        static func effectivePreset(
            _ preset: QualityPreset,
            source: SourceInfo
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
                effectiveBitrate = min(presetBitrate, sourceBitrate)
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

#endif
