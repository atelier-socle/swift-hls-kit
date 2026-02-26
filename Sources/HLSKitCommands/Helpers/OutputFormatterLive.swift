// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import HLSKit

// MARK: - Live Pipeline Formatting

extension OutputFormatter {

    /// Format a live pipeline configuration summary.
    public func formatLiveConfig(
        _ config: LivePipelineConfiguration,
        outputDirectory: String
    ) -> String {
        switch self {
        case .text:
            return formatLiveConfigText(
                config, outputDirectory: outputDirectory
            )
        case .json:
            return formatLiveConfigJSON(
                config, outputDirectory: outputDirectory
            )
        }
    }

    /// Format live pipeline statistics.
    public func formatLiveStats(
        _ stats: LivePipelineStatistics
    ) -> String {
        switch self {
        case .text:
            return formatLiveStatsText(stats)
        case .json:
            return formatLiveStatsJSON(stats)
        }
    }

    /// Format a table of all available presets.
    public func formatPresetList() -> String {
        switch self {
        case .text:
            return formatPresetListText()
        case .json:
            return formatPresetListJSON()
        }
    }
}

// MARK: - Live Config Text

extension OutputFormatter {

    private func formatLiveConfigText(
        _ config: LivePipelineConfiguration,
        outputDirectory: String
    ) -> String {
        var lines: [String] = [
            ColorOutput.bold("Live Pipeline Configuration")
        ]
        let pairs = buildConfigPairs(
            config, outputDirectory: outputDirectory
        )
        lines.append(formatKeyValues(pairs))
        return lines.joined(separator: "\n")
    }

    private func buildConfigPairs(
        _ config: LivePipelineConfiguration,
        outputDirectory: String
    ) -> [(String, String)] {
        let channels =
            config.audioChannels == 1 ? "mono" : "stereo"
        let audio =
            "\(config.audioBitrate / 1000) kbps"
            + ", \(config.audioSampleRate) Hz"
            + ", \(channels)"
        var pairs: [(String, String)] = [
            ("Output:", outputDirectory),
            ("Audio:", audio)
        ]
        if config.videoEnabled {
            let video =
                "\(config.videoWidth)x\(config.videoHeight)"
                + " @ \(Int(config.videoFrameRate))fps"
                + ", \(config.videoBitrate / 1000) kbps"
            pairs.append(("Video:", video))
        }
        pairs.append(
            (
                "Segment:",
                String(format: "%.1fs", config.segmentDuration)
                    + ", \(config.containerFormat.rawValue)"
            ))
        let playlist: String
        switch config.playlistType {
        case let .slidingWindow(size):
            playlist = "sliding window (\(size))"
        case .event:
            playlist = "event"
        }
        pairs.append(("Playlist:", playlist))
        appendOptionalPairs(config, to: &pairs)
        return pairs
    }

    private func appendOptionalPairs(
        _ config: LivePipelineConfiguration,
        to pairs: inout [(String, String)]
    ) {
        if let ll = config.lowLatency {
            pairs.append(
                (
                    "LL-HLS:",
                    String(
                        format: "%.2fs parts",
                        ll.partTargetDuration
                    )
                ))
        }
        if config.enableDVR {
            let hours = Int(
                config.dvrWindowDuration / 3600
            )
            pairs.append(("DVR:", "\(hours)h window"))
        }
        if config.enableRecording {
            pairs.append(
                (
                    "Recording:",
                    config.recordingDirectory ?? "enabled"
                ))
        }
        if let loudness = config.targetLoudness {
            pairs.append(
                ("Loudness:", "\(loudness) LUFS")
            )
        }
        if !config.destinations.isEmpty {
            let count = config.destinations.count
            pairs.append(
                (
                    "Destinations:",
                    "\(count) push target(s)"
                ))
        }
    }
}

// MARK: - Live Config JSON

extension OutputFormatter {

    private func formatLiveConfigJSON(
        _ config: LivePipelineConfiguration,
        outputDirectory: String
    ) -> String {
        var dict: [(String, String)] = [
            (
                "\"outputDirectory\"",
                "\"\(outputDirectory)\""
            ),
            (
                "\"audioBitrate\"",
                "\(config.audioBitrate)"
            ),
            (
                "\"segmentDuration\"",
                "\(config.segmentDuration)"
            ),
            (
                "\"containerFormat\"",
                "\"\(config.containerFormat.rawValue)\""
            ),
            (
                "\"videoEnabled\"",
                config.videoEnabled ? "true" : "false"
            ),
            (
                "\"enableDVR\"",
                config.enableDVR ? "true" : "false"
            ),
            (
                "\"enableRecording\"",
                config.enableRecording ? "true" : "false"
            )
        ]
        if let loudness = config.targetLoudness {
            dict.append(
                ("\"targetLoudness\"", "\(loudness)")
            )
        }
        if !config.destinations.isEmpty {
            dict.append(
                (
                    "\"destinations\"",
                    "\(config.destinations.count)"
                ))
        }
        return formatJSONObject(dict)
    }
}

// MARK: - Live Stats Text

extension OutputFormatter {

    private func formatLiveStatsText(
        _ stats: LivePipelineStatistics
    ) -> String {
        var lines: [String] = [
            ColorOutput.bold("Live Pipeline Statistics")
        ]
        var pairs = buildStatsPairs(stats)
        appendOptionalStatsPairs(stats, to: &pairs)
        lines.append(formatKeyValues(pairs))
        return lines.joined(separator: "\n")
    }

    private func buildStatsPairs(
        _ stats: LivePipelineStatistics
    ) -> [(String, String)] {
        let h = Int(stats.uptime) / 3600
        let m = (Int(stats.uptime) % 3600) / 60
        let s = Int(stats.uptime) % 60
        let uptime = String(
            format: "%02d:%02d:%02d", h, m, s
        )
        return [
            ("Uptime:", uptime),
            ("Segments:", "\(stats.segmentsProduced)"),
            (
                "Avg Duration:",
                String(
                    format: "%.2fs",
                    stats.averageSegmentDuration
                )
            ),
            ("Total:", formatBytes(Int(stats.totalBytes))),
            (
                "Bitrate:",
                "\(stats.estimatedBitrate / 1000) kbps"
            )
        ]
    }

    private func appendOptionalStatsPairs(
        _ stats: LivePipelineStatistics,
        to pairs: inout [(String, String)]
    ) {
        if stats.activeDestinations > 0 {
            let sent = formatBytes(Int(stats.bytesSent))
            pairs.append(
                (
                    "Push:",
                    "\(stats.activeDestinations) dest, "
                        + "\(sent) sent"
                ))
        }
        if stats.pushErrors > 0 {
            pairs.append(
                (
                    "Push Errors:",
                    ColorOutput.error("\(stats.pushErrors)")
                ))
        }
        if stats.partialsProduced > 0 {
            pairs.append(
                (
                    "LL-HLS:",
                    "\(stats.partialsProduced) partials"
                ))
        }
        if stats.recordingActive {
            pairs.append(
                (
                    "Recording:",
                    "\(stats.recordedSegments) segments"
                ))
        }
        if stats.droppedSegments > 0 {
            pairs.append(
                (
                    "Dropped:",
                    ColorOutput.warning(
                        "\(stats.droppedSegments)"
                    )
                ))
        }
    }
}

// MARK: - Live Stats JSON

extension OutputFormatter {

    private func formatLiveStatsJSON(
        _ stats: LivePipelineStatistics
    ) -> String {
        let dict: [(String, String)] = [
            ("\"uptime\"", "\(stats.uptime)"),
            (
                "\"segmentsProduced\"",
                "\(stats.segmentsProduced)"
            ),
            (
                "\"averageSegmentDuration\"",
                "\(stats.averageSegmentDuration)"
            ),
            ("\"totalBytes\"", "\(stats.totalBytes)"),
            (
                "\"estimatedBitrate\"",
                "\(stats.estimatedBitrate)"
            ),
            ("\"bytesSent\"", "\(stats.bytesSent)"),
            ("\"pushErrors\"", "\(stats.pushErrors)"),
            (
                "\"partialsProduced\"",
                "\(stats.partialsProduced)"
            ),
            (
                "\"droppedSegments\"",
                "\(stats.droppedSegments)"
            )
        ]
        return formatJSONObject(dict)
    }
}

// MARK: - Preset List

extension OutputFormatter {

    private static let presetDescriptions: [(String, String)] = [
        (
            "podcast-live",
            "Podcast live (128 kbps, MPEG-TS)"
        ),
        (
            "webradio",
            "Web radio (256 kbps, LL-HLS)"
        ),
        (
            "dj-mix",
            "DJ mix (320 kbps, event, recording)"
        ),
        (
            "low-bandwidth",
            "Low bandwidth (48 kbps, mono)"
        ),
        (
            "video-live",
            "Video 1080p (4 Mbps, LL-HLS)"
        ),
        (
            "low-latency-video",
            "Low-latency 720p (2 Mbps)"
        ),
        (
            "video-simulcast",
            "Video simulcast 1080p (4 Mbps)"
        ),
        (
            "video-4k",
            "4K video (15 Mbps, LL-HLS)"
        ),
        (
            "video-4k-low-latency",
            "4K low-latency (15 Mbps)"
        ),
        (
            "podcast-video",
            "Podcast video 720p (1.5 Mbps)"
        ),
        (
            "video-live-dvr",
            "Video 1080p DVR (4 Mbps, 4h)"
        ),
        (
            "apple-podcast-live",
            "Apple Podcast live (128 kbps, fMP4)"
        ),
        (
            "broadcast",
            "Broadcast EBU R 128 (192 kbps)"
        ),
        (
            "event-recording",
            "Event recording (128 kbps, event)"
        ),
        (
            "conference-stream",
            "Conference 720p (1 Mbps, 15fps)"
        ),
        (
            "dj-mix-dvr",
            "DJ mix DVR (320 kbps, 6h)"
        )
    ]

    private func formatPresetListText() -> String {
        var lines: [String] = [
            ColorOutput.bold("Available Presets:")
        ]
        for (name, desc) in Self.presetDescriptions {
            let padded = name.padding(
                toLength: 24, withPad: " ",
                startingAt: 0
            )
            lines.append("  \(padded) \(desc)")
        }
        return lines.joined(separator: "\n")
    }

    private func formatPresetListJSON() -> String {
        let names = Self.presetDescriptions.map {
            "  \"\($0.0)\""
        }
        return "[\n\(names.joined(separator: ",\n"))\n]"
    }
}
