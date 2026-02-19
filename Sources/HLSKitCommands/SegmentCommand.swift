// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Segment a media file into HLS segments.
///
/// ```
/// hlskit segment input.mp4 --output ./hls/
/// hlskit segment input.mp4 --output ./hls/ --format ts
/// hlskit segment input.mp4 --output ./hls/ --duration 10
/// hlskit segment input.mp4 --byte-range
/// ```
struct SegmentCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "segment",
        abstract: "Segment a media file into HLS segments."
    )

    @Argument(help: "Input media file (MP4, M4A, etc.)")
    var input: String

    @Option(
        name: .shortAndLong,
        help: "Output directory (default: ./hls_output/)"
    )
    var output: String = "./hls_output/"

    @Option(
        name: .long,
        help: "Container format: fmp4, ts (default: fmp4)"
    )
    var format: String = "fmp4"

    @Option(
        name: .shortAndLong,
        help: "Target segment duration in seconds (default: 6)"
    )
    var duration: Double = 6.0

    @Flag(
        name: .long,
        help: "Use byte-range segments (single file)"
    )
    var byteRange: Bool = false

    @Flag(name: .long, help: "Suppress output")
    var quiet: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        let inputURL = URL(fileURLWithPath: input)
        let outputURL = URL(fileURLWithPath: output)
        let formatter = OutputFormatter(from: outputFormat)

        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        let containerFormat = parseContainerFormat(format)
        let outputMode: SegmentationConfig.OutputMode =
            byteRange ? .byteRange : .separateFiles

        let config = SegmentationConfig(
            targetSegmentDuration: duration,
            containerFormat: containerFormat,
            outputMode: outputMode
        )

        if !quiet {
            print("Segmenting: \(inputURL.lastPathComponent)")
            let fmtName =
                containerFormat == .fragmentedMP4 ? "fMP4" : "TS"
            print("Format:     \(fmtName)")
            print("Duration:   \(duration)s")
            print("")
        }

        let engine = HLSEngine()
        let result = try engine.segmentToDirectory(
            data: Data(contentsOf: inputURL),
            outputDirectory: outputURL,
            config: config
        )

        if !quiet {
            let summary = formatter.formatSegmentResult(
                result, outputDirectory: output
            )
            print(summary)
        }
    }

    private func parseContainerFormat(
        _ string: String
    ) -> SegmentationConfig.ContainerFormat {
        switch string.lowercased() {
        case "ts", "mpegts", "mpeg-ts":
            return .mpegTS
        default:
            return .fragmentedMP4
        }
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}
