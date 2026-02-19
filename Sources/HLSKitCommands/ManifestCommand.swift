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
        if formatter == .json {
            var dict: [String: Any] = [
                "type": "Master Playlist",
                "variantCount": master.variants.count,
                "renditionGroups": master.renditions.count,
                "variants": master.variants.enumerated()
                    .map { i, v -> [String: Any] in
                        [
                            "index": i + 1,
                            "resolution": v.resolution.map {
                                "\($0.width)x\($0.height)"
                            } ?? "audio",
                            "bandwidth": v.bandwidth,
                            "uri": v.uri
                        ]
                    }
            ]
            if let v = master.version {
                dict["version"] = v.rawValue
            }
            printJSON(dict)
            return
        }

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
        let total = media.segments.reduce(0.0) {
            $0 + $1.duration
        }

        if formatter == .json {
            var dict: [String: Any] = [
                "type": "Media Playlist",
                "targetDuration": media.targetDuration,
                "segmentCount": media.segments.count,
                "totalDuration": Double(
                    String(format: "%.1f", total)
                ) ?? total,
                "segments": media.segments.enumerated()
                    .map { i, seg -> [String: Any] in
                        [
                            "index": i,
                            "uri": seg.uri,
                            "duration": seg.duration
                        ]
                    }
            ]
            if let v = media.version {
                dict["version"] = v.rawValue
            }
            if let pt = media.playlistType {
                dict["playlistType"] = pt.rawValue
            }
            printJSON(dict)
            return
        }

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

    private func printJSON(_ object: Any) {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let str = String(data: data, encoding: .utf8)
        else {
            return
        }
        print(str)
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}

// MARK: - Generate Subcommand

/// Generate an HLS playlist from a JSON config or a directory of segments.
struct ManifestGenerateCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate an HLS master playlist from a JSON configuration."
    )

    @Argument(
        help: "JSON configuration file or directory of segments"
    )
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

        var isDir: ObjCBool = false
        FileManager.default.fileExists(
            atPath: input, isDirectory: &isDir
        )

        let m3u8: String
        if isDir.boolValue {
            m3u8 = try generateFromDirectory(
                URL(fileURLWithPath: input)
            )
        } else {
            let url = URL(fileURLWithPath: input)
            let data = try Data(contentsOf: url)
            let config = try JSONDecoder().decode(
                ManifestConfig.self, from: data
            )
            let playlist = buildPlaylist(from: config)
            let engine = HLSEngine()
            m3u8 = engine.generate(playlist)
        }

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

    private func generateFromDirectory(
        _ directory: URL
    ) throws -> String {
        let contents = try FileManager.default
            .contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey]
            )

        let m4sFiles =
            contents
            .filter { $0.pathExtension == "m4s" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let tsFiles =
            contents
            .filter { $0.pathExtension == "ts" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let hasInit = contents.contains {
            $0.lastPathComponent == "init.mp4"
        }

        let isFMP4 = !m4sFiles.isEmpty
        let segmentFiles = isFMP4 ? m4sFiles : tsFiles

        guard !segmentFiles.isEmpty else {
            printErr(
                "Error: no segments found in \(directory.path)"
            )
            throw ExitCode(ExitCodes.generalError)
        }

        let version = isFMP4 ? 7 : 3
        let targetDuration = 6

        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:\(version)",
            "#EXT-X-TARGETDURATION:\(targetDuration)",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-PLAYLIST-TYPE:VOD"
        ]

        if isFMP4 && hasInit {
            lines.append(
                "#EXT-X-MAP:URI=\"init.mp4\""
            )
        }

        lines += buildSegmentEntries(segmentFiles)
        lines.append("#EXT-X-ENDLIST")
        lines.append("")

        let m3u8 = lines.joined(separator: "\n")

        let playlistURL = directory.appendingPathComponent(
            "playlist.m3u8"
        )
        try m3u8.write(
            to: playlistURL, atomically: true, encoding: .utf8
        )

        return m3u8
    }

    private func buildSegmentEntries(
        _ files: [URL]
    ) -> [String] {
        files.map { file in
            let size =
                (try? file.resourceValues(
                    forKeys: [.fileSizeKey]
                ).fileSize) ?? 0
            let dur = String(
                format: "%.3f",
                max(1.0, Double(size) / 50_000.0)
            )
            return "#EXTINF:\(dur),\n\(file.lastPathComponent)"
        }
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
