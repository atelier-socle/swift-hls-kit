// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

extension LivePipelineConfiguration {

    // MARK: - Extended Video Presets

    /// 4K video live streaming (2160p).
    ///
    /// - Video: 3840×2160, 30fps, 15 Mbps
    /// - Audio: AAC 192 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: sliding window (5 segments)
    /// - Low-Latency HLS: 0.5s parts
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-PART-INF:PART-TARGET=0.5
    /// #EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES
    /// ```
    public static var video4K: Self {
        var config = Self()
        config.audioBitrate = 192_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = true
        config.videoBitrate = 15_000_000
        config.videoWidth = 3840
        config.videoHeight = 2160
        config.videoFrameRate = 30.0
        config.segmentDuration = 6.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 5)
        config.lowLatency = LowLatencyConfig(partTargetDuration: 0.5)
        return config
    }

    /// 4K ultra-low-latency video streaming (2160p).
    ///
    /// - Video: 3840×2160, 30fps, 15 Mbps
    /// - Audio: AAC 192 kbps, 48 kHz, stereo
    /// - Segments: 4s, fMP4
    /// - Playlist: sliding window (5 segments)
    /// - Low-Latency HLS: 0.33s parts, preload hints, delta, blocking
    /// - Optimized for minimum glass-to-glass latency at 4K
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:4
    /// #EXT-X-PART-INF:PART-TARGET=0.33
    /// #EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES,CAN-SKIP-UNTIL=24.0
    /// #EXT-X-PRELOAD-HINT:TYPE=PART,...
    /// ```
    public static var video4KLowLatency: Self {
        var config = Self()
        config.audioBitrate = 192_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = true
        config.videoBitrate = 15_000_000
        config.videoWidth = 3840
        config.videoHeight = 2160
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

    /// Podcast video (filmed podcast, interview style).
    ///
    /// - Video: 1280×720, 30fps, 1.5 Mbps (talking heads don't need high bitrate)
    /// - Audio: AAC 128 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: sliding window (5 segments)
    /// - Loudness: -16 LUFS (podcast standard)
    /// - PROGRAM-DATE-TIME enabled
    /// - Recording enabled
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-MEDIA-SEQUENCE:N
    /// #EXT-X-PROGRAM-DATE-TIME:...
    /// ```
    public static var podcastVideo: Self {
        var config = Self()
        config.audioBitrate = 128_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = true
        config.videoBitrate = 1_500_000
        config.videoWidth = 1280
        config.videoHeight = 720
        config.videoFrameRate = 30.0
        config.segmentDuration = 6.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 5)
        config.targetLoudness = -16.0
        config.enableRecording = true
        config.recordingDirectory = "recordings"
        config.enableProgramDateTime = true
        config.programDateTimeInterval = 6.0
        return config
    }

    /// Video live with DVR/time-shift (sports, conferences).
    ///
    /// - Video: 1920×1080, 30fps, 4 Mbps
    /// - Audio: AAC 128 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: sliding window (5 segments)
    /// - DVR enabled: 4 hour window
    /// - Low-Latency HLS: 0.5s parts
    /// - Recording enabled
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-PART-INF:PART-TARGET=0.5
    /// #EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES
    /// ```
    public static var videoLiveWithDVR: Self {
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
        config.enableDVR = true
        config.dvrWindowDuration = 14400
        config.lowLatency = LowLatencyConfig(partTargetDuration: 0.5)
        config.enableRecording = true
        config.recordingDirectory = "recordings"
        return config
    }

    // MARK: - Extended Audio Presets

    /// DJ mix with DVR for re-listen during the set.
    ///
    /// - Audio: AAC 320 kbps, 48 kHz, stereo
    /// - Segments: 4s, fMP4
    /// - Playlist: sliding window (10 segments)
    /// - DVR enabled: 6 hour window (full festival set)
    /// - Recording enabled
    /// - No loudness normalization (preserve dynamic range)
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:4
    /// #EXT-X-MEDIA-SEQUENCE:N
    /// ```
    public static var djMixWithDVR: Self {
        var config = Self()
        config.audioBitrate = 320_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = false
        config.segmentDuration = 4.0
        config.containerFormat = .fmp4
        config.playlistType = .slidingWindow(windowSize: 10)
        config.enableDVR = true
        config.dvrWindowDuration = 21600
        config.enableRecording = true
        config.recordingDirectory = "recordings"
        return config
    }

    // MARK: - Extended Specialized Presets

    /// Conference/webinar stream.
    ///
    /// - Video: 1280×720, 15fps, 1 Mbps (slides/screen share need less FPS)
    /// - Audio: AAC 96 kbps, 48 kHz, stereo
    /// - Segments: 6s, fMP4
    /// - Playlist: event (keep all segments for replay)
    /// - Recording enabled
    /// - PROGRAM-DATE-TIME enabled
    ///
    /// HLS tags generated:
    /// ```
    /// #EXT-X-TARGETDURATION:6
    /// #EXT-X-PLAYLIST-TYPE:EVENT
    /// #EXT-X-PROGRAM-DATE-TIME:...
    /// ```
    public static var conferenceStream: Self {
        var config = Self()
        config.audioBitrate = 96_000
        config.audioSampleRate = 48_000
        config.audioChannels = 2
        config.videoEnabled = true
        config.videoBitrate = 1_000_000
        config.videoWidth = 1280
        config.videoHeight = 720
        config.videoFrameRate = 15.0
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
