// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

extension LivePipelineConfiguration {

    // MARK: - Audio-Only Presets

    /// Podcast live streaming.
    ///
    /// - Audio: AAC 128 kbps, 48 kHz, stereo
    /// - Segments: 6s, MPEG-TS
    /// - Playlist: sliding window (5 segments)
    /// - Loudness: -16 LUFS (Apple/Spotify standard)
    /// - PROGRAM-DATE-TIME enabled
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-MEDIA-SEQUENCE:N
    /// #EXT-X-PROGRAM-DATE-TIME:...
    /// ```
    public static var podcastLive: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = false
        config.segmentDuration = 6.0
        config.containerFormat = .mpegts
        config.playlistType = .slidingWindow(windowSize: 5)
        config.targetLoudness = -16.0
        config.enableProgramDateTime = true
        config.programDateTimeInterval = 6.0
        return config
    }

    /// Web radio / music streaming.
    ///
    /// - Audio: AAC 256 kbps, 48 kHz, stereo (higher quality for music)
    /// - Segments: 4s, fMP4
    /// - Playlist: sliding window (8 segments)
    /// - Low-Latency HLS enabled (1s parts)
    /// - No loudness normalization (preserve dynamic range)
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:4
    /// #EXT-X-PART-INF:PART-TARGET=1.0
    /// #EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES
    /// ```
    public static var webradio: Self {
        var config = Self()
        config.audioBitrate = 256_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = false
        config.segmentDuration = 4.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 8)
        config.lowLatency = LowLatencyConfig(partTargetDuration: 1.0)
        return config
    }

    /// DJ mix / live music set.
    ///
    /// - Audio: AAC 320 kbps, 48 kHz, stereo (maximum AAC quality)
    /// - Segments: 4s, fMP4
    /// - Playlist: event (keep all segments for full set replay)
    /// - No loudness normalization
    /// - Recording enabled
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:4
    /// #EXT-X-PLAYLIST-TYPE:EVENT
    /// ```
    public static var djMix: Self {
        var config = Self()
        config.audioBitrate = 320_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = false
        config.segmentDuration = 4.0
        config.containerFormat = .fmp4
        config.playlistType = .event
        config.enableRecording = true
        config.recordingDirectory = "recordings"
        return config
    }

    /// Low-bandwidth audio streaming.
    ///
    /// - Audio: AAC 48 kbps, 22050 Hz, mono
    /// - Segments: 10s, MPEG-TS (longer segments for stability)
    /// - Playlist: sliding window (3 segments)
    /// - Target for voice-only content on poor connections
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:10
    /// #EXT-X-MEDIA-SEQUENCE:N
    /// ```
    public static var lowBandwidth: Self {
        var config = Self()
        config.audioBitrate = 48_000
        config.audioSampleRate = 22_050
        config.audioChannels = 1
        config.videoEnabled = false
        config.segmentDuration = 10.0
        config.containerFormat = .mpegts
        config.playlistType = .slidingWindow(windowSize: 3)
        return config
    }

    // MARK: - Video Presets

    /// Standard video live streaming (1080p).
    ///
    /// - Video: 1920×1080, 30fps, 4 Mbps
    /// - Audio: AAC 128 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: sliding window (5 segments)
    /// - Low-Latency HLS enabled (0.5s parts)
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-PART-INF:PART-TARGET=0.5
    /// #EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES
    /// ```
    public static var videoLive: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = true
        config.videoBitrate = 4_000_000
        config.videoWidth = 1920
        config.videoHeight = 1080
        config.videoFrameRate = 30.0
        config.segmentDuration = 6.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 5)
        config.lowLatency = LowLatencyConfig(partTargetDuration: 0.5)
        return config
    }

    /// Low-latency video streaming (720p).
    ///
    /// - Video: 1280×720, 30fps, 2 Mbps
    /// - Audio: AAC 128 kbps, 48 kHz, stereo
    /// - Segments: 4s, fMP4
    /// - Playlist: sliding window (5 segments)
    /// - Low-Latency HLS: 0.33s parts, preload hints, delta, blocking
    /// - Optimized for minimum glass-to-glass latency
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:4
    /// #EXT-X-PART-INF:PART-TARGET=0.33
    /// #EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES,CAN-SKIP-UNTIL=24.0
    /// #EXT-X-PRELOAD-HINT:TYPE=PART,...
    /// ```
    public static var lowLatencyVideo: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = true
        config.videoBitrate = 2_000_000
        config.videoWidth = 1280
        config.videoHeight = 720
        config.videoFrameRate = 30.0
        config.segmentDuration = 4.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 5)
        config.lowLatency = LowLatencyConfig(
            partTargetDuration: 0.33,
            enablePreloadHints: true,
            enableDeltaUpdates: true,
            enableBlockingReload: true
        )
        return config
    }

    /// Video simulcast (1080p + push to external platforms).
    ///
    /// - Video: 1920×1080, 30fps, 4 Mbps
    /// - Audio: AAC 128 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: sliding window (5 segments)
    /// - Caller adds RTMP destinations via ``LivePipeline/addDestination(_:id:)``
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-MEDIA-SEQUENCE:N
    /// ```
    public static var videoSimulcast: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = true
        config.videoBitrate = 4_000_000
        config.videoWidth = 1920
        config.videoHeight = 1080
        config.videoFrameRate = 30.0
        config.segmentDuration = 6.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 5)
        return config
    }

    // MARK: - Specialized Presets

    /// Apple Podcast live — strictly conformant to Apple HLS spec.
    ///
    /// - Audio: AAC-LC 128 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4 (Apple preferred format)
    /// - Playlist: sliding window (6 segments)
    /// - PROGRAM-DATE-TIME every segment
    /// - Loudness: -16 LUFS
    /// - Designed for Apple Podcasts live audio features
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-MEDIA-SEQUENCE:N
    /// #EXT-X-PROGRAM-DATE-TIME:...
    /// ```
    public static var applePodcastLive: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = false
        config.segmentDuration = 6.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 6)
        config.targetLoudness = -16.0
        config.enableProgramDateTime = true
        config.programDateTimeInterval = 6.0
        return config
    }

    /// Broadcast-grade streaming (EBU R 128 compliant).
    ///
    /// - Audio: AAC 192 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: sliding window (6 segments)
    /// - Loudness: -23 LUFS (EBU R 128 broadcast standard)
    /// - DVR enabled (2 hour window)
    /// - Recording enabled
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-MEDIA-SEQUENCE:N
    /// #EXT-X-PROGRAM-DATE-TIME:...
    /// ```
    public static var broadcast: Self {
        var config = Self()
        config.audioBitrate = 192_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = false
        config.segmentDuration = 6.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 6)
        config.targetLoudness = -23.0
        config.enableDVR = true
        config.dvrWindowDuration = 7200
        config.enableRecording = true
        config.recordingDirectory = "recordings"
        config.enableProgramDateTime = true
        config.programDateTimeInterval = 6.0
        return config
    }

    /// Event recording — keep everything, convert to VOD later.
    ///
    /// - Audio: AAC 128 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: event (no segment eviction)
    /// - Recording enabled
    /// - PROGRAM-DATE-TIME enabled for timeline accuracy
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-PLAYLIST-TYPE:EVENT
    /// #EXT-X-PROGRAM-DATE-TIME:...
    /// ```
    public static var eventRecording: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = false
        config.segmentDuration = 6.0
        config.containerFormat = .fmp4
        config.playlistType = .event
        config.enableRecording = true
        config.recordingDirectory = "recordings"
        config.enableProgramDateTime = true
        config.programDateTimeInterval = 6.0
        return config
    }
}
