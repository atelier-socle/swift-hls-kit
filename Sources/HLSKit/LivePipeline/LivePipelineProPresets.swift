// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

extension LivePipelineConfiguration {

    // MARK: - Spatial Audio Presets (Phase 19)

    /// Dolby Atmos 5.1 live with stereo AAC fallback.
    ///
    /// - Audio: AAC 128 kbps + E-AC-3 384 kbps spatial
    /// - Spatial: Dolby Atmos 5.1 with stereo fallback
    /// - Segments: 6s, fMP4
    public static var spatialAudioLive: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.spatialAudio = .atmos5_1
        return config
    }

    /// Hi-Res lossless audio live stream.
    ///
    /// - Audio: 256 kbps AAC + 96kHz/24-bit ALAC lossless
    /// - Segments: 6s, fMP4
    public static var hiResLive: Self {
        var config = Self()
        config.audioBitrate = 256_000
        config.hiResAudio = .studioHiRes
        return config
    }

    // MARK: - HDR Video Presets (Phase 20)

    /// HDR10 live video (1080p) with SDR fallback.
    ///
    /// - Video: 1920x1080, HDR10, HEVC Main10
    /// - Audio: AAC 128 kbps
    /// - Segments: 6s, fMP4
    public static var videoHDR: Self {
        var config = Self()
        config.videoEnabled = true
        config.hdr = .hdr10Default
        config.resolution = .fullHD1080p
        return config
    }

    /// Dolby Vision Profile 8 live video with HDR10 base layer.
    ///
    /// - Video: 3840x2160, Dolby Vision Profile 8, HEVC
    /// - Audio: AAC 128 kbps
    /// - Segments: 6s, fMP4
    public static var videoDolbyVision: Self {
        var config = Self()
        config.videoEnabled = true
        config.hdr = .dolbyVisionProfile8
        config.resolution = .uhd4K
        return config
    }

    /// 8K HEVC live video.
    ///
    /// - Video: 7680x4320, HEVC Main10
    /// - Audio: AAC 128 kbps
    /// - Segments: 6s, fMP4
    public static var video8K: Self {
        var config = Self()
        config.videoEnabled = true
        config.resolution = .uhd8K
        return config
    }

    // MARK: - DRM Presets (Phase 21)

    /// FairPlay-protected live stream with key rotation.
    ///
    /// - DRM: FairPlay CBCS, rotation every 10 segments
    /// - Audio: AAC 128 kbps
    /// - Segments: 6s, fMP4
    public static var drmProtectedLive: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.drm = .fairPlayModern
        return config
    }

    /// Multi-DRM live stream (FairPlay + Widevine + PlayReady).
    ///
    /// - DRM: FairPlay + Widevine + PlayReady, rotation every 10 segments
    /// - Audio: AAC 128 kbps
    /// - Segments: 6s, fMP4
    public static var multiDRMLive: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.drm = .multiDRM
        return config
    }

    // MARK: - Accessibility Presets (Phase 22)

    /// Accessible live stream with CC + audio description.
    ///
    /// - Accessibility: CEA-708 English/Spanish captions + English audio description
    /// - Subtitles: WebVTT enabled
    /// - Audio: AAC 128 kbps
    /// - Segments: 6s, fMP4
    public static var accessibleLive: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.closedCaptions = .englishSpanish708
        config.audioDescriptions = [.english]
        config.subtitlesEnabled = true
        return config
    }

    // MARK: - Combined Pro Presets

    /// Broadcast-grade live: DRM + CC + spatial audio + HDR + DVR + recording.
    ///
    /// The ultimate preset combining all professional features:
    /// - Audio: 256 kbps AAC + Dolby Atmos 5.1
    /// - Video: 3840x2160, Dolby Vision Profile 8
    /// - DRM: FairPlay CBCS with key rotation
    /// - Accessibility: CEA-708 broadcast (EN/ES/FR) + audio descriptions
    /// - DVR: disabled (use with sliding window)
    /// - Recording: enabled
    public static var broadcastPro: Self {
        var config = Self()
        // Audio
        config.audioBitrate = 256_000
        config.spatialAudio = .atmos5_1
        // Video
        config.videoEnabled = true
        config.hdr = .dolbyVisionProfile8
        config.resolution = .uhd4K
        // DRM
        config.drm = .fairPlayModern
        // Accessibility
        config.closedCaptions = .broadcast708
        config.audioDescriptions = [.english, .spanish, .french]
        config.subtitlesEnabled = true
        // Recording
        config.enableRecording = true
        config.recordingDirectory = "recordings"
        return config
    }
}
