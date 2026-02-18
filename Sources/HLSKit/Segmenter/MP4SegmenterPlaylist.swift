// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Playlist Generation

extension MP4Segmenter {

    /// Build an HLS playlist from segmentation output.
    ///
    /// Bridges Phase 2 (segmenter) output with Phase 1 (manifest
    /// generator) models to produce a valid M3U8 string.
    func buildPlaylist(
        segments: [MediaSegmentOutput],
        config: SegmentationConfig
    ) -> String {
        let targetDuration = calculateTargetDuration(
            segments: segments
        )
        let hlsSegments = buildHLSSegments(
            segments: segments, config: config
        )
        let version = HLSVersion(rawValue: config.hlsVersion)
        let playlist = MediaPlaylist(
            version: version,
            targetDuration: targetDuration,
            mediaSequence: 0,
            playlistType: config.playlistType,
            hasEndList: true,
            segments: hlsSegments,
            independentSegments: true
        )
        return ManifestGenerator().generateMedia(playlist)
    }

    private func calculateTargetDuration(
        segments: [MediaSegmentOutput]
    ) -> Int {
        let maxDuration = segments.map(\.duration).max() ?? 6.0
        return Int(maxDuration.rounded(.up))
    }

    private func buildHLSSegments(
        segments: [MediaSegmentOutput],
        config: SegmentationConfig
    ) -> [Segment] {
        let isByteRange = config.outputMode == .byteRange
        let byteRangeURI = byteRangeSegmentFilename(config: config)
        var hlsSegments: [Segment] = []

        for (index, seg) in segments.enumerated() {
            let uri = isByteRange ? byteRangeURI : seg.filename
            var byteRange: ByteRange?
            if isByteRange,
                let offset = seg.byteRangeOffset,
                let length = seg.byteRangeLength
            {
                byteRange = ByteRange(
                    length: Int(length), offset: Int(offset)
                )
            }

            // First segment gets the EXT-X-MAP tag
            let map: MapTag?
            if index == 0 {
                map = MapTag(uri: config.initSegmentName)
            } else {
                map = nil
            }

            hlsSegments.append(
                Segment(
                    duration: seg.duration,
                    uri: uri,
                    byteRange: byteRange,
                    map: map
                )
            )
        }
        return hlsSegments
    }
}
