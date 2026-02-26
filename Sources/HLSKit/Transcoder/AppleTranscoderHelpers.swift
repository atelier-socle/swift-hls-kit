// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    @preconcurrency import AVFoundation
    import Foundation

    // MARK: - Track Composition

    extension AppleTranscoder {

        /// Tracks extracted from a filtered composition.
        struct FilteredAsset {
            let asset: AVAsset
            let videoTrack: AVAssetTrack?
            let audioTrack: AVAssetTrack?
        }

        /// Build a composition containing only audio and real video
        /// tracks, excluding text, metadata, and cover art tracks
        /// that cause AVAssetReader/Writer failures.
        func filteredComposition(
            duration: CMTime,
            videoTrack: AVAssetTrack?,
            audioTrack: AVAssetTrack?
        ) throws -> FilteredAsset {
            let composition = AVMutableComposition()
            let range = CMTimeRange(
                start: .zero, duration: duration
            )

            var compVideo: AVAssetTrack?
            if let videoTrack {
                let track = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                try track?.insertTimeRange(
                    range, of: videoTrack, at: .zero
                )
                compVideo = track
            }

            var compAudio: AVAssetTrack?
            if let audioTrack {
                let track = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                try track?.insertTimeRange(
                    range, of: audioTrack, at: .zero
                )
                compAudio = track
            }

            return FilteredAsset(
                asset: composition,
                videoTrack: compVideo,
                audioTrack: compAudio
            )
        }
    }

    // MARK: - Segmentation

    extension AppleTranscoder {

        func segmentOutput(
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

        func prepareOutputDirectory(
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

        func fileSize(at url: URL) -> UInt64 {
            let attrs = try? FileManager.default.attributesOfItem(
                atPath: url.path
            )
            return attrs?[.size] as? UInt64 ?? 0
        }
    }

#endif
