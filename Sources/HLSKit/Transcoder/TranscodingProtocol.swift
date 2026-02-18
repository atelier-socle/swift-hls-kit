// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A type that can transcode media files to HLS-ready formats.
///
/// Conforming types implement platform-specific encoding pipelines.
/// The protocol defines the contract; implementations provide the engine.
///
/// ## Implementations
/// - `AppleTranscoder` — VideoToolbox + AVAssetWriter (Apple platforms)
/// - `FFmpegTranscoder` — FFmpeg process wrapper (future)
///
/// - SeeAlso: ``TranscodingConfig``, ``TranscodingResult``
public protocol Transcoder: Sendable {

    /// Transcode a media file to HLS-ready output.
    ///
    /// - Parameters:
    ///   - input: URL of the source media file.
    ///   - outputDirectory: Directory for transcoded output files.
    ///   - config: Transcoding configuration.
    ///   - progress: Optional progress callback (0.0 to 1.0).
    /// - Returns: Transcoding result with output file information.
    /// - Throws: ``TranscodingError`` on failure.
    func transcode(
        input: URL,
        outputDirectory: URL,
        config: TranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> TranscodingResult

    /// Transcode to multiple quality variants.
    ///
    /// Produces a complete adaptive bitrate HLS package with a
    /// master playlist.
    ///
    /// - Parameters:
    ///   - input: URL of the source media file.
    ///   - outputDirectory: Directory for all variant outputs.
    ///   - variants: Quality variants to produce.
    ///   - config: Base transcoding configuration.
    ///   - progress: Optional progress callback (0.0 to 1.0).
    /// - Returns: Multi-variant result with master playlist.
    /// - Throws: ``TranscodingError`` on failure.
    func transcodeVariants(
        input: URL,
        outputDirectory: URL,
        variants: [QualityPreset],
        config: TranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> MultiVariantResult

    /// Check if this transcoder is available on the current platform.
    static var isAvailable: Bool { get }

    /// Human-readable name of this transcoder.
    static var name: String { get }
}

// MARK: - Default Implementation

extension Transcoder {

    /// Default multi-variant implementation: transcode each variant
    /// sequentially and generate a master playlist.
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
            variants: results,
            config: config
        )

        return MultiVariantResult(
            variants: results,
            masterPlaylist: masterM3U8,
            outputDirectory: outputDirectory
        )
    }
}
