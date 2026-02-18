// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Segments an MP4 file into HLS-compatible fMP4 fragments.
///
/// Takes an existing MP4 file (already encoded) and splits it into
/// an initialization segment and media segments, suitable for HLS
/// delivery. No transcoding is performed — this is pure container
/// manipulation.
///
/// ## Basic Usage
///
/// ```swift
/// let segmenter = MP4Segmenter()
/// let result = try segmenter.segment(data: mp4Data)
///
/// // Write files
/// for segment in result.mediaSegments {
///     try segment.data.write(to: dir.appending(path: segment.filename))
/// }
/// ```
///
/// ## Byte-Range Mode
///
/// ```swift
/// var config = SegmentationConfig()
/// config.outputMode = .byteRange
/// let result = try segmenter.segment(data: mp4Data, config: config)
/// ```
///
/// - SeeAlso: ``SegmentationConfig``, ``SegmentationResult``
public struct MP4Segmenter: Sendable {

    /// Creates a new MP4 segmenter.
    public init() {}

    /// Segment MP4 data into HLS fMP4 fragments.
    ///
    /// - Parameters:
    ///   - data: The MP4 file data.
    ///   - config: Segmentation configuration.
    /// - Returns: The segmentation result.
    /// - Throws: `MP4Error` if the data is not valid MP4.
    public func segment(
        data: Data,
        config: SegmentationConfig = SegmentationConfig()
    ) throws(MP4Error) -> SegmentationResult {
        try performSegmentation(data: data, config: config)
    }

    /// Segment an MP4 file from a URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the MP4.
    ///   - config: Segmentation configuration.
    /// - Returns: The segmentation result.
    /// - Throws: `MP4Error` if the file cannot be read or is invalid.
    public func segment(
        url: URL,
        config: SegmentationConfig = SegmentationConfig()
    ) throws(MP4Error) -> SegmentationResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw .ioError(error.localizedDescription)
        }
        return try performSegmentation(data: data, config: config)
    }

    /// Segment and write output files to a directory.
    ///
    /// Writes init.mp4, segments, and playlist to the directory.
    ///
    /// - Parameters:
    ///   - data: The MP4 file data.
    ///   - outputDirectory: Directory to write files to (must exist).
    ///   - config: Segmentation configuration.
    /// - Returns: The segmentation result.
    /// - Throws: `MP4Error` if segmentation or I/O fails.
    public func segmentToDirectory(
        data: Data,
        outputDirectory: URL,
        config: SegmentationConfig = SegmentationConfig()
    ) throws(MP4Error) -> SegmentationResult {
        let result = try performSegmentation(
            data: data, config: config
        )
        do {
            try writeResult(result, to: outputDirectory)
        } catch let error as MP4Error {
            throw error
        } catch {
            throw .ioError(error.localizedDescription)
        }
        return result
    }
}

// MARK: - Pipeline Context

extension MP4Segmenter {

    /// Groups the parameters needed during segment generation.
    struct SegmentContext {
        let videoAnalysis: MP4TrackAnalysis
        let audioAnalysis: MP4TrackAnalysis?
        let config: SegmentationConfig
        let sourceData: Data
    }
}

// MARK: - Pipeline

extension MP4Segmenter {

    private func performSegmentation(
        data: Data,
        config: SegmentationConfig
    ) throws(MP4Error) -> SegmentationResult {
        // 1. Read MP4 boxes
        let boxReader = MP4BoxReader()
        let boxes = try boxReader.readBoxes(from: data)

        // 2. Parse file info
        let infoParser = MP4InfoParser()
        let fileInfo = try infoParser.parseFileInfo(from: boxes)

        // 3. Parse track analyses
        let trackAnalyses = try infoParser.parseTrackAnalysis(
            from: boxes
        )

        // 4. Identify video and audio tracks
        guard
            let video = trackAnalyses.first(where: {
                $0.info.mediaType == .video
            })
        else {
            throw .invalidMP4("No video track found")
        }
        let audio = trackAnalyses.first {
            $0.info.mediaType == .audio
        }

        // 5. Calculate video segments
        let videoSegments = video.locator.calculateSegments(
            targetDuration: config.targetSegmentDuration
        )

        // 6. Generate init segment
        let initWriter = InitSegmentWriter()
        let initSegment = try initWriter.generateInitSegment(
            fileInfo: fileInfo,
            trackAnalyses: trackAnalyses
        )

        // 7. Generate media segments
        let ctx = SegmentContext(
            videoAnalysis: video, audioAnalysis: audio,
            config: config, sourceData: data
        )
        let mediaSegments = try generateMediaSegments(
            videoSegments: videoSegments, context: ctx
        )

        // 8. Apply byte-range offsets if needed
        let finalSegments = applyByteRangeOffsets(
            segments: mediaSegments, config: config
        )

        // 9. Generate playlist if requested
        let playlist: String?
        if config.generatePlaylist {
            playlist = buildPlaylist(
                segments: finalSegments, config: config
            )
        } else {
            playlist = nil
        }

        return SegmentationResult(
            initSegment: initSegment,
            mediaSegments: finalSegments,
            playlist: playlist,
            fileInfo: fileInfo,
            config: config
        )
    }
}

// MARK: - Media Segment Generation

extension MP4Segmenter {

    private func generateMediaSegments(
        videoSegments: [SegmentInfo],
        context: SegmentContext
    ) throws(MP4Error) -> [MediaSegmentOutput] {
        let writer = MediaSegmentWriter()
        let useMuxed =
            context.config.includeAudio
            && context.audioAnalysis != nil
        var segments: [MediaSegmentOutput] = []

        for (index, videoSeg) in videoSegments.enumerated() {
            let seq = UInt32(index + 1)
            let segmentData: Data
            if useMuxed, let audio = context.audioAnalysis {
                segmentData = try buildMuxedSegment(
                    writer: writer,
                    videoSegment: videoSeg,
                    audioAnalysis: audio,
                    context: context,
                    sequenceNumber: seq
                )
            } else {
                segmentData = try writer.generateMediaSegment(
                    segmentInfo: videoSeg,
                    sequenceNumber: seq,
                    trackAnalysis: context.videoAnalysis,
                    sourceData: context.sourceData
                )
            }
            let filename = segmentFilename(
                pattern: context.config.segmentNamePattern,
                index: index
            )
            segments.append(
                MediaSegmentOutput(
                    index: index, data: segmentData,
                    duration: videoSeg.duration,
                    filename: filename,
                    byteRangeOffset: nil,
                    byteRangeLength: nil
                )
            )
        }
        return segments
    }

    private func buildMuxedSegment(
        writer: MediaSegmentWriter,
        videoSegment: SegmentInfo,
        audioAnalysis: MP4TrackAnalysis,
        context: SegmentContext,
        sequenceNumber: UInt32
    ) throws(MP4Error) -> Data {
        let audioSeg = audioAnalysis.locator.alignedAudioSegment(
            for: videoSegment,
            videoTimescale: context.videoAnalysis.info.timescale
        )
        return try writer.generateMuxedSegment(
            video: MuxedTrackInput(
                segment: videoSegment,
                analysis: context.videoAnalysis
            ),
            audio: MuxedTrackInput(
                segment: audioSeg, analysis: audioAnalysis
            ),
            sequenceNumber: sequenceNumber,
            sourceData: context.sourceData
        )
    }
}

// MARK: - Byte-Range

extension MP4Segmenter {

    private func applyByteRangeOffsets(
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

    private func writeResult(
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
