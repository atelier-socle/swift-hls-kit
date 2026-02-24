// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A compressed media frame produced by a ``LiveEncoder``.
///
/// Contains the encoded data along with timing and codec metadata needed
/// for segmentation and packaging into HLS transport streams.
///
/// ## Usage
/// ```swift
/// let frame = EncodedFrame(
///     data: aacData,
///     timestamp: MediaTimestamp(seconds: 0.0),
///     duration: MediaTimestamp(seconds: 0.023),
///     isKeyframe: true,
///     codec: .aac
/// )
/// ```
public struct EncodedFrame: Sendable {

    /// Compressed frame data.
    public let data: Data

    /// Presentation timestamp of this frame.
    public let timestamp: MediaTimestamp

    /// Duration of this frame.
    public let duration: MediaTimestamp

    /// Whether this frame is a keyframe (sync point).
    public let isKeyframe: Bool

    /// Codec used to encode this frame.
    public let codec: EncodedCodec

    /// Approximate bitrate hint in bits per second. Nil if unknown.
    public let bitrateHint: Int?

    /// HDR metadata carried with this frame. Nil for SDR or audio.
    public let hdrMetadata: HDRMetadata?

    /// Audio channel layout for this frame. Nil for video or default stereo.
    public let channelLayout: AudioChannelLayout?

    /// Creates an encoded frame.
    ///
    /// - Parameters:
    ///   - data: The compressed frame data.
    ///   - timestamp: Presentation timestamp.
    ///   - duration: Duration of this frame.
    ///   - isKeyframe: Whether this is a keyframe.
    ///   - codec: The codec used.
    ///   - bitrateHint: Optional bitrate hint in bps.
    ///   - hdrMetadata: Optional HDR metadata.
    ///   - channelLayout: Optional audio channel layout.
    public init(
        data: Data,
        timestamp: MediaTimestamp,
        duration: MediaTimestamp,
        isKeyframe: Bool,
        codec: EncodedCodec,
        bitrateHint: Int? = nil,
        hdrMetadata: HDRMetadata? = nil,
        channelLayout: AudioChannelLayout? = nil
    ) {
        self.data = data
        self.timestamp = timestamp
        self.duration = duration
        self.isKeyframe = isKeyframe
        self.codec = codec
        self.bitrateHint = bitrateHint
        self.hdrMetadata = hdrMetadata
        self.channelLayout = channelLayout
    }
}

// MARK: - EncodedCodec

/// Codecs that a ``LiveEncoder`` can produce.
public enum EncodedCodec: String, Sendable, Codable, CaseIterable, Hashable {

    /// AAC (Advanced Audio Coding).
    case aac

    /// AC-3 (Dolby Digital).
    case ac3

    /// E-AC-3 (Dolby Digital Plus).
    case eac3

    /// Apple Lossless Audio Codec.
    case alac

    /// Free Lossless Audio Codec.
    case flac

    /// Opus.
    case opus

    /// H.264 / AVC.
    case h264

    /// H.265 / HEVC.
    case h265

    /// AV1.
    case av1

    /// Whether this codec produces audio frames.
    public var isAudio: Bool {
        switch self {
        case .aac, .ac3, .eac3, .alac, .flac, .opus:
            true
        case .h264, .h265, .av1:
            false
        }
    }

    /// Whether this codec produces video frames.
    public var isVideo: Bool {
        !isAudio
    }
}
