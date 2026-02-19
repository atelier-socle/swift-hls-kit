// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Generate or parse HLS manifests.
///
/// ```
/// hlskit manifest parse playlist.m3u8
/// hlskit manifest generate config.json --output master.m3u8
/// ```
struct ManifestCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "manifest",
        abstract: "Generate or parse HLS manifests.",
        subcommands: [
            ManifestParseCommand.self,
            ManifestGenerateCommand.self
        ]
    )
}

// MARK: - Parse Subcommand

/// Parse and display an HLS manifest.
struct ManifestParseCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "parse",
        abstract: "Parse and display an HLS manifest."
    )

    @Argument(help: "M3U8 file path")
    var input: String

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        let url = URL(fileURLWithPath: input)
        let content = try String(
            contentsOf: url, encoding: .utf8
        )
        let engine = HLSEngine()
        let manifest = try engine.parse(content)
        let formatter = OutputFormatter(from: outputFormat)

        switch manifest {
        case .master(let master):
            displayMaster(master, formatter: formatter)
        case .media(let media):
            displayMedia(media, formatter: formatter)
        }
    }

    private func displayMaster(
        _ master: MasterPlaylist,
        formatter: OutputFormatter
    ) {
        var pairs: [(String, String)] = [
            ("Type:", "Master Playlist"),
            ("Variants:", "\(master.variants.count)")
        ]
        if let version = master.version {
            pairs.append(("Version:", "\(version.rawValue)"))
        }
        for (i, variant) in master.variants.enumerated() {
            let res =
                variant.resolution.map {
                    "\($0.width)x\($0.height)"
                } ?? "audio"
            pairs.append(
                (
                    "  \(i + 1).",
                    "\(res) @ \(variant.bandwidth) bps"
                        + " → \(variant.uri)"
                ))
        }
        if !master.renditions.isEmpty {
            pairs.append(
                (
                    "Rendition groups:",
                    "\(master.renditions.count)"
                ))
        }
        print(formatter.formatKeyValues(pairs))
    }

    private func displayMedia(
        _ media: MediaPlaylist,
        formatter: OutputFormatter
    ) {
        var pairs: [(String, String)] = [
            ("Type:", "Media Playlist"),
            ("Target duration:", "\(media.targetDuration)s"),
            ("Segments:", "\(media.segments.count)")
        ]
        if let version = media.version {
            pairs.append(("Version:", "\(version.rawValue)"))
        }
        if let pType = media.playlistType {
            pairs.append(("Playlist type:", pType.rawValue))
        }
        let total = media.segments.reduce(0.0) {
            $0 + $1.duration
        }
        pairs.append(
            (
                "Total duration:",
                String(format: "%.1fs", total)
            ))
        for (i, seg) in media.segments.enumerated() {
            pairs.append(
                (
                    "  \(i).",
                    "\(seg.uri) "
                        + String(format: "(%.1fs)", seg.duration)
                ))
        }
        print(formatter.formatKeyValues(pairs))
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}

// MARK: - Generate Subcommand

/// Generate an HLS master playlist from a JSON configuration.
struct ManifestGenerateCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate an HLS master playlist from a JSON configuration."
    )

    @Argument(help: "JSON configuration file")
    var input: String

    @Option(
        name: .shortAndLong,
        help: "Output file (stdout if omitted)"
    )
    var output: String?

    func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        let url = URL(fileURLWithPath: input)
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(
            ManifestConfig.self, from: data
        )

        let playlist = buildPlaylist(from: config)
        let engine = HLSEngine()
        let m3u8 = engine.generate(playlist)

        if let outputPath = output {
            try m3u8.write(
                toFile: outputPath,
                atomically: true,
                encoding: .utf8
            )
            print("Wrote manifest to \(outputPath)")
        } else {
            print(m3u8)
        }
    }

    private func buildPlaylist(
        from config: ManifestConfig
    ) -> MasterPlaylist {
        let variants = config.variants.map { v in
            Variant(
                bandwidth: v.bandwidth,
                resolution: v.resolution.map {
                    Resolution(width: $0.width, height: $0.height)
                },
                uri: v.uri,
                averageBandwidth: v.averageBandwidth,
                codecs: v.codecs,
                frameRate: v.frameRate
            )
        }
        return MasterPlaylist(
            version: config.version.flatMap { HLSVersion(rawValue: $0) },
            variants: variants
        )
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}

// MARK: - JSON Config Model

/// JSON configuration for manifest generation.
struct ManifestConfig: Codable, Sendable {
    let version: Int?
    let variants: [VariantConfig]

    struct VariantConfig: Codable, Sendable {
        let bandwidth: Int
        let uri: String
        let averageBandwidth: Int?
        let codecs: String?
        let resolution: ResolutionConfig?
        let frameRate: Double?
    }

    struct ResolutionConfig: Codable, Sendable {
        let width: Int
        let height: Int
    }
}
