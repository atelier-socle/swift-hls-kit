// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Builds HLS master playlists from transcoding variant results.
///
/// Generates the master playlist that ties together multiple quality
/// variants for adaptive bitrate streaming. Uses the existing
/// ``MasterPlaylist`` model and ``ManifestGenerator`` internally.
///
/// ```swift
/// let builder = VariantPlaylistBuilder()
/// let m3u8 = builder.buildMasterPlaylist(
///     presets: QualityPreset.standardLadder,
///     videoCodec: .h264,
///     config: TranscodingConfig()
/// )
/// ```
///
/// - SeeAlso: ``MasterPlaylist``, ``ManifestGenerator``
public struct VariantPlaylistBuilder: Sendable {

    /// Creates a variant playlist builder.
    public init() {}

    /// Build a master playlist from variant transcoding results.
    ///
    /// - Parameters:
    ///   - variants: Transcoding results for each quality level.
    ///   - config: Transcoding configuration.
    /// - Returns: Master playlist M3U8 string.
    public func buildMasterPlaylist(
        variants: [TranscodingResult],
        config: TranscodingConfig
    ) -> String {
        let sorted = variants.sorted {
            $0.preset.totalBandwidth
                < $1.preset.totalBandwidth
        }
        let hlsVariants = sorted.map { result in
            buildVariant(
                from: result.preset,
                videoCodec: config.videoCodec,
                uri: "\(result.preset.name)/playlist.m3u8"
            )
        }
        let playlist = MasterPlaylist(
            version: .v7,
            variants: hlsVariants,
            independentSegments: true
        )
        return ManifestGenerator().generateMaster(playlist)
    }

    /// Build a master playlist from quality presets
    /// (before transcoding).
    ///
    /// Useful for pre-generating the master playlist structure.
    ///
    /// - Parameters:
    ///   - presets: Quality presets to include.
    ///   - videoCodec: Video codec used.
    ///   - config: Transcoding configuration.
    /// - Returns: Master playlist M3U8 string.
    public func buildMasterPlaylist(
        presets: [QualityPreset],
        videoCodec: OutputVideoCodec,
        config: TranscodingConfig
    ) -> String {
        let sorted = presets.sorted {
            $0.totalBandwidth < $1.totalBandwidth
        }
        let hlsVariants = sorted.map { preset in
            buildVariant(
                from: preset,
                videoCodec: videoCodec,
                uri: "\(preset.name)/playlist.m3u8"
            )
        }
        let playlist = MasterPlaylist(
            version: .v7,
            variants: hlsVariants,
            independentSegments: true
        )
        return ManifestGenerator().generateMaster(playlist)
    }

    // MARK: - Private

    private func buildVariant(
        from preset: QualityPreset,
        videoCodec: OutputVideoCodec,
        uri: String
    ) -> Variant {
        Variant(
            bandwidth: preset.totalBandwidth,
            resolution: preset.resolution,
            uri: uri,
            codecs: preset.codecsString(
                videoCodec: videoCodec
            ),
            frameRate: preset.frameRate
        )
    }
}
