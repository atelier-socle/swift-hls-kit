// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Transcoding

extension HLSEngine {

    /// Whether a transcoder is available on the current platform.
    ///
    /// Returns `true` on Apple platforms (AVFoundation available),
    /// `false` otherwise.
    public var isTranscoderAvailable: Bool {
        #if canImport(AVFoundation)
            return AppleTranscoder.isAvailable
        #else
            return false
        #endif
    }

    /// Transcode a media file to HLS format.
    ///
    /// Uses the best available transcoder for the current platform.
    /// On Apple platforms, delegates to ``AppleTranscoder``.
    ///
    /// - Parameters:
    ///   - input: Source media file URL.
    ///   - outputDirectory: Directory for output files.
    ///   - preset: Quality preset.
    ///   - config: Transcoding configuration.
    ///   - progress: Optional progress callback.
    /// - Returns: Transcoding result.
    /// - Throws: ``TranscodingError`` if no transcoder is available.
    public func transcode(
        input: URL,
        outputDirectory: URL,
        preset: QualityPreset = .p720,
        config: TranscodingConfig = TranscodingConfig(),
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> TranscodingResult {
        #if canImport(AVFoundation)
            let transcoder = AppleTranscoder()
            let result = try await transcoder.transcodeVariants(
                input: input,
                outputDirectory: outputDirectory,
                variants: [preset],
                config: config,
                progress: progress
            )
            guard let first = result.variants.first else {
                throw TranscodingError.encodingFailed(
                    "No transcoding result produced"
                )
            }
            return first
        #else
            throw TranscodingError.transcoderNotAvailable(
                "No transcoder available on this platform"
            )
        #endif
    }

    /// Transcode to multiple quality variants.
    ///
    /// Produces a complete adaptive bitrate HLS package with a
    /// master playlist. On Apple platforms, delegates to
    /// ``AppleTranscoder``.
    ///
    /// - Parameters:
    ///   - input: Source media file URL.
    ///   - outputDirectory: Directory for output files.
    ///   - variants: Quality presets (default: standard ladder).
    ///   - config: Transcoding configuration.
    ///   - progress: Optional progress callback.
    /// - Returns: Multi-variant result with master playlist.
    /// - Throws: ``TranscodingError`` if no transcoder is available.
    public func transcodeVariants(
        input: URL,
        outputDirectory: URL,
        variants: [QualityPreset] = QualityPreset.standardLadder,
        config: TranscodingConfig = TranscodingConfig(),
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> MultiVariantResult {
        #if canImport(AVFoundation)
            let transcoder = AppleTranscoder()
            return try await transcoder.transcodeVariants(
                input: input,
                outputDirectory: outputDirectory,
                variants: variants,
                config: config,
                progress: progress
            )
        #else
            throw TranscodingError.transcoderNotAvailable(
                "No transcoder available on this platform"
            )
        #endif
    }
}
