// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Segments an MP4 file into MPEG-TS (.ts) segments for HLS delivery.
///
/// Uses the same MP4 reading and sample analysis as ``MP4Segmenter``,
/// but outputs MPEG Transport Stream segments instead of fMP4.
///
/// ## Usage
///
/// ```swift
/// let config = SegmentationConfig(containerFormat: .mpegTS)
/// let segmenter = TSSegmenter()
/// let result = try segmenter.segment(data: mp4Data, config: config)
/// ```
///
/// - SeeAlso: ``MP4Segmenter`` for fMP4 output
public struct TSSegmenter: Sendable {

    /// Creates a new TS segmenter.
    public init() {}

    /// Segment MP4 data into MPEG-TS segments.
    ///
    /// - Parameters:
    ///   - data: The MP4 file data.
    ///   - config: Segmentation configuration.
    /// - Returns: Segmentation result with .ts segments and playlist.
    /// - Throws: `MP4Error` or `TransportError`.
    public func segment(
        data: Data,
        config: SegmentationConfig = SegmentationConfig()
    ) throws -> SegmentationResult {
        try performSegmentation(data: data, config: config)
    }

    /// Segment from a file URL.
    ///
    /// - Parameters:
    ///   - url: The file URL of the MP4.
    ///   - config: Segmentation configuration.
    /// - Returns: Segmentation result with .ts segments and playlist.
    /// - Throws: `MP4Error` or `TransportError`.
    public func segment(
        url: URL,
        config: SegmentationConfig = SegmentationConfig()
    ) throws -> SegmentationResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw MP4Error.ioError(error.localizedDescription)
        }
        return try performSegmentation(data: data, config: config)
    }

    /// Segment and write to a directory.
    ///
    /// - Parameters:
    ///   - data: The MP4 file data.
    ///   - outputDirectory: Directory to write files to.
    ///   - config: Segmentation configuration.
    /// - Returns: Segmentation result with .ts segments and playlist.
    /// - Throws: `MP4Error` or `TransportError`.
    public func segmentToDirectory(
        data: Data,
        outputDirectory: URL,
        config: SegmentationConfig = SegmentationConfig()
    ) throws -> SegmentationResult {
        let result = try performSegmentation(
            data: data, config: config
        )
        try writeResult(result, to: outputDirectory)
        return result
    }
}

// MARK: - Pipeline

extension TSSegmenter {

    private func performSegmentation(
        data: Data,
        config: SegmentationConfig
    ) throws -> SegmentationResult {
        let analysis = try analyzeMP4(data: data)
        let codecConfig = try extractCodecConfig(
            videoAnalysis: analysis.video,
            audioAnalysis: analysis.audio,
            sourceBoxes: analysis.boxes
        )
        let segments = calculateSegments(
            analysis: analysis, config: config
        )
        let mediaSegments = try generateTSSegments(
            segments: segments, analysis: analysis,
            codecConfig: codecConfig,
            config: config, sourceData: data
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
            initSegment: Data(),
            mediaSegments: finalSegments,
            playlist: playlist,
            fileInfo: analysis.fileInfo,
            config: config
        )
    }

    private func analyzeMP4(
        data: Data
    ) throws -> MP4Analysis {
        let boxReader = MP4BoxReader()
        let boxes = try boxReader.readBoxes(from: data)
        let infoParser = MP4InfoParser()
        let fileInfo = try infoParser.parseFileInfo(from: boxes)
        let tracks = try infoParser.parseTrackAnalysis(
            from: boxes
        )
        let supportedVideoCodecs: Set<String> = [
            "avc1", "avc3", "hvc1", "hev1"
        ]
        let video = tracks.first {
            $0.info.mediaType == .video
                && supportedVideoCodecs.contains($0.info.codec)
        }
        let audio = tracks.first {
            $0.info.mediaType == .audio
        }
        guard video != nil || audio != nil else {
            throw MP4Error.invalidMP4(
                "No video or audio track found"
            )
        }
        return MP4Analysis(
            boxes: boxes, fileInfo: fileInfo,
            video: video, audio: audio
        )
    }

    private func calculateSegments(
        analysis: MP4Analysis,
        config: SegmentationConfig
    ) -> [SegmentInfo] {
        if let video = analysis.video {
            return video.locator.calculateSegments(
                targetDuration: config.targetSegmentDuration
            )
        } else if let audio = analysis.audio {
            return audio.locator.calculateSegments(
                targetDuration: config.targetSegmentDuration
            )
        }
        return []
    }
}

// MARK: - MP4 Analysis

extension TSSegmenter {

    private struct MP4Analysis {
        let boxes: [MP4Box]
        let fileInfo: MP4FileInfo
        let video: MP4TrackAnalysis?
        let audio: MP4TrackAnalysis?
    }
}
// MARK: - TS Segment Generation

extension TSSegmenter {

    private struct SegmentContext {
        let analysis: MP4Analysis
        let codecConfig: TSCodecConfig
        let config: SegmentationConfig
        let sourceData: Data
        let builder: TSSegmentBuilder
    }

    private func generateTSSegments(
        segments: [SegmentInfo],
        analysis: MP4Analysis,
        codecConfig: TSCodecConfig,
        config: SegmentationConfig,
        sourceData: Data
    ) throws -> [MediaSegmentOutput] {
        let ctx = SegmentContext(
            analysis: analysis,
            codecConfig: codecConfig,
            config: config,
            sourceData: sourceData,
            builder: TSSegmentBuilder()
        )
        var mediaSegments: [MediaSegmentOutput] = []
        for (index, segInfo) in segments.enumerated() {
            let segmentData = try buildSegmentData(
                segInfo: segInfo, index: index, ctx: ctx
            )
            guard let segmentData else { continue }
            let filename = segmentFilename(
                pattern: config.segmentNamePattern,
                index: index
            )
            mediaSegments.append(
                MediaSegmentOutput(
                    index: index, data: segmentData,
                    duration: segInfo.duration,
                    filename: filename,
                    byteRangeOffset: nil,
                    byteRangeLength: nil
                )
            )
        }
        return mediaSegments
    }

    private func buildSegmentData(
        segInfo: SegmentInfo,
        index: Int,
        ctx: SegmentContext
    ) throws -> Data? {
        let seq = UInt32(index + 1)
        let useMuxed =
            ctx.config.includeAudio
            && ctx.analysis.audio != nil

        if let video = ctx.analysis.video {
            let videoSamples = collectSamples(
                segInfo: segInfo,
                analysis: video,
                sourceData: ctx.sourceData
            )
            var audioSamples: [SampleData]?
            if useMuxed, let audio = ctx.analysis.audio {
                let audioSegInfo =
                    audio.locator.alignedAudioSegment(
                        for: segInfo,
                        videoTimescale: video.info.timescale
                    )
                audioSamples = collectSamples(
                    segInfo: audioSegInfo,
                    analysis: audio,
                    sourceData: ctx.sourceData
                )
            }
            return ctx.builder.buildSegment(
                videoSamples: videoSamples,
                audioSamples: audioSamples,
                config: ctx.codecConfig,
                sequenceNumber: seq
            )
        } else if let audio = ctx.analysis.audio {
            let audioSamples = collectSamples(
                segInfo: segInfo,
                analysis: audio,
                sourceData: ctx.sourceData
            )
            return ctx.builder.buildAudioOnlySegment(
                audioSamples: audioSamples,
                config: ctx.codecConfig,
                sequenceNumber: seq
            )
        }
        return nil
    }

    private func collectSamples(
        segInfo: SegmentInfo,
        analysis: MP4TrackAnalysis,
        sourceData: Data
    ) -> [SampleData] {
        let locator = analysis.locator
        let timescale = analysis.info.timescale
        let tsTimescale: UInt64 = 90000
        var samples: [SampleData] = []
        samples.reserveCapacity(segInfo.sampleCount)

        for i in 0..<segInfo.sampleCount {
            let idx = segInfo.firstSample + i
            let offset = locator.sampleOffset(forSample: idx)
            let size = locator.sampleSize(forSample: idx)
            let sampleEnd = Int(offset) + Int(size)
            guard sampleEnd <= sourceData.count else {
                continue
            }
            let data = sourceData.subdata(
                in: Int(offset)..<sampleEnd
            )
            let dts = locator.decodingTime(forSample: idx)
            let pts = locator.presentationTime(forSample: idx)
            let duration = locator.sampleDuration(
                forSample: idx
            )
            // Convert to 90kHz TS timescale
            let ts = UInt64(timescale)
            let pts90k = pts * tsTimescale / ts
            let dts90k = dts * tsTimescale / ts
            let dur90k = UInt32(
                UInt64(duration) * tsTimescale / ts
            )
            let isSync = locator.isSyncSample(idx)
            samples.append(
                SampleData(
                    data: data, pts: pts90k,
                    dts: pts90k != dts90k ? dts90k : nil,
                    duration: dur90k, isSync: isSync
                )
            )
        }
        return samples
    }
}

// MARK: - Byte-Range

extension TSSegmenter {

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

extension TSSegmenter {

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
        if config.outputMode == .byteRange {
            let fileURL = directory.appendingPathComponent(
                "segments.ts"
            )
            var combined = Data()
            for segment in result.mediaSegments {
                combined.append(segment.data)
            }
            try combined.write(to: fileURL)
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
}
