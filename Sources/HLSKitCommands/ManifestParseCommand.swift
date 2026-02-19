// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

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
