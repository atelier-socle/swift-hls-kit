// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    @preconcurrency import AVFoundation
    import Foundation

    // MARK: - Fast Path (AVAssetExportSession)

    extension AppleTranscoder {

        /// Attempt the fast export path using `AVAssetExportSession`.
        ///
        /// Returns `nil` if the fast path is not applicable (no matching
        /// export preset, passthrough mode, or unsupported configuration).
        /// The caller should fall back to the manual reader/writer pipeline.
        ///
        /// - Parameters:
        ///   - job: Transcode job parameters.
        ///   - progress: Progress callback.
        /// - Returns: `true` if the fast path succeeded, `nil` if not
        ///   applicable.
        func tryFastPath(
            job: TranscodeJob,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> Bool? {
            #if DEBUG
                print(
                    "[HLSKit][Debug] tryFastPath:"
                        + " codec=\(job.config.videoCodec),"
                        + " preset=\(job.preset.name),"
                        + " resolution="
                        + "\(job.preset.resolution?.width ?? 0)"
                        + "x\(job.preset.resolution?.height ?? 0)"
                )
            #endif

            guard !job.config.videoPassthrough else { return nil }
            guard !job.config.twoPass else { return nil }

            guard
                let exportPreset = Self.exportPresetName(
                    for: job.preset,
                    codec: job.config.videoCodec
                )
            else {
                #if DEBUG
                    print(
                        "[HLSKit][Debug] tryFastPath:"
                            + " no matching export preset"
                    )
                #endif
                return nil
            }

            guard
                try await runExportSession(
                    input: job.input,
                    presetName: exportPreset,
                    outputURL: job.tempOutput
                )
            else { return nil }

            progress?(1.0)
            return true
        }

        /// Run the export session and check compatibility.
        ///
        /// - Returns: `true` if export succeeded, `false` if not
        ///   compatible or session could not be created.
        private func runExportSession(
            input: URL,
            presetName: String,
            outputURL: URL
        ) async throws -> Bool {
            let asset = AVURLAsset(url: input)

            let compatible =
                await AVAssetExportSession
                .compatibility(
                    ofExportPreset: presetName,
                    with: asset,
                    outputFileType: .mp4
                )
            guard compatible else {
                #if DEBUG
                    print(
                        "[HLSKit][Debug] tryFastPath:"
                            + " \(presetName) not compatible"
                    )
                #endif
                return false
            }

            guard
                let session = AVAssetExportSession(
                    asset: asset,
                    presetName: presetName
                )
            else { return false }

            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true

            #if DEBUG
                print(
                    "[HLSKit][Perf] Using fast path:"
                        + " \(presetName)"
                )
            #endif

            await session.export()

            guard session.status == .completed else {
                if session.status == .cancelled {
                    throw CancellationError()
                }
                let desc =
                    session.error?.localizedDescription
                    ?? "Export failed with status"
                    + " \(session.status.rawValue)"
                throw TranscodingError.encodingFailed(desc)
            }

            return true
        }

        // MARK: - Preset Mapping

        /// Map a ``QualityPreset`` to an `AVAssetExportSession` preset.
        ///
        /// Returns `nil` if no standard export preset matches.
        static func exportPresetName(
            for preset: QualityPreset,
            codec: OutputVideoCodec
        ) -> String? {
            guard let resolution = preset.resolution else {
                return nil
            }

            if codec == .h265 {
                return hevcExportPreset(
                    resolution: resolution
                )
            }

            return h264ExportPreset(
                resolution: resolution
            )
        }

        private static func h264ExportPreset(
            resolution: Resolution
        ) -> String? {
            switch (resolution.width, resolution.height) {
            case (3840, 2160):
                return AVAssetExportPreset3840x2160
            case (1920, 1080):
                return AVAssetExportPreset1920x1080
            case (1280, 720):
                return AVAssetExportPreset1280x720
            case (640...854, 360...480):
                return AVAssetExportPreset640x480
            default:
                return nil
            }
        }

        private static func hevcExportPreset(
            resolution: Resolution
        ) -> String? {
            // Apple provides HEVC export presets only for 1080p
            // and 2160p. Other resolutions fall back to the
            // manual reader/writer pipeline.
            switch (resolution.width, resolution.height) {
            case (3840, 2160):
                return AVAssetExportPresetHEVC3840x2160
            case (1920, 1080):
                return AVAssetExportPresetHEVC1920x1080
            default:
                return nil
            }
        }
    }

#endif
