// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Track media type.
public enum MediaTrackType: String, Sendable, Hashable, Codable {
    case video = "vide"
    case audio = "soun"
    case subtitle = "sbtl"
    case text = "text"
    case unknown
}

// MARK: - Track Info

/// Parsed information about a single track.
///
/// Contains the essential metadata extracted from the trak box
/// hierarchy: tkhd, mdhd, hdlr, and stsd.
public struct TrackInfo: Sendable, Hashable {

    /// Track ID (from tkhd).
    public let trackId: UInt32

    /// Media type.
    public let mediaType: MediaTrackType

    /// Track-level timescale (from mdhd).
    public let timescale: UInt32

    /// Track duration in timescale units (from mdhd).
    public let duration: UInt64

    /// Duration in seconds.
    public var durationSeconds: Double {
        guard timescale > 0 else { return 0 }
        return Double(duration) / Double(timescale)
    }

    /// Codec identifier (from stsd: "avc1", "hvc1", "mp4a", etc.).
    public let codec: String

    /// Video dimensions (nil for audio).
    public let dimensions: VideoDimensions?

    /// Language code (from mdhd, ISO 639-2/T).
    public let language: String?

    /// Sample description data (raw stsd entry for init segment).
    public let sampleDescriptionData: Data

    /// Whether this track has sync sample markers (stss).
    public let hasSyncSamples: Bool
}

// MARK: - Video Dimensions

/// Video track dimensions.
public struct VideoDimensions: Sendable, Hashable, Codable {
    /// Width in pixels.
    public let width: UInt16

    /// Height in pixels.
    public let height: UInt16

    /// Creates video dimensions.
    public init(width: UInt16, height: UInt16) {
        self.width = width
        self.height = height
    }
}

// MARK: - MP4 File Info

/// Parsed information about an MP4 file.
///
/// Extracted from the moov box hierarchy. Contains the movie-level
/// timescale, duration, file brands, and per-track information.
///
/// ```swift
/// let reader = MP4BoxReader()
/// let boxes = try reader.readBoxes(from: data)
/// let parser = MP4InfoParser()
/// let info = try parser.parseFileInfo(from: boxes)
/// print("Duration: \(info.durationSeconds)s")
/// print("Video: \(info.videoTrack?.codec ?? "none")")
/// ```
public struct MP4FileInfo: Sendable, Hashable {

    /// Movie-level timescale (ticks per second).
    public let timescale: UInt32

    /// Movie duration in timescale units.
    public let duration: UInt64

    /// Duration in seconds.
    public var durationSeconds: Double {
        guard timescale > 0 else { return 0 }
        return Double(duration) / Double(timescale)
    }

    /// Compatible brands from ftyp.
    public let brands: [String]

    /// Tracks in the file.
    public let tracks: [TrackInfo]

    /// Find the first video track.
    public var videoTrack: TrackInfo? {
        tracks.first { $0.mediaType == .video }
    }

    /// Find the first audio track.
    public var audioTrack: TrackInfo? {
        tracks.first { $0.mediaType == .audio }
    }
}
