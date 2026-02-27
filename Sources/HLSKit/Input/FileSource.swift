// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Reference ``MediaSource`` implementation that reads from MP4/MOV files.
///
/// Bridges the existing MP4 reading infrastructure (MP4BoxReader, SampleTableParser)
/// to the new ``MediaSource`` protocol, enabling the live pipeline to process
/// existing files for testing, simulation, and live-to-VOD workflows.
///
/// ## Usage
/// ```swift
/// let source = try FileSource(url: videoFileURL)
/// while let buffer = try await source.nextSampleBuffer() {
///     // Process buffer...
/// }
/// ```
public actor FileSource: MediaSource {

    // MARK: - Properties

    private let url: URL
    private let fileData: Data
    private let trackAnalyses: [MP4TrackAnalysis]
    private var currentSampleIndex: Int = 0
    private let totalSamples: Int

    /// The type of media in this file.
    public let mediaType: MediaSourceType

    /// Format description derived from the MP4 track info.
    public let formatDescription: MediaFormatDescription

    // MARK: - Initialization

    /// Creates a FileSource from a local file URL.
    ///
    /// Reads the MP4 box structure and sample tables at init time.
    ///
    /// - Parameter url: Path to an MP4/MOV file.
    /// - Throws: ``InputError`` if the file cannot be read or parsed.
    public init(url: URL) throws {
        self.url = url
        self.fileData = try Data(contentsOf: url)

        let boxReader = MP4BoxReader()
        let boxes = try boxReader.readBoxes(from: fileData)

        let parser = MP4InfoParser()
        let analyses = try parser.parseTrackAnalysis(from: boxes)
        self.trackAnalyses = analyses

        // Determine media type
        let hasVideo = analyses.contains { $0.info.mediaType == .video }
        let hasAudio = analyses.contains { $0.info.mediaType == .audio }

        if hasVideo && hasAudio {
            self.mediaType = .audioVideo
        } else if hasVideo {
            self.mediaType = .video
        } else if hasAudio {
            self.mediaType = .audio
        } else {
            throw InputError.noMediaTracks
        }

        // Build format description
        var audioFormat: AudioFormat?
        var videoFormat: VideoFormatInfo?

        if let audioTrack = analyses.first(where: { $0.info.mediaType == .audio }) {
            audioFormat = Self.buildAudioFormat(from: audioTrack.info)
        }

        if let videoTrack = analyses.first(where: { $0.info.mediaType == .video }) {
            videoFormat = Self.buildVideoFormat(from: videoTrack.info)
        }

        self.formatDescription = MediaFormatDescription(
            audioFormat: audioFormat,
            videoFormat: videoFormat
        )

        // Calculate total samples (from primary track)
        if let primary = analyses.first(where: { $0.info.mediaType == .video })
            ?? analyses.first(where: { $0.info.mediaType == .audio })
        {
            self.totalSamples = primary.sampleTable.sampleCount
        } else {
            self.totalSamples = 0
        }
    }

    // MARK: - MediaSource Protocol

    /// Returns the next sample buffer from the file.
    ///
    /// Reads samples sequentially using the existing SampleLocator.
    /// Returns nil when all samples have been read.
    public func nextSampleBuffer() async throws -> RawMediaBuffer? {
        guard currentSampleIndex < totalSamples else { return nil }

        // Use primary track (video preferred, then audio)
        guard
            let analysis = trackAnalyses.first(where: { $0.info.mediaType == .video })
                ?? trackAnalyses.first(where: { $0.info.mediaType == .audio })
        else {
            return nil
        }

        let locator = analysis.locator
        let info = analysis.info

        // Get sample location and read data
        let offset = locator.sampleOffset(forSample: currentSampleIndex)
        let size = locator.sampleSize(forSample: currentSampleIndex)
        let sampleData = fileData.subdata(
            in: Int(offset)..<Int(offset + UInt64(size))
        )

        // Get timing info
        let dts = locator.decodingTime(forSample: currentSampleIndex)
        let duration = locator.sampleDuration(forSample: currentSampleIndex)
        let isSyncSample = locator.isSyncSample(currentSampleIndex)

        let timestamp = MediaTimestamp(
            value: Int64(dts),
            timescale: Int32(info.timescale)
        )
        let durationTimestamp = MediaTimestamp(
            value: Int64(duration),
            timescale: Int32(info.timescale)
        )

        // Determine media type for this buffer
        let bufferMediaType: MediaSourceType = info.mediaType == .video ? .video : .audio

        // Build format info
        let formatInfo: MediaFormatInfo
        if info.mediaType == .video {
            let codec = Self.mapVideoCodec(info.codec)
            let width = Int(info.dimensions?.width ?? 0)
            let height = Int(info.dimensions?.height ?? 0)
            formatInfo = .video(codec: codec, width: width, height: height)
        } else {
            // Audio: extract sample rate from track timescale (common for AAC)
            let sampleRate = Double(info.timescale)
            formatInfo = .audio(
                sampleRate: sampleRate,
                channels: 2,
                bitsPerSample: 16,
                isFloat: false
            )
        }

        let buffer = RawMediaBuffer(
            data: sampleData,
            timestamp: timestamp,
            duration: durationTimestamp,
            isKeyframe: bufferMediaType == .audio || isSyncSample,
            mediaType: bufferMediaType,
            formatInfo: formatInfo
        )

        currentSampleIndex += 1
        return buffer
    }

    /// Whether all samples have been read.
    public var isFinished: Bool {
        currentSampleIndex >= totalSamples
    }

    /// Resets to the beginning of the file.
    public func reset() {
        currentSampleIndex = 0
    }

    // MARK: - Private Helpers

    private static func buildAudioFormat(from info: TrackInfo) -> AudioFormat {
        // Map codec string to AudioCodec
        let codec: AudioCodec
        switch info.codec.lowercased() {
        case "mp4a": codec = .aac
        case "ac-3": codec = .ac3
        case "ec-3": codec = .eac3
        case "alac": codec = .alac
        case "flac": codec = .flac
        case "opus": codec = .opus
        default: codec = .aac
        }

        return AudioFormat(
            codec: codec,
            sampleRate: Double(info.timescale),
            channels: 2,  // Default; could extract from stsd
            bitrate: nil,
            aacProfile: codec == .aac ? .lc : nil
        )
    }

    private static func buildVideoFormat(from info: TrackInfo) -> VideoFormatInfo {
        let codec = mapVideoCodec(info.codec)
        let width = Int(info.dimensions?.width ?? 1920)
        let height = Int(info.dimensions?.height ?? 1080)

        // Calculate frame rate from duration
        let frameRate: Double
        if info.timescale > 0 && info.duration > 0 {
            // This is approximate; proper calculation needs sample count
            frameRate = 30.0  // Default
        } else {
            frameRate = 30.0
        }

        return VideoFormatInfo(
            codec: codec,
            width: width,
            height: height,
            frameRate: frameRate
        )
    }

    private static func mapVideoCodec(_ codecString: String) -> VideoCodec {
        switch codecString.lowercased() {
        case "avc1", "avc3", "h264": return .h264
        case "hvc1", "hev1", "hevc", "h265": return .h265
        case "av01", "av1": return .av1
        default: return .h264
        }
    }
}
