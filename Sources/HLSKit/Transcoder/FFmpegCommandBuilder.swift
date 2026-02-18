// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Builds ffmpeg command-line arguments from HLSKit configuration.
///
/// Translates ``QualityPreset`` and ``TranscodingConfig`` into the
/// correct ffmpeg arguments for transcoding. Pure argument generation
/// with no process execution — easy to test without ffmpeg installed.
///
/// ```swift
/// let builder = FFmpegCommandBuilder()
/// let args = builder.buildTranscodeArguments(
///     input: "/path/to/source.mp4",
///     output: "/path/to/output.mp4",
///     preset: .p720,
///     config: TranscodingConfig()
/// )
/// // ["-i", "/path/to/source.mp4", "-c:v", "libx264", ...]
/// ```
///
/// - SeeAlso: ``FFmpegTranscoder``, ``QualityPreset``
struct FFmpegCommandBuilder: Sendable {

    // Uses synthesized memberwise initializer.

    /// Build ffmpeg arguments for single-quality transcoding.
    ///
    /// - Parameters:
    ///   - input: Source file path.
    ///   - output: Output file path.
    ///   - preset: Quality preset.
    ///   - config: Transcoding configuration.
    /// - Returns: Array of ffmpeg arguments (without the binary name).
    func buildTranscodeArguments(
        input: String,
        output: String,
        preset: QualityPreset,
        config: TranscodingConfig
    ) -> [String] {
        var args: [String] = []

        args += ["-i", input]
        args += buildVideoArguments(preset: preset, config: config)
        args += buildAudioArguments(preset: preset, config: config)
        args += ["-movflags", "+faststart"]
        args += ["-y"]
        args += [output]

        return args
    }

    /// Build ffprobe arguments for source analysis.
    ///
    /// - Parameter input: Source file path.
    /// - Returns: Array of ffprobe arguments (without the binary name).
    func buildProbeArguments(input: String) -> [String] {
        [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            input
        ]
    }
}

// MARK: - Video Arguments

extension FFmpegCommandBuilder {

    private func buildVideoArguments(
        preset: QualityPreset,
        config: TranscodingConfig
    ) -> [String] {
        guard let resolution = preset.resolution else {
            return ["-vn"]
        }

        var args: [String] = []

        switch config.videoCodec {
        case .h264:
            args += ["-c:v", "libx264"]
        case .h265:
            args += ["-c:v", "libx265"]
            args += ["-tag:v", "hvc1"]
        case .vp9:
            args += ["-c:v", "libvpx-vp9"]
        case .av1:
            args += ["-c:v", "libsvtav1"]
        }

        if let bitrate = preset.videoBitrate {
            args += ["-b:v", "\(bitrate / 1000)k"]
        }

        if let maxBitrate = preset.maxVideoBitrate {
            args += ["-maxrate", "\(maxBitrate / 1000)k"]
            args += ["-bufsize", "\(maxBitrate * 2 / 1000)k"]
        }

        args += [
            "-vf", "scale=\(resolution.width):\(resolution.height)"
        ]

        if let profile = preset.videoProfile {
            args += ["-profile:v", ffmpegProfileName(profile)]
        }

        if let level = preset.videoLevel {
            args += ["-level", level]
        }

        let fps = preset.frameRate ?? 30.0
        let gopSize = Int(preset.keyFrameInterval * fps)
        args += ["-g", "\(gopSize)", "-keyint_min", "\(gopSize)"]

        return args
    }

    private func ffmpegProfileName(
        _ profile: VideoProfile
    ) -> String {
        switch profile {
        case .baseline:
            return "baseline"
        case .main:
            return "main"
        case .high:
            return "high"
        case .mainHEVC:
            return "main"
        case .main10HEVC:
            return "main10"
        }
    }
}

// MARK: - Audio Arguments

extension FFmpegCommandBuilder {

    private func buildAudioArguments(
        preset: QualityPreset,
        config: TranscodingConfig
    ) -> [String] {
        guard config.includeAudio else {
            return ["-an"]
        }

        if config.audioPassthrough {
            return ["-c:a", "copy"]
        }

        var args: [String] = []

        switch config.audioCodec {
        case .aac:
            args += ["-c:a", "aac"]
        case .heAAC:
            args += ["-c:a", "libfdk_aac", "-profile:a", "aac_he"]
        case .heAACv2:
            args += [
                "-c:a", "libfdk_aac", "-profile:a", "aac_he_v2"
            ]
        case .flac:
            args += ["-c:a", "flac"]
        case .opus:
            args += ["-c:a", "libopus"]
        }

        args += ["-b:a", "\(preset.audioBitrate / 1000)k"]
        args += ["-ar", "\(preset.audioSampleRate)"]
        args += ["-ac", "\(preset.audioChannels)"]

        return args
    }
}
