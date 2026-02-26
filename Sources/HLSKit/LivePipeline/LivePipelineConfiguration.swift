// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - LivePipelineConfiguration

/// Comprehensive configuration for a LivePipeline.
///
/// Assembles settings for all pipeline stages:
/// encoding, segmentation, playlist, push, recording, metadata, and audio processing.
///
/// Usage:
/// ```swift
/// var config = LivePipelineConfiguration()
/// config.segmentDuration = 6.0
/// config.playlistType = .slidingWindow(windowSize: 5)
/// config.containerFormat = .fmp4
/// config.destinations = [.http(url: "https://cdn.example.com")]
/// ```
public struct LivePipelineConfiguration: Sendable, Equatable {

    // MARK: - Encoding

    /// Audio bitrate in bits per second. Default: 128,000 (128 kbps).
    public var audioBitrate: Int

    /// Audio sample rate in Hz. Default: 48,000.
    public var audioSampleRate: Int

    /// Number of audio channels. Default: 2 (stereo).
    public var audioChannels: Int

    /// Whether video encoding is enabled. Default: false (audio-only).
    public var videoEnabled: Bool

    /// Video bitrate in bits per second. Only used if ``videoEnabled``. Default: 2,000,000.
    public var videoBitrate: Int

    /// Video width in pixels. Default: 1920.
    public var videoWidth: Int

    /// Video height in pixels. Default: 1080.
    public var videoHeight: Int

    /// Video frame rate in frames per second. Default: 30.0.
    public var videoFrameRate: Double

    // MARK: - Segmentation

    /// Target segment duration in seconds. Default: 6.0.
    public var segmentDuration: TimeInterval

    /// Container format for segments. Default: ``SegmentContainerFormat/fmp4``.
    public var containerFormat: SegmentContainerFormat

    // MARK: - Playlist

    /// Playlist type and configuration. Default: sliding window with 5 segments.
    public var playlistType: PlaylistTypeConfig

    /// Enable DVR (time-shift) buffer. Default: false.
    public var enableDVR: Bool

    /// DVR window duration in seconds. Default: 7200 (2 hours).
    public var dvrWindowDuration: TimeInterval

    // MARK: - Low-Latency HLS

    /// Low-Latency HLS configuration. nil means disabled. Default: nil.
    public var lowLatency: LowLatencyConfig?

    // MARK: - Push Destinations

    /// Push destinations for segments. Default: empty (local only).
    public var destinations: [PushDestinationConfig]

    // MARK: - Recording

    /// Enable simultaneous recording. Default: false.
    public var enableRecording: Bool

    /// Recording output directory. Required if ``enableRecording`` is true.
    public var recordingDirectory: String?

    // MARK: - Metadata

    /// Insert EXT-X-PROGRAM-DATE-TIME tags. Default: true.
    public var enableProgramDateTime: Bool

    /// PROGRAM-DATE-TIME insertion interval in seconds. Default: 6.0.
    public var programDateTimeInterval: TimeInterval

    // MARK: - Audio Processing

    /// Target loudness in LUFS. nil disables normalization. Default: nil.
    public var targetLoudness: Float?

    /// Audio processing settings for metering, normalization, and silence detection.
    public var audioProcessing: AudioProcessingSettings?

    // MARK: - Spatial Audio (Phase 19)

    /// Spatial audio configuration (Atmos, AC-3, E-AC-3, multichannel).
    /// Nil for standard stereo.
    public var spatialAudio: SpatialAudioConfig?

    /// Hi-Res audio configuration (96/192kHz, 24/32-bit, ALAC/FLAC).
    /// Nil for standard quality.
    public var hiResAudio: HiResAudioConfig?

    // MARK: - HDR & Video (Phase 20)

    /// HDR video configuration (HDR10, HDR10+, Dolby Vision, HLG).
    /// Nil for SDR content.
    public var hdr: HDRConfig?

    /// Resolution preset for video output.
    /// Nil uses the default from the quality preset.
    public var resolution: ResolutionPreset?

    // MARK: - DRM (Phase 21)

    /// DRM pipeline configuration (FairPlay, key rotation, CENC).
    /// Nil for unencrypted streams.
    public var drm: LiveDRMPipelineConfig?

    // MARK: - Accessibility (Phase 22)

    /// Closed caption configuration.
    /// Nil for no captions.
    public var closedCaptions: ClosedCaptionConfig?

    /// Audio description tracks.
    /// Nil for no audio descriptions.
    public var audioDescriptions: [AudioDescriptionConfig]?

    /// Whether to enable subtitle support (WebVTT).
    /// The actual subtitle content is added at runtime via LiveWebVTTWriter.
    public var subtitlesEnabled: Bool

    // MARK: - Resilience (Phase 22)

    /// Redundant stream configuration for failover.
    /// Nil for single-origin streaming.
    public var redundancy: RedundantStreamConfig?

    /// Content steering configuration for CDN switching.
    /// Nil for no steering.
    public var contentSteering: ContentSteeringConfig?

    /// Session data entries for master playlist metadata.
    public var sessionData: SessionDataConfig?

    // MARK: - Init

    /// Creates a new configuration with default values.
    public init() {
        self.audioBitrate = 128_000
        self.audioSampleRate = 48_000
        self.audioChannels = 2
        self.videoEnabled = false
        self.videoBitrate = 2_000_000
        self.videoWidth = 1920
        self.videoHeight = 1080
        self.videoFrameRate = 30.0
        self.segmentDuration = 6.0
        self.containerFormat = .fmp4
        self.playlistType = .slidingWindow(windowSize: 5)
        self.enableDVR = false
        self.dvrWindowDuration = 7200
        self.lowLatency = nil
        self.destinations = []
        self.enableRecording = false
        self.recordingDirectory = nil
        self.enableProgramDateTime = true
        self.programDateTimeInterval = 6.0
        self.targetLoudness = nil
        self.audioProcessing = nil
        self.spatialAudio = nil
        self.hiResAudio = nil
        self.hdr = nil
        self.resolution = nil
        self.drm = nil
        self.closedCaptions = nil
        self.audioDescriptions = nil
        self.subtitlesEnabled = false
        self.redundancy = nil
        self.contentSteering = nil
        self.sessionData = nil
    }

    // MARK: - Validation

    /// Validates the configuration for consistency.
    ///
    /// - Returns: nil if the configuration is valid,
    ///   or a description of the first validation error found.
    public func validate() -> String? {
        if let error = validateEncoding() { return error }
        if let error = validateVideo() { return error }
        if let error = validateFeatures() { return error }
        return validateDestinations()
    }

    private func validateEncoding() -> String? {
        if segmentDuration <= 0 {
            return "segmentDuration must be greater than 0"
        }
        if audioBitrate <= 0 {
            return "audioBitrate must be greater than 0"
        }
        if audioSampleRate <= 0 {
            return "audioSampleRate must be greater than 0"
        }
        if audioChannels <= 0 {
            return "audioChannels must be greater than 0"
        }
        return nil
    }

    private func validateVideo() -> String? {
        guard videoEnabled else { return nil }
        if videoBitrate <= 0 {
            return "videoBitrate must be greater than 0 when video is enabled"
        }
        if videoWidth <= 0 {
            return "videoWidth must be greater than 0 when video is enabled"
        }
        if videoHeight <= 0 {
            return "videoHeight must be greater than 0 when video is enabled"
        }
        if videoFrameRate <= 0 {
            return "videoFrameRate must be greater than 0 when video is enabled"
        }
        return nil
    }

    private func validateFeatures() -> String? {
        if enableRecording, recordingDirectory == nil {
            return "recordingDirectory is required when recording is enabled"
        }
        if enableDVR {
            if case .event = playlistType {
                return "DVR requires slidingWindow playlist type, not event"
            }
        }
        if let ll = lowLatency {
            if ll.partTargetDuration >= segmentDuration {
                return "lowLatency partTargetDuration must be less than segmentDuration"
            }
        }
        return nil
    }

    private func validateDestinations() -> String? {
        for destination in destinations {
            if case let .http(url, _) = destination, url.isEmpty {
                return "HTTP destination URL must not be empty"
            }
            if case let .local(directory) = destination, directory.isEmpty {
                return "Local destination directory must not be empty"
            }
        }
        return nil
    }
}

// MARK: - SegmentContainerFormat

/// Container format for HLS segments.
public enum SegmentContainerFormat: String, Sendable, Equatable, CaseIterable {
    /// Fragmented MP4 (CMAF-compatible).
    case fmp4
    /// MPEG Transport Stream.
    case mpegts
    /// Common Media Application Format.
    case cmaf
}

// MARK: - PlaylistTypeConfig

/// Playlist type configuration for the pipeline.
public enum PlaylistTypeConfig: Sendable, Equatable {
    /// Sliding window playlist with a maximum number of segments.
    case slidingWindow(windowSize: Int)
    /// Event playlist that never removes segments.
    case event
}

// MARK: - LowLatencyConfig

/// Low-Latency HLS configuration.
public struct LowLatencyConfig: Sendable, Equatable {
    /// Part target duration in seconds. Default: 0.5.
    public var partTargetDuration: TimeInterval

    /// Enable preload hints. Default: true.
    public var enablePreloadHints: Bool

    /// Enable delta updates. Default: true.
    public var enableDeltaUpdates: Bool

    /// Enable blocking playlist reload. Default: true.
    public var enableBlockingReload: Bool

    /// Creates a new Low-Latency HLS configuration with defaults.
    public init(
        partTargetDuration: TimeInterval = 0.5,
        enablePreloadHints: Bool = true,
        enableDeltaUpdates: Bool = true,
        enableBlockingReload: Bool = true
    ) {
        self.partTargetDuration = partTargetDuration
        self.enablePreloadHints = enablePreloadHints
        self.enableDeltaUpdates = enableDeltaUpdates
        self.enableBlockingReload = enableBlockingReload
    }
}

// MARK: - PushDestinationConfig

/// Push destination configuration for segment delivery.
public enum PushDestinationConfig: Sendable, Equatable {
    /// HTTP push destination with optional headers.
    case http(url: String, headers: [String: String] = [:])
    /// Local filesystem directory.
    case local(directory: String)
}

// MARK: - AudioProcessingSettings

/// Audio processing settings for the live pipeline.
///
/// Configures loudness normalization, silence detection, and metering.
/// Use presets for common scenarios: ``podcast``, ``broadcast``, ``music``.
public struct AudioProcessingSettings: Sendable, Equatable {

    /// Target loudness in LUFS. nil disables normalization.
    public var targetLoudness: Double?

    /// Enable silence detection.
    public var silenceDetection: Bool

    /// Silence threshold in dBFS.
    public var silenceThreshold: Double

    /// Minimum silence duration to trigger detection.
    public var silenceMinDuration: TimeInterval

    /// Enable peak/RMS level metering.
    public var levelMetering: Bool

    /// Enable integrated loudness metering.
    public var loudnessMetering: Bool

    /// Creates audio processing settings.
    ///
    /// - Parameters:
    ///   - targetLoudness: Target loudness in LUFS. nil disables normalization.
    ///   - silenceDetection: Enable silence detection. Default: false.
    ///   - silenceThreshold: Silence threshold in dBFS. Default: -50.0.
    ///   - silenceMinDuration: Minimum silence duration. Default: 3.0.
    ///   - levelMetering: Enable level metering. Default: false.
    ///   - loudnessMetering: Enable loudness metering. Default: false.
    public init(
        targetLoudness: Double? = nil,
        silenceDetection: Bool = false,
        silenceThreshold: Double = -50.0,
        silenceMinDuration: TimeInterval = 3.0,
        levelMetering: Bool = false,
        loudnessMetering: Bool = false
    ) {
        self.targetLoudness = targetLoudness
        self.silenceDetection = silenceDetection
        self.silenceThreshold = silenceThreshold
        self.silenceMinDuration = silenceMinDuration
        self.levelMetering = levelMetering
        self.loudnessMetering = loudnessMetering
    }

    /// Podcast: -16 LUFS, silence detection, loudness metering.
    public static var podcast: Self {
        Self(
            targetLoudness: -16.0,
            silenceDetection: true,
            silenceThreshold: -50.0,
            silenceMinDuration: 3.0,
            levelMetering: false,
            loudnessMetering: true
        )
    }

    /// Broadcast: -23 LUFS (EBU R 128), all meters active.
    public static var broadcast: Self {
        Self(
            targetLoudness: -23.0,
            silenceDetection: true,
            silenceThreshold: -50.0,
            silenceMinDuration: 5.0,
            levelMetering: true,
            loudnessMetering: true
        )
    }

    /// DJ/music: level metering only, no normalization.
    public static var music: Self {
        Self(
            targetLoudness: nil,
            silenceDetection: false,
            silenceThreshold: -50.0,
            silenceMinDuration: 3.0,
            levelMetering: true,
            loudnessMetering: false
        )
    }
}
