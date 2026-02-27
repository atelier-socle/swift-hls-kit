// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Generate an I-frame only playlist from a media playlist.
///
/// ```
/// hlskit iframe --input /tmp/vod/stream.m3u8 --output /tmp/vod/iframe.m3u8
/// hlskit iframe --input /tmp/vod/stream.m3u8 --output /tmp/vod/iframe.m3u8 --interval 2.0
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
        try validateInputs()

        let inputURL = URL(fileURLWithPath: input)
        let playlist = try parseMediaPlaylist(at: inputURL)

        let inputDir = inputURL.deletingLastPathComponent()
        let generator = buildGenerator(
            playlist: playlist, inputDir: inputDir
        )

        let iframePlaylist = generator.generate()
        let outputURL = URL(fileURLWithPath: output)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try iframePlaylist.write(
            to: outputURL, atomically: true, encoding: .utf8
        )

        if !quiet {
            printSummary(generator: generator)
        }
    }
}

// MARK: - Generator Building

extension IFrameCommand {

    private func buildGenerator(
        playlist: MediaPlaylist,
        inputDir: URL
    ) -> IFramePlaylistGenerator {
        let initURI = playlist.segments.first?.map?.uri
        let config = IFramePlaylistGenerator.Configuration(
            version: 7,
            initSegmentURI: initURI
        )
        var generator = IFramePlaylistGenerator(
            configuration: config
        )

        let keyframeRatio = 0.1
        for segment in playlist.segments {
            let segURL = inputDir.appendingPathComponent(
                segment.uri
            )
            let fileSize = segmentFileSize(at: segURL)
            let kfSize = max(
                1, Int(Double(fileSize) * keyframeRatio)
            )

            generator.addKeyframe(
                segmentURI: segment.uri,
                byteOffset: 0,
                byteLength: kfSize,
                duration: segment.duration,
                programDateTime: segment.programDateTime,
                isDiscontinuity: segment.discontinuity
            )
        }

        return generator
    }

    private func segmentFileSize(at url: URL) -> Int {
        let attrs = try? FileManager.default
            .attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? Int) ?? 0
    }
}

// MARK: - Validation

extension IFrameCommand {

    private func validateInputs() throws {
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

        if let size = thumbnailSize {
            guard parseDimensions(size) != nil else {
                printErr(
                    "Error: --thumbnail-size must be WxH "
                        + "(e.g., 320x180)"
                )
                throw ExitCode(ExitCodes.validationError)
            }
        }
    }

    private func parseMediaPlaylist(
        at url: URL
    ) throws -> MediaPlaylist {
        guard
            FileManager.default.fileExists(
                atPath: url.path
            )
        else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        let content = try String(
            contentsOf: url, encoding: .utf8
        )
        let engine = HLSEngine()
        let manifest = try engine.parse(content)

        guard case .media(let playlist) = manifest else {
            printErr(
                "Error: input must be a media playlist,"
                    + " not a master playlist"
            )
            throw ExitCode(ExitCodes.validationError)
        }

        return playlist
    }

    private func printSummary(
        generator: IFramePlaylistGenerator
    ) {
        let formatter = OutputFormatter(from: outputFormat)
        print(
            ColorOutput.success(
                "I-Frame playlist generated"
            )
        )
        let pairs: [(String, String)] = [
            ("Input:", input),
            ("Output:", output),
            (
                "Keyframes:",
                "\(generator.keyframeCount)"
            ),
            (
                "Target Duration:",
                "\(generator.calculateTargetDuration())s"
            )
        ]
        print(formatter.formatKeyValues(pairs))
    }
}

// MARK: - Helpers

extension IFrameCommand {

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
