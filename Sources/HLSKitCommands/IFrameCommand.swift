// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation

/// Generate an I-frame only playlist from a media playlist.
///
/// ```
/// hlskit iframe --input /tmp/vod/stream.m3u8 --output /tmp/vod/iframe.m3u8
/// hlskit iframe --input /tmp/vod/stream.m3u8 --output /tmp/vod/iframe.m3u8 --interval 2.0
/// hlskit iframe --input /tmp/vod/stream.m3u8 --output /tmp/vod/iframe.m3u8 --thumbnail-output /tmp/thumbnails/
/// ```
struct IFrameCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "iframe",
        abstract:
            "Generate I-frame only playlist from a media playlist."
    )

    // MARK: - Input/Output

    @Option(
        name: .long,
        help: "Input media playlist (.m3u8)"
    )
    var input: String

    @Option(
        name: .shortAndLong,
        help: "Output I-frame playlist path"
    )
    var output: String

    // MARK: - I-frame Options

    @Option(
        name: .long,
        help: "I-frame interval in seconds (default: from source)"
    )
    var interval: Double?

    @Option(
        name: .long,
        help: "Output directory for extracted thumbnails"
    )
    var thumbnailOutput: String?

    @Option(
        name: .long,
        help: "Thumbnail dimensions (WxH, e.g., 320x180)"
    )
    var thumbnailSize: String?

    @Flag(
        name: .long,
        help: "Include BYTERANGE for byte-range addressing"
    )
    var byteRange: Bool = false

    // MARK: - Options

    @Flag(name: .long, help: "Suppress output")
    var quiet: Bool = false

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    // MARK: - Run

    func run() async throws {
        guard input.hasSuffix(".m3u8") else {
            printErr(
                "Error: --input must be a .m3u8 file"
            )
            throw ExitCode(ExitCodes.validationError)
        }

        guard !output.isEmpty else {
            printErr("Error: --output is required")
            throw ExitCode(ExitCodes.validationError)
        }

        var parsedSize: (Int, Int)?
        if let size = thumbnailSize {
            parsedSize = parseDimensions(size)
            guard parsedSize != nil else {
                printErr(
                    "Error: --thumbnail-size must be WxH "
                        + "(e.g., 320x180)"
                )
                throw ExitCode(ExitCodes.validationError)
            }
        }

        guard !quiet else { return }

        let formatter = OutputFormatter(from: outputFormat)
        var pairs: [(String, String)] = [
            ("Input:", input),
            ("Output:", output)
        ]

        if let ivl = interval {
            pairs.append(
                ("Interval:", "\(ivl)s")
            )
        }

        pairs.append(
            ("BYTERANGE:", byteRange ? "yes" : "no")
        )

        if let dir = thumbnailOutput {
            pairs.append(("Thumbnails:", dir))
        }

        if let dims = parsedSize {
            pairs.append(
                ("Size:", "\(dims.0)x\(dims.1)")
            )
        }

        print(
            ColorOutput.bold("I-Frame Playlist Generation")
        )
        print(formatter.formatKeyValues(pairs))
    }

    // MARK: - Helpers

    private func parseDimensions(
        _ string: String
    ) -> (Int, Int)? {
        let parts = string.lowercased().split(separator: "x")
        guard parts.count == 2,
            let width = Int(parts[0]),
            let height = Int(parts[1]),
            width > 0, height > 0
        else {
            return nil
        }
        return (width, height)
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}
