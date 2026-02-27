// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - ISOBMFF Detection

extension HLSEngine {

    /// Known ISOBMFF container file extensions.
    private static let isobmffExtensions: Set<String> = [
        "mp4", "m4a", "m4v", "mov"
    ]

    /// Whether a URL points to an ISOBMFF container.
    ///
    /// Checks the file extension against known ISOBMFF types:
    /// `.mp4`, `.m4a`, `.m4v`, and `.mov`.
    ///
    /// - Parameter url: File URL to check.
    /// - Returns: `true` if the file has a known ISOBMFF extension.
    public static func isISOBMFF(_ url: URL) -> Bool {
        isobmffExtensions.contains(
            url.pathExtension.lowercased()
        )
    }
}

// MARK: - Auto-Transcode Segmentation

#if canImport(AVFoundation) && !os(watchOS)
    @preconcurrency import AVFoundation

    extension HLSEngine {

        /// Segment a media file, auto-transcoding non-ISOBMFF formats.
        ///
        /// For ISOBMFF files (`.mp4`, `.m4a`, `.m4v`, `.mov`), reads
        /// the data and segments directly via ``MP4Segmenter`` or
        /// ``TSSegmenter``.
        ///
        /// For other audio formats (`.mp3`, `.wav`, `.flac`, etc.),
        /// first transcodes to M4A using `AVAssetExportSession`,
        /// then segments the resulting ISOBMFF container.
        ///
        /// - Parameters:
        ///   - url: Source media file URL.
        ///   - outputDirectory: Directory to write segment files to.
        ///   - config: Segmentation configuration.
        /// - Returns: The segmentation result.
        /// - Throws: ``TranscodingError`` if auto-transcoding fails,
        ///   `MP4Error` or `TransportError` if segmentation fails.
        public func segmentToDirectory(
            url: URL,
            outputDirectory: URL,
            config: SegmentationConfig = SegmentationConfig()
        ) async throws -> SegmentationResult {
            if Self.isISOBMFF(url) {
                let data = try Data(contentsOf: url)
                return try segmentToDirectory(
                    data: data,
                    outputDirectory: outputDirectory,
                    config: config
                )
            }

            let tempURL =
                outputDirectory
                .appendingPathComponent("_temp_transcode.m4a")
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            try await transcodeToM4A(input: url, output: tempURL)

            let data = try Data(contentsOf: tempURL)
            return try segmentToDirectory(
                data: data,
                outputDirectory: outputDirectory,
                config: config
            )
        }

        // MARK: - Auto-Transcode

        /// Transcode an audio file to M4A format.
        ///
        /// Uses `AVAssetExportSession` with the Apple M4A preset
        /// for lightweight format conversion.
        ///
        /// - Parameters:
        ///   - input: Source audio file URL.
        ///   - output: Destination M4A URL.
        /// - Throws: ``TranscodingError/encodingFailed(_:)`` if
        ///   the export session cannot be created or fails.
        private func transcodeToM4A(
            input: URL,
            output: URL
        ) async throws {
            try? FileManager.default.removeItem(at: output)
            let asset = AVURLAsset(url: input)
            guard
                let session = AVAssetExportSession(
                    asset: asset,
                    presetName: AVAssetExportPresetAppleM4A
                )
            else {
                throw TranscodingError.encodingFailed(
                    "Cannot create export session for"
                        + " \(input.lastPathComponent)"
                )
            }
            session.outputURL = output
            session.outputFileType = .m4a
            await session.export()
            guard session.status == .completed else {
                let reason =
                    session.error?.localizedDescription
                    ?? "Unknown export error"
                throw TranscodingError.encodingFailed(
                    "Auto-transcode failed for"
                        + " \(input.lastPathComponent):"
                        + " \(reason)"
                )
            }
        }
    }
#endif
