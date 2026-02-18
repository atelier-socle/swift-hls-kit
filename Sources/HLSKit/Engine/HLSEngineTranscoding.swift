// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Transcoding

extension HLSEngine {

    /// Whether a transcoder is available on the current platform.
    ///
    /// Returns `false` until a platform-specific transcoder
    /// is registered (e.g., `AppleTranscoder` in Session 14).
    public var isTranscoderAvailable: Bool { false }

    /// Transcode a media file to HLS format.
    ///
    /// Uses the best available transcoder for the current platform.
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
        throw TranscodingError.transcoderNotAvailable(
            "No transcoder available on this platform"
        )
    }

    /// Transcode to multiple quality variants.
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
        throw TranscodingError.transcoderNotAvailable(
            "No transcoder available on this platform"
        )
    }
}
