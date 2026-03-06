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
            displayMasterJSON(master)
        } else {
            displayMasterText(master, formatter: formatter)
        }
    }

    private func displayMasterJSON(
        _ master: MasterPlaylist
    ) {
        var dict: [String: Any] = [
            "type": "Master Playlist",
            "variantCount": master.variants.count,
            "renditionGroups": master.renditions.count,
            "variants": master.variants.enumerated()
                .map { formatVariantJSON($1, index: $0 + 1) }
        ]
        if let v = master.version {
            dict["version"] = v.rawValue
        }
        if !master.definitions.isEmpty {
            dict["definitions"] = formatDefinitionsJSON(
                master.definitions
            )
        }
        if !master.renditions.isEmpty {
            dict["renditions"] = master.renditions
                .map { formatRenditionJSON($0) }
        }
        printFormattedJSON(dict)
    }

    private func displayMasterText(
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
        appendSessionKeyDisplayPairs(
            master.sessionKeys, to: &pairs
        )
        appendContentSteeringDisplayPair(
            master.contentSteering, to: &pairs
        )
        appendDefinitionDisplayPairs(
            master.definitions, to: &pairs
        )
        for (i, variant) in master.variants.enumerated() {
            pairs.append(
                ("  \(i + 1).", formatVariantDetail(variant))
            )
        }
        appendRenditionDisplayPairs(
            master.renditions, to: &pairs
        )
        print(formatter.formatKeyValues(pairs))
    }

    private func displayMedia(
        _ media: MediaPlaylist,
        formatter: OutputFormatter
    ) {
        if formatter == .json {
            displayMediaJSON(media)
        } else {
            displayMediaText(media, formatter: formatter)
        }
    }

    private func displayMediaJSON(_ media: MediaPlaylist) {
        let total = media.segments.reduce(0.0) {
            $0 + $1.duration
        }
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
                        "index": i, "uri": seg.uri,
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
        if !media.definitions.isEmpty {
            dict["definitions"] = formatDefinitionsJSON(
                media.definitions
            )
        }
        printFormattedJSON(dict)
    }

    private func displayMediaText(
        _ media: MediaPlaylist,
        formatter: OutputFormatter
    ) {
        let total = media.segments.reduce(0.0) {
            $0 + $1.duration
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
        if media.iFramesOnly {
            pairs.append(("I-Frames Only:", "Yes"))
        }
        appendEncryptionDisplayPairs(
            media.segments, to: &pairs
        )
        appendDefinitionDisplayPairs(
            media.definitions, to: &pairs
        )
        appendDateRangeDisplayPairs(
            media.dateRanges, to: &pairs
        )
        pairs.append(
            (
                "Total duration:",
                String(format: "%.1fs", total)
            ))
        for (i, seg) in media.segments.enumerated() {
            pairs.append(
                ("  \(i).", formatSegmentDetail(seg))
            )
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
