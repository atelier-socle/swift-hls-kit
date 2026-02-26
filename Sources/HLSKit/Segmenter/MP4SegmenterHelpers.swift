// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Byte-Range

extension MP4Segmenter {

    func applyByteRangeOffsets(
        segments: [MediaSegmentOutput],
        config: SegmentationConfig
    ) -> [MediaSegmentOutput] {
        guard config.outputMode == .byteRange else {
            return segments
        }
        var offset: UInt64 = 0
        var result: [MediaSegmentOutput] = []
        for seg in segments {
            let length = UInt64(seg.data.count)
            result.append(
                MediaSegmentOutput(
                    index: seg.index, data: seg.data,
                    duration: seg.duration,
                    filename: seg.filename,
                    byteRangeOffset: offset,
                    byteRangeLength: length
                )
            )
            offset += length
        }
        return result
    }
}

// MARK: - Helpers

extension MP4Segmenter {

    func segmentFilename(
        pattern: String, index: Int
    ) -> String {
        guard let range = pattern.range(of: "%d") else {
            return pattern
        }
        return pattern.replacingCharacters(
            in: range, with: "\(index)"
        )
    }

    func writeResult(
        _ result: SegmentationResult,
        to directory: URL
    ) throws {
        let config = result.config
        let initURL = directory.appendingPathComponent(
            config.initSegmentName
        )
        try result.initSegment.write(to: initURL)

        if config.outputMode == .byteRange {
            try writeByteRangeFile(result, to: directory)
        } else {
            for segment in result.mediaSegments {
                let segURL = directory.appendingPathComponent(
                    segment.filename
                )
                try segment.data.write(to: segURL)
            }
        }

        if let playlist = result.playlist {
            let playlistURL = directory.appendingPathComponent(
                config.playlistName
            )
            try playlist.write(
                to: playlistURL, atomically: true,
                encoding: .utf8
            )
        }
    }

    private func writeByteRangeFile(
        _ result: SegmentationResult,
        to directory: URL
    ) throws {
        let filename = byteRangeSegmentFilename(
            config: result.config
        )
        let fileURL = directory.appendingPathComponent(filename)
        var combined = Data()
        for segment in result.mediaSegments {
            combined.append(segment.data)
        }
        try combined.write(to: fileURL)
    }

    func byteRangeSegmentFilename(
        config: SegmentationConfig
    ) -> String {
        "segments.m4s"
    }
}
