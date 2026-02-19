// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Transcode and segment a media file into multi-quality HLS.
///
/// ```
/// hlskit transcode input.mp4 --output ./hls/ --preset 720p
/// hlskit transcode input.mp4 --presets 480p,720p,1080p
/// hlskit transcode input.mp4 --ladder standard
/// ```
struct TranscodeCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "transcode",
        abstract: "Transcode and segment a media file into multi-quality HLS."
    )

    @Argument(help: "Input media file")
    var input: String

    @Option(
        name: .shortAndLong,
        help: "Output directory (default: ./hls_output/)"
    )
    var output: String = "./hls_output/"

    @Option(
        name: .long,
        help: "Single quality preset: 360p, 480p, 720p, 1080p, 2160p, audio"
    )
    var preset: String?

    @Option(
        name: .long,
        help: "Multiple presets (comma-separated): 480p,720p,1080p"
    )
    var presets: String?

    @Option(
        name: .long,
        help: "Resolution ladder: standard, full"
    )
    var ladder: String?

    @Option(
        name: .long,
        help: "Container format: fmp4, ts (default: fmp4)"
    )
    var format: String = "fmp4"

    @Option(
        name: .shortAndLong,
        help: "Segment duration in seconds (default: 6)"
    )
    var duration: Double = 6.0

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
        let engine = HLSEngine()

        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        let variants = resolveVariants()

        if !quiet {
            print("Transcoding: \(inputURL.lastPathComponent)")
            let names = variants.map(\.name)
            print("Variants: \(names.joined(separator: ", "))")
            print("")
        }

        let config = TranscodingConfig(
            segmentDuration: duration
        )

        if variants.count == 1, let single = variants.first {
            let result = try await engine.transcode(
                input: inputURL,
                outputDirectory: outputURL,
                preset: single,
                config: config
            )
            if !quiet {
                print(
                    ColorOutput.success("Transcoding complete")
                )
                print("  Output: \(result.outputDirectory.path)")
            }
        } else {
            let result = try await engine.transcodeVariants(
                input: inputURL,
                outputDirectory: outputURL,
                variants: variants,
                config: config
            )
            if !quiet {
                print(
                    ColorOutput.success("Transcoding complete")
                )
                let count = result.variants.count
                print("  Variants: \(count)")
                if let master = result.masterPlaylist {
                    print("  Master: \(master)")
                }
            }
        }
    }
}

// MARK: - Variant Resolution

extension TranscodeCommand {

    private func resolveVariants() -> [QualityPreset] {
        if let ladderName = ladder {
            return resolveLadder(ladderName)
        }
        if let presetsStr = presets {
            return parsePresetList(presetsStr)
        }
        if let presetName = preset {
            if let p = parsePreset(presetName) {
                return [p]
            }
        }
        return [.p720]
    }

    private func resolveLadder(
        _ name: String
    ) -> [QualityPreset] {
        switch name.lowercased() {
        case "full":
            return QualityPreset.fullLadder
        default:
            return QualityPreset.standardLadder
        }
    }

    private func parsePresetList(
        _ string: String
    ) -> [QualityPreset] {
        string
            .split(separator: ",")
            .compactMap {
                parsePreset(
                    String($0).trimmingCharacters(
                        in: .whitespaces
                    ))
            }
    }

    private func parsePreset(
        _ name: String
    ) -> QualityPreset? {
        switch name.lowercased() {
        case "360p": return .p360
        case "480p": return .p480
        case "720p": return .p720
        case "1080p": return .p1080
        case "2160p", "4k": return .p2160
        case "audio", "audio-only": return .audioOnly
        default: return nil
        }
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}
