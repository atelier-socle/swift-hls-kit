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
        let videoAnalysis: MP4TrackAnalysis?
        let audioAnalysis: MP4TrackAnalysis?
        let config: SegmentationConfig
        let sourceData: Data
    }
}

// MARK: - Pipeline

extension MP4Segmenter {

    /// Supported video codecs for HLS segmentation.
    static let supportedVideoCodecs: Set<String> = [
        "avc1", "avc3", "hvc1", "hev1", "av01"
    ]

    private func performSegmentation(
        data: Data,
        config: SegmentationConfig
    ) throws(MP4Error) -> SegmentationResult {
        let parsed = try parseMP4(data: data)
        let segments = calculatePrimarySegments(
            parsed: parsed, config: config
        )
        let initSegment = try generateInit(parsed: parsed)
        let ctx = SegmentContext(
            videoAnalysis: parsed.video,
            audioAnalysis: parsed.audio,
            config: config, sourceData: data
        )
        let mediaSegments = try generateMediaSegments(
            segments: segments, context: ctx
        )
        let finalSegments = applyByteRangeOffsets(
            segments: mediaSegments, config: config
        )
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
            fileInfo: parsed.fileInfo,
            config: config
        )
    }

    private func parseMP4(
        data: Data
    ) throws(MP4Error) -> ParsedMP4 {
        let boxReader = MP4BoxReader()
        let boxes = try boxReader.readBoxes(from: data)
        let infoParser = MP4InfoParser()
        let fileInfo = try infoParser.parseFileInfo(from: boxes)
        let trackAnalyses = try infoParser.parseTrackAnalysis(
            from: boxes
        )
        let video = trackAnalyses.first {
            $0.info.mediaType == .video
                && Self.supportedVideoCodecs.contains(
                    $0.info.codec
                )
        }
        let audio = trackAnalyses.first {
            $0.info.mediaType == .audio
        }
        guard video != nil || audio != nil else {
            throw .invalidMP4("No video or audio track found")
        }
        let mediaTracks = trackAnalyses.filter {
            ($0.info.mediaType == .video
                && Self.supportedVideoCodecs.contains(
                    $0.info.codec
                ))
                || $0.info.mediaType == .audio
        }
        return ParsedMP4(
            fileInfo: fileInfo, video: video,
            audio: audio, mediaTracks: mediaTracks
        )
    }

    private func calculatePrimarySegments(
        parsed: ParsedMP4,
        config: SegmentationConfig
    ) -> [SegmentInfo] {
        if let video = parsed.video {
            return video.locator.calculateSegments(
                targetDuration: config.targetSegmentDuration
            )
        }
        if let audio = parsed.audio {
            return audio.locator.calculateSegments(
                targetDuration: config.targetSegmentDuration,
                forceAllSync: true
            )
        }
        return []
    }

    private func generateInit(
        parsed: ParsedMP4
    ) throws(MP4Error) -> Data {
        let initWriter = InitSegmentWriter()
        return try initWriter.generateInitSegment(
            fileInfo: parsed.fileInfo,
            trackAnalyses: parsed.mediaTracks
        )
    }

    /// Parsed MP4 structure for segmentation.
    struct ParsedMP4 {
        let fileInfo: MP4FileInfo
        let video: MP4TrackAnalysis?
        let audio: MP4TrackAnalysis?
        let mediaTracks: [MP4TrackAnalysis]
    }
}

// MARK: - Media Segment Generation

extension MP4Segmenter {

    private func generateMediaSegments(
        segments: [SegmentInfo],
        context: SegmentContext
    ) throws(MP4Error) -> [MediaSegmentOutput] {
        let writer = MediaSegmentWriter()

        if let video = context.videoAnalysis {
            return try generateVideoSegments(
                segments: segments,
                videoAnalysis: video,
                writer: writer,
                context: context
            )
        }

        if let audio = context.audioAnalysis {
            return try generateAudioOnlySegments(
                segments: segments,
                audioAnalysis: audio,
                writer: writer,
                context: context
            )
        }

        return []
    }

    private func generateVideoSegments(
        segments: [SegmentInfo],
        videoAnalysis: MP4TrackAnalysis,
        writer: MediaSegmentWriter,
        context: SegmentContext
    ) throws(MP4Error) -> [MediaSegmentOutput] {
        let useMuxed =
            context.config.includeAudio
            && context.audioAnalysis != nil
        var result: [MediaSegmentOutput] = []

        for (index, seg) in segments.enumerated() {
            let seq = UInt32(index + 1)
            let segmentData: Data
            if useMuxed, let audio = context.audioAnalysis {
                let audioSeg =
                    audio.locator.alignedAudioSegment(
                        for: seg,
                        videoTimescale: videoAnalysis.info
                            .timescale
                    )
                segmentData = try writer.generateMuxedSegment(
                    video: MuxedTrackInput(
                        segment: seg, analysis: videoAnalysis
                    ),
                    audio: MuxedTrackInput(
                        segment: audioSeg, analysis: audio
                    ),
                    sequenceNumber: seq,
                    sourceData: context.sourceData
                )
            } else {
                segmentData = try writer.generateMediaSegment(
                    segmentInfo: seg,
                    sequenceNumber: seq,
                    trackAnalysis: videoAnalysis,
                    sourceData: context.sourceData
                )
            }
            let filename = segmentFilename(
                pattern: context.config.segmentNamePattern,
                index: index
            )
            result.append(
                MediaSegmentOutput(
                    index: index, data: segmentData,
                    duration: seg.duration,
                    filename: filename,
                    byteRangeOffset: nil,
                    byteRangeLength: nil
                )
            )
        }
        return result
    }

    private func generateAudioOnlySegments(
        segments: [SegmentInfo],
        audioAnalysis: MP4TrackAnalysis,
        writer: MediaSegmentWriter,
        context: SegmentContext
    ) throws(MP4Error) -> [MediaSegmentOutput] {
        var result: [MediaSegmentOutput] = []
        for (index, seg) in segments.enumerated() {
            let seq = UInt32(index + 1)
            let segmentData = try writer.generateMediaSegment(
                segmentInfo: seg,
                sequenceNumber: seq,
                trackAnalysis: audioAnalysis,
                sourceData: context.sourceData
            )
            let filename = segmentFilename(
                pattern: context.config.segmentNamePattern,
                index: index
            )
            result.append(
                MediaSegmentOutput(
                    index: index, data: segmentData,
                    duration: seg.duration,
                    filename: filename,
                    byteRangeOffset: nil,
                    byteRangeLength: nil
                )
            )
        }
        return result
    }

}
