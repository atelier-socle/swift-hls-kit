// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Raw media buffer — platform-independent equivalent of CMSampleBuffer.
///
/// On Apple platforms, the app converts CMSampleBuffer → RawMediaBuffer.
/// On Linux (server), data comes from file I/O or network.
///
/// ## Usage
/// ```swift
/// let buffer = RawMediaBuffer(
///     data: pcmData,
///     timestamp: MediaTimestamp(seconds: 0.0),
///     duration: MediaTimestamp(seconds: 0.02),
///     isKeyframe: true,
///     mediaType: .audio,
///     formatInfo: .audio(sampleRate: 48000, channels: 2, bitsPerSample: 16)
/// )
/// ```
public struct RawMediaBuffer: Sendable {

    /// Raw media data bytes.
    public let data: Data

    /// Presentation timestamp.
    public let timestamp: MediaTimestamp

    /// Duration of this buffer.
    public let duration: MediaTimestamp

    /// Whether this buffer starts at a keyframe (always true for audio).
    public let isKeyframe: Bool

    /// Type of media in this buffer.
    public let mediaType: MediaSourceType

    /// Format information for this buffer.
    public let formatInfo: MediaFormatInfo

    /// Audio channel layout for multi-channel / spatial audio. Nil for video or default stereo.
    public let channelLayout: AudioChannelLayout?

    /// HDR metadata if applicable. Nil for SDR content.
    public let hdrMetadata: HDRMetadata?

    /// Closed captions payload embedded in this buffer (CEA-608/708). Nil if none.
    public let closedCaptionsPayload: Data?

    /// Creates a raw media buffer.
    ///
    /// - Parameters:
    ///   - data: The raw media data bytes.
    ///   - timestamp: The presentation timestamp.
    ///   - duration: The duration of this buffer.
    ///   - isKeyframe: Whether this buffer starts at a keyframe.
    ///   - mediaType: The type of media in this buffer.
    ///   - formatInfo: Format information for this buffer.
    ///   - channelLayout: Optional audio channel layout.
    ///   - hdrMetadata: Optional HDR metadata.
    ///   - closedCaptionsPayload: Optional closed captions payload.
    public init(
        data: Data,
        timestamp: MediaTimestamp,
        duration: MediaTimestamp,
        isKeyframe: Bool,
        mediaType: MediaSourceType,
        formatInfo: MediaFormatInfo,
        channelLayout: AudioChannelLayout? = nil,
        hdrMetadata: HDRMetadata? = nil,
        closedCaptionsPayload: Data? = nil
    ) {
        self.data = data
        self.timestamp = timestamp
        self.duration = duration
        self.isKeyframe = isKeyframe
        self.mediaType = mediaType
        self.formatInfo = formatInfo
        self.channelLayout = channelLayout
        self.hdrMetadata = hdrMetadata
        self.closedCaptionsPayload = closedCaptionsPayload
    }
}

// MARK: - MediaTimestamp

/// Platform-independent media timestamp with sub-sample precision.
public struct MediaTimestamp: Sendable, Comparable, Equatable, Hashable {

    /// Time in seconds.
    public let seconds: Double

    /// Timescale for integer-based calculations (e.g., 44100 for audio, 90000 for video).
    public let timescale: Int32

    /// Integer value = seconds × timescale. For precise calculations.
    public var value: Int64 {
        Int64(seconds * Double(timescale))
    }

    /// Creates a timestamp from seconds.
    ///
    /// - Parameters:
    ///   - seconds: Time in seconds.
    ///   - timescale: Timescale for integer calculations. Default is 90000 (video standard).
    public init(seconds: Double, timescale: Int32 = 90_000) {
        self.seconds = seconds
        self.timescale = timescale
    }

    /// Creates a timestamp from integer value and timescale.
    ///
    /// - Parameters:
    ///   - value: Integer time value.
    ///   - timescale: Timescale divisor.
    public init(value: Int64, timescale: Int32) {
        self.seconds = Double(value) / Double(timescale)
        self.timescale = timescale
    }

    /// Zero timestamp.
    public static let zero = MediaTimestamp(seconds: 0.0)

    public static func < (lhs: MediaTimestamp, rhs: MediaTimestamp) -> Bool {
        lhs.seconds < rhs.seconds
    }
}

// MARK: - MediaFormatInfo

/// Format info for a raw media buffer.
public enum MediaFormatInfo: Sendable, Equatable {

    /// Audio format info.
    case audio(sampleRate: Double, channels: Int, bitsPerSample: Int, isFloat: Bool = false)

    /// Video format info.
    case video(codec: VideoCodec, width: Int, height: Int)
}

// MARK: - AudioChannelLayout

/// Audio channel layout descriptor — for multi-channel and spatial audio.
///
/// Used to describe channel arrangements beyond simple stereo.
public struct AudioChannelLayout: Sendable, Equatable {

    /// Layout identifier.
    public let layout: Layout

    /// Number of channels.
    public let channelCount: Int

    /// Supported channel layout types.
    public enum Layout: String, Sendable, Codable, CaseIterable {

        /// Mono (1 channel).
        case mono

        /// Stereo (2 channels).
        case stereo

        /// 5.1 surround (L, R, C, LFE, Ls, Rs).
        case surround51

        /// 7.1 surround.
        case surround71

        /// 7.1.4 (Atmos bed).
        case surround714

        /// Binaural stereo.
        case binaural

        /// Joint Object Coding (Dolby Atmos object-based).
        case jointObjectCoding
    }

    /// Creates an audio channel layout.
    ///
    /// - Parameter layout: The layout type.
    public init(layout: Layout) {
        self.layout = layout
        self.channelCount =
            switch layout {
            case .mono: 1
            case .stereo, .binaural: 2
            case .surround51: 6
            case .surround71: 8
            case .surround714: 12
            case .jointObjectCoding: 16
            }
    }

    /// HLS CHANNELS attribute string (e.g., "2", "6", "16/JOC").
    public var hlsChannelsAttribute: String {
        switch layout {
        case .jointObjectCoding: "16/JOC"
        default: "\(channelCount)"
        }
    }
}

// MARK: - HDRMetadata

/// HDR metadata container — for HDR10, HDR10+, Dolby Vision, HLG.
///
/// Carried alongside video buffers for HDR content.
public struct HDRMetadata: Sendable, Equatable {

    /// HDR type.
    public let type: HDRType

    /// MaxCLL (Maximum Content Light Level) in nits. HDR10 static metadata.
    public let maxContentLightLevel: Int?

    /// MaxFALL (Maximum Frame Average Light Level) in nits. HDR10 static metadata.
    public let maxFrameAverageLightLevel: Int?

    /// Dynamic metadata payload (HDR10+, Dolby Vision RPU). Nil for static HDR.
    public let dynamicMetadata: Data?

    /// HDR type identifiers.
    public enum HDRType: String, Sendable, Codable, CaseIterable {

        /// SMPTE ST 2084 (PQ), static metadata.
        case hdr10

        /// SMPTE ST 2094-40, dynamic metadata.
        case hdr10Plus

        /// Dolby Vision, RPU metadata.
        case dolbyVision

        /// Hybrid Log-Gamma, no metadata needed.
        case hlg
    }

    /// Creates HDR metadata.
    ///
    /// - Parameters:
    ///   - type: The HDR type.
    ///   - maxContentLightLevel: Optional MaxCLL in nits.
    ///   - maxFrameAverageLightLevel: Optional MaxFALL in nits.
    ///   - dynamicMetadata: Optional dynamic metadata payload.
    public init(
        type: HDRType,
        maxContentLightLevel: Int? = nil,
        maxFrameAverageLightLevel: Int? = nil,
        dynamicMetadata: Data? = nil
    ) {
        self.type = type
        self.maxContentLightLevel = maxContentLightLevel
        self.maxFrameAverageLightLevel = maxFrameAverageLightLevel
        self.dynamicMetadata = dynamicMetadata
    }
}
