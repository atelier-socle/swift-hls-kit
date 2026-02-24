// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Contract for media input to HLSKit.
///
/// Apps implement this protocol with AVAudioEngine, AVCaptureSession, etc.
/// HLSKit provides ``FileSource`` as a reference implementation.
///
/// The protocol is cross-platform — no CoreMedia dependency.
/// On Apple platforms, the app bridges CMSampleBuffer → ``RawMediaBuffer``.
/// On Linux, data comes from file I/O, network, or other sources.
public protocol MediaSource: Sendable {

    /// Type of media provided by this source.
    var mediaType: MediaSourceType { get }

    /// Description of the audio/video format.
    var formatDescription: MediaFormatDescription { get }

    /// Returns the next buffer of samples, or nil when the source is exhausted.
    ///
    /// For live sources, this method blocks (async) until data is available.
    /// For file sources, it reads the next chunk and returns nil at EOF.
    func nextSampleBuffer() async throws -> RawMediaBuffer?

    /// Whether this source has finished producing data.
    ///
    /// Always `false` for live sources. `true` for file sources after EOF.
    var isFinished: Bool { get async }
}

/// The type of media a source provides.
public enum MediaSourceType: String, Sendable, Codable, CaseIterable {

    /// Audio-only media.
    case audio

    /// Video-only media.
    case video

    /// Muxed audio and video.
    case audioVideo
}
