// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Playlist Generation

extension TSSegmenter {

    /// Build an HLS playlist for TS segments.
    ///
    /// TS playlists differ from fMP4 playlists:
    /// - No `EXT-X-MAP` tag (TS segments are self-contained)
    /// - HLS version is typically 3 (not 7)
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
        let byteRangeURI = "segments.ts"
        var hlsSegments: [Segment] = []

        for seg in segments {
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

            // No EXT-X-MAP for TS segments
            hlsSegments.append(
                Segment(
                    duration: seg.duration,
                    uri: uri,
                    byteRange: byteRange
                )
            )
        }
        return hlsSegments
    }
}
