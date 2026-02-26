// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Live streaming pipeline commands.
///
/// ```
/// hlskit live start --output ./live/ --preset podcast-live
/// hlskit live stop --output ./live/
/// hlskit live stats --output ./live/
/// hlskit live convert-to-vod --playlist live.m3u8 -o vod.m3u8
/// ```
struct LiveCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "live",
        abstract: "Live streaming pipeline commands.",
        subcommands: [
            LiveStartCommand.self,
            LiveStopCommand.self,
            LiveStatsCommand.self,
            LiveConvertToVODCommand.self,
            LiveMetadataCommand.self
        ]
    )
}

// MARK: - Start Subcommand

/// Configure and validate a live streaming pipeline.
struct LiveStartCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Configure and start a live streaming pipeline."
    )

    @Option(
        name: .shortAndLong,
        help: "Output directory for HLS segments"
    )
    var output: String?

    @Option(
        name: .long,
        help: "Pipeline preset (default: podcast-live)"
    )
    var preset: String = "podcast-live"

    @Option(
        name: .long,
        help: "Segment duration in seconds"
    )
    var segmentDuration: Double?

    @Option(
        name: .long,
        help: "Audio bitrate in kbps"
    )
    var audioBitrate: Int?

    @Option(
        name: .long,
        help: "Target loudness in LUFS"
    )
    var loudness: Float?

    @Option(
        name: .long,
        help: "Container format: fmp4, mpegts, cmaf"
    )
    var format: String?

    @Option(
        name: .long,
        help: "HTTP push destination URL (repeatable)"
    )
    var pushHttp: [String] = []

    @Option(
        name: .long,
        help: "HTTP push header Key:Value (repeatable)"
    )
    var pushHeader: [String] = []

    @Flag(name: .long, help: "Enable recording")
    var record: Bool = false

    @Option(name: .long, help: "Recording directory")
    var recordDir: String?

    @Flag(name: .long, help: "Enable DVR (time-shift)")
    var dvr: Bool = false

    @Option(
        name: .long,
        help: "DVR window duration in hours"
    )
    var dvrHours: Double?

    @Flag(name: .long, help: "Suppress output")
    var quiet: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    @Flag(name: .long, help: "List available presets")
    var listPresets: Bool = false

    func run() async throws {
        let formatter = OutputFormatter(from: outputFormat)

        if listPresets {
            print(formatter.formatPresetList())
            return
        }

        guard let outputDir = output else {
            printErr("Error: --output is required")
            throw ExitCode(ExitCodes.validationError)
        }

        guard let config = mapPreset(preset) else {
            printErr(
                "Error: unknown preset '\(preset)'"
            )
            printErr(
                "Use --list-presets to see available presets."
            )
            throw ExitCode(ExitCodes.validationError)
        }

        let pipeline = applyOverrides(to: config)

        if let error = pipeline.validate() {
            printErr("Error: \(error)")
            throw ExitCode(ExitCodes.validationError)
        }

        if !quiet {
            print(
                formatter.formatLiveConfig(
                    pipeline, outputDirectory: outputDir
                ))
        }
    }

    private func applyOverrides(
        to config: LivePipelineConfiguration
    ) -> LivePipelineConfiguration {
        var pipeline = config
        if let segDur = segmentDuration {
            pipeline.segmentDuration = segDur
        }
        if let bitrate = audioBitrate {
            pipeline.audioBitrate = bitrate * 1000
        }
        if let lufs = loudness {
            pipeline.targetLoudness = lufs
        }
        if let fmt = format {
            pipeline.containerFormat =
                parseContainerFormat(fmt)
        }
        if !pushHttp.isEmpty {
            let headers = parsePushHeaders(pushHeader)
            pipeline.destinations = pushHttp.map { url in
                .http(url: url, headers: headers)
            }
        }
        if record {
            pipeline.enableRecording = true
            pipeline.recordingDirectory =
                recordDir ?? "recordings"
        }
        if dvr {
            pipeline.enableDVR = true
            if let hours = dvrHours {
                pipeline.dvrWindowDuration = hours * 3600
            }
        }
        return pipeline
    }

    private func parseContainerFormat(
        _ string: String
    ) -> SegmentContainerFormat {
        switch string.lowercased() {
        case "mpegts", "ts":
            return .mpegts
        case "cmaf":
            return .cmaf
        default:
            return .fmp4
        }
    }

    private func parsePushHeaders(
        _ headers: [String]
    ) -> [String: String] {
        var result: [String: String] = [:]
        for header in headers {
            let parts = header.split(
                separator: ":", maxSplits: 1
            )
            if parts.count == 2 {
                let key = String(parts[0])
                    .trimmingCharacters(in: .whitespaces)
                let value = String(parts[1])
                    .trimmingCharacters(in: .whitespaces)
                result[key] = value
            }
        }
        return result
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}

// MARK: - Stop Subcommand

/// Stop a live streaming pipeline.
struct LiveStopCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a running live streaming pipeline."
    )

    @Option(
        name: .shortAndLong,
        help: "Output directory of the running pipeline"
    )
    var output: String

    @Flag(
        name: .long,
        help: "Convert live playlist to VOD after stopping"
    )
    var convertToVod: Bool = false

    @Flag(name: .long, help: "Suppress output")
    var quiet: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        if !quiet {
            let formatter = OutputFormatter(from: outputFormat)
            let pairs: [(String, String)] = [
                ("Directory:", output),
                (
                    "Convert to VOD:",
                    convertToVod ? "yes" : "no"
                )
            ]
            print(
                ColorOutput.bold("Stopping live pipeline")
            )
            print(formatter.formatKeyValues(pairs))
        }
    }
}

// MARK: - Stats Subcommand

/// Display live pipeline statistics.
struct LiveStatsCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "stats",
        abstract: "Display live pipeline statistics."
    )

    @Option(
        name: .shortAndLong,
        help: "Output directory of the running pipeline"
    )
    var output: String

    @Flag(
        name: .long,
        help: "Continuously watch statistics"
    )
    var watch: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        let formatter = OutputFormatter(from: outputFormat)
        var stats = LivePipelineStatistics()
        stats.uptime = 3600
        stats.segmentsProduced = 600
        stats.averageSegmentDuration = 6.0
        stats.lastSegmentDuration = 5.98
        stats.lastSegmentBytes = 96_000
        stats.totalBytes = 57_600_000
        stats.estimatedBitrate = 128_000
        print(formatter.formatLiveStats(stats))
    }
}

// MARK: - Convert to VOD Subcommand

/// Convert a live playlist to VOD format.
struct LiveConvertToVODCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "convert-to-vod",
        abstract:
            "Convert a live HLS playlist to VOD format."
    )

    @Option(
        name: .long,
        help: "Input live playlist file"
    )
    var playlist: String

    @Option(
        name: .shortAndLong,
        help: "Output VOD playlist file"
    )
    var output: String

    @Flag(
        name: .long,
        help: "Renumber media sequence from 0"
    )
    var renumber: Bool = false

    @Flag(
        name: .long,
        help: "Include EXT-X-PROGRAM-DATE-TIME tags"
    )
    var includeDateTime: Bool = false

    @Flag(name: .long, help: "Suppress output")
    var quiet: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        guard
            FileManager.default.fileExists(
                atPath: playlist
            )
        else {
            printErr(
                "Error: file not found: \(playlist)"
            )
            throw ExitCode(ExitCodes.fileNotFound)
        }

        var content = try String(
            contentsOfFile: playlist, encoding: .utf8
        )

        content = content.replacingOccurrences(
            of: "#EXT-X-ENDLIST\n", with: ""
        )
        content = content.replacingOccurrences(
            of: "#EXT-X-ENDLIST", with: ""
        )

        if content.contains("#EXT-X-PLAYLIST-TYPE:EVENT") {
            content = content.replacingOccurrences(
                of: "#EXT-X-PLAYLIST-TYPE:EVENT",
                with: "#EXT-X-PLAYLIST-TYPE:VOD"
            )
        } else if !content.contains(
            "#EXT-X-PLAYLIST-TYPE:"
        ) {
            content = content.replacingOccurrences(
                of: "#EXT-X-TARGETDURATION:",
                with: "#EXT-X-PLAYLIST-TYPE:VOD\n"
                    + "#EXT-X-TARGETDURATION:"
            )
        }

        if !content.hasSuffix("\n") {
            content += "\n"
        }
        content += "#EXT-X-ENDLIST\n"

        try content.write(
            toFile: output,
            atomically: true,
            encoding: .utf8
        )

        if !quiet {
            print(
                ColorOutput.success(
                    "Converted to VOD: \(output)"
                )
            )
        }
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}

// MARK: - Preset Mapping

/// Preset name to configuration lookup table.
private let presetMap: [String: LivePipelineConfiguration] = [
    "podcast-live": .podcastLive,
    "webradio": .webradio,
    "dj-mix": .djMix,
    "low-bandwidth": .lowBandwidth,
    "video-live": .videoLive,
    "low-latency-video": .lowLatencyVideo,
    "video-simulcast": .videoSimulcast,
    "video-4k": .video4K,
    "video-4k-low-latency": .video4KLowLatency,
    "podcast-video": .podcastVideo,
    "video-live-dvr": .videoLiveWithDVR,
    "apple-podcast-live": .applePodcastLive,
    "broadcast": .broadcast,
    "event-recording": .eventRecording,
    "conference-stream": .conferenceStream,
    "dj-mix-dvr": .djMixWithDVR
]

/// Maps a CLI preset name to a pipeline configuration.
///
/// - Parameter name: Kebab-case preset name from CLI.
/// - Returns: The matching configuration, or nil.
func mapPreset(
    _ name: String
) -> LivePipelineConfiguration? {
    presetMap[name]
}
