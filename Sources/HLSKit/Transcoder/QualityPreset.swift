// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Pre-defined quality levels for HLS adaptive bitrate streaming.
///
/// Each preset defines resolution, bitrate, codec settings, and audio
/// parameters that follow Apple's HLS Authoring Specification.
///
/// ## Built-in Presets
/// - `.p360` — 640x360, ideal for cellular connections
/// - `.p480` — 854x480, baseline quality
/// - `.p720` — 1280x720, standard HD
/// - `.p1080` — 1920x1080, full HD
/// - `.p2160` — 3840x2160, 4K UHD
/// - `.audioOnly` — Audio-only variant
///
/// ## Custom Presets
/// ```swift
/// let custom = QualityPreset(
///     name: "mobile-low",
///     resolution: Resolution(width: 426, height: 240),
///     videoBitrate: 400_000,
///     audioBitrate: 64_000
/// )
/// ```
///
/// - SeeAlso: Apple HLS Authoring Specification, Section 2
public struct QualityPreset: Sendable, Hashable, Codable {

    /// Human-readable name (e.g., "720p", "1080p").
    public let name: String

    /// Output resolution (nil for audio-only).
    public let resolution: Resolution?

    /// Target video bitrate in bits per second (nil for audio-only).
    public let videoBitrate: Int?

    /// Maximum video bitrate (for VBR, typically 1.5x target).
    public let maxVideoBitrate: Int?

    /// Target audio bitrate in bits per second.
    public let audioBitrate: Int

    /// Audio sample rate in Hz.
    public let audioSampleRate: Int

    /// Audio channel count.
    public let audioChannels: Int

    /// Video codec profile (for H.264: baseline, main, high).
    public let videoProfile: VideoProfile?

    /// Video codec level (for H.264: 3.0, 3.1, 4.0, 4.1, etc.).
    public let videoLevel: String?

    /// Frame rate (nil = same as source).
    public let frameRate: Double?

    /// Key frame interval in seconds (GOP size).
    /// Default: 2.0 (Apple recommendation for HLS).
    public let keyFrameInterval: Double

    /// Creates a quality preset.
    ///
    /// - Parameters:
    ///   - name: Human-readable name.
    ///   - resolution: Output resolution (nil for audio-only).
    ///   - videoBitrate: Target video bitrate in bps.
    ///   - maxVideoBitrate: Maximum video bitrate.
    ///   - audioBitrate: Target audio bitrate in bps.
    ///   - audioSampleRate: Audio sample rate in Hz.
    ///   - audioChannels: Audio channel count.
    ///   - videoProfile: Video codec profile.
    ///   - videoLevel: Video codec level string.
    ///   - frameRate: Frame rate (nil = source).
    ///   - keyFrameInterval: Key frame interval in seconds.
    public init(
        name: String,
        resolution: Resolution?,
        videoBitrate: Int?,
        maxVideoBitrate: Int? = nil,
        audioBitrate: Int = 128_000,
        audioSampleRate: Int = 44_100,
        audioChannels: Int = 2,
        videoProfile: VideoProfile? = .high,
        videoLevel: String? = nil,
        frameRate: Double? = nil,
        keyFrameInterval: Double = 2.0
    ) {
        self.name = name
        self.resolution = resolution
        self.videoBitrate = videoBitrate
        self.maxVideoBitrate = maxVideoBitrate
        self.audioBitrate = audioBitrate
        self.audioSampleRate = audioSampleRate
        self.audioChannels = audioChannels
        self.videoProfile = videoProfile
        self.videoLevel = videoLevel
        self.frameRate = frameRate
        self.keyFrameInterval = keyFrameInterval
    }
}

// MARK: - Built-in Presets

extension QualityPreset {

    /// 640x360 @ 800 kbps — cellular/low bandwidth.
    public static let p360 = QualityPreset(
        name: "360p",
        resolution: .p360,
        videoBitrate: 800_000,
        maxVideoBitrate: 1_200_000,
        audioBitrate: 64_000,
        videoProfile: .baseline,
        videoLevel: "3.0"
    )

    /// 854x480 @ 1.4 Mbps — baseline quality.
    public static let p480 = QualityPreset(
        name: "480p",
        resolution: .p480,
        videoBitrate: 1_400_000,
        maxVideoBitrate: 2_100_000,
        audioBitrate: 96_000,
        videoProfile: .main,
        videoLevel: "3.1"
    )

    /// 1280x720 @ 2.8 Mbps — standard HD.
    public static let p720 = QualityPreset(
        name: "720p",
        resolution: .p720,
        videoBitrate: 2_800_000,
        maxVideoBitrate: 4_200_000,
        audioBitrate: 128_000,
        videoProfile: .high,
        videoLevel: "3.1"
    )

    /// 1920x1080 @ 5 Mbps — full HD.
    public static let p1080 = QualityPreset(
        name: "1080p",
        resolution: .p1080,
        videoBitrate: 5_000_000,
        maxVideoBitrate: 7_500_000,
        audioBitrate: 128_000,
        videoProfile: .high,
        videoLevel: "4.0"
    )

    /// 3840x2160 @ 14 Mbps — 4K UHD.
    public static let p2160 = QualityPreset(
        name: "2160p",
        resolution: .p2160,
        videoBitrate: 14_000_000,
        maxVideoBitrate: 21_000_000,
        audioBitrate: 192_000,
        videoProfile: .high,
        videoLevel: "5.1"
    )

    /// Audio-only variant (for podcast audio HLS).
    public static let audioOnly = QualityPreset(
        name: "audio",
        resolution: nil,
        videoBitrate: nil,
        audioBitrate: 128_000,
        audioSampleRate: 44_100,
        audioChannels: 2,
        videoProfile: nil
    )

    /// Standard resolution ladder for adaptive streaming.
    public static let standardLadder: [QualityPreset] = [
        .p360, .p480, .p720, .p1080
    ]

    /// Full resolution ladder including 4K.
    public static let fullLadder: [QualityPreset] = [
        .p360, .p480, .p720, .p1080, .p2160
    ]
}

// MARK: - Computed Properties

extension QualityPreset {

    /// Total bandwidth (video + audio) — used for
    /// EXT-X-STREAM-INF BANDWIDTH.
    public var totalBandwidth: Int {
        (videoBitrate ?? 0) + audioBitrate
    }

    /// Whether this is an audio-only preset.
    public var isAudioOnly: Bool {
        resolution == nil && videoBitrate == nil
    }

    /// CODECS string for the HLS playlist
    /// (e.g., "avc1.640029,mp4a.40.2").
    ///
    /// - Parameter videoCodec: The video codec used.
    /// - Returns: A codec string suitable for HLS playlists.
    public func codecsString(
        videoCodec: OutputVideoCodec = .h264
    ) -> String {
        var parts: [String] = []
        if !isAudioOnly {
            parts.append(
                videoCodecString(videoCodec: videoCodec)
            )
        }
        parts.append(audioCodecString())
        return parts.joined(separator: ",")
    }
}

// MARK: - Codec String Helpers

extension QualityPreset {

    private func videoCodecString(
        videoCodec: OutputVideoCodec
    ) -> String {
        switch videoCodec {
        case .h264:
            return h264CodecString()
        case .h265:
            return "hvc1.1.6.L120.90"
        case .vp9:
            return "vp09.00.10.08"
        case .av1:
            return "av01.0.01M.08"
        }
    }

    private func h264CodecString() -> String {
        let profileHex: String
        switch videoProfile {
        case .baseline:
            profileHex = "42"
        case .main:
            profileHex = "4D"
        case .high, .none:
            profileHex = "64"
        case .mainHEVC, .main10HEVC:
            profileHex = "64"
        }
        let constraintHex = "00"
        let levelHex: String
        if let level = videoLevel {
            let numericLevel = (Double(level) ?? 3.0) * 10
            levelHex = String(
                format: "%02X", Int(numericLevel)
            )
        } else {
            levelHex = "1E"
        }
        return "avc1.\(profileHex)\(constraintHex)\(levelHex)"
    }

    private func audioCodecString() -> String {
        "mp4a.40.2"
    }
}
