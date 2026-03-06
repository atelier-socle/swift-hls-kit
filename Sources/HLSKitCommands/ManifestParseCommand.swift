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
                .map { variantJSON($1, index: $0 + 1) }
        ]
        if let v = master.version {
            dict["version"] = v.rawValue
        }
        if !master.definitions.isEmpty {
            dict["definitions"] = definitionsJSON(
                master.definitions
            )
        }
        if !master.renditions.isEmpty {
            dict["renditions"] = master.renditions
                .map { renditionJSON($0) }
        }
        printJSON(dict)
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
        appendDefinitionPairs(
            master.definitions, to: &pairs
        )
        for (i, variant) in master.variants.enumerated() {
            pairs.append(
                ("  \(i + 1).", variantDetail(variant))
            )
        }
        appendRenditionPairs(
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
            dict["definitions"] = definitionsJSON(
                media.definitions
            )
        }
        printJSON(dict)
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
        appendDefinitionPairs(
            media.definitions, to: &pairs
        )
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
                        + String(
                            format: "(%.1fs)", seg.duration
                        )
                ))
        }
        print(formatter.formatKeyValues(pairs))
    }

    // MARK: - Display Helpers

    private func variantJSON(
        _ v: Variant, index: Int
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "index": index,
            "resolution": v.resolution.map {
                "\($0.width)x\($0.height)"
            } ?? "audio",
            "bandwidth": v.bandwidth,
            "uri": v.uri
        ]
        if let sc = v.supplementalCodecs {
            entry["supplementalCodecs"] = sc
        }
        if let vld = v.videoLayoutDescriptor {
            entry["videoLayout"] = vld.attributeValue
        }
        return entry
    }

    private func renditionJSON(
        _ r: Rendition
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "name": r.name,
            "type": r.type.rawValue,
            "groupId": r.groupId
        ]
        if let codec = r.codec {
            entry["codec"] = codec
        }
        return entry
    }

    private func definitionsJSON(
        _ definitions: [VariableDefinition]
    ) -> [[String: Any]] {
        definitions.map { d in
            [
                "name": d.name,
                "value": d.value,
                "type": d.type.rawValue
            ]
        }
    }

    private func variantDetail(_ variant: Variant) -> String {
        let res =
            variant.resolution.map {
                "\($0.width)x\($0.height)"
            } ?? "audio"
        var detail =
            "\(res) @ \(variant.bandwidth) bps"
            + " → \(variant.uri)"
        if let sc = variant.supplementalCodecs {
            detail += " SUPPLEMENTAL-CODECS=\(sc)"
        }
        if let vld = variant.videoLayoutDescriptor {
            detail +=
                " REQ-VIDEO-LAYOUT=\(vld.attributeValue)"
        }
        return detail
    }

    private func appendDefinitionPairs(
        _ definitions: [VariableDefinition],
        to pairs: inout [(String, String)]
    ) {
        guard !definitions.isEmpty else { return }
        pairs.append(
            ("Definitions:", "\(definitions.count)")
        )
        for def in definitions {
            pairs.append(
                ("  Define:", formatDefinitionLabel(def))
            )
        }
    }

    private func appendRenditionPairs(
        _ renditions: [Rendition],
        to pairs: inout [(String, String)]
    ) {
        guard !renditions.isEmpty else { return }
        pairs.append(
            ("Rendition groups:", "\(renditions.count)")
        )
        for rendition in renditions {
            var detail =
                "\(rendition.type.rawValue) "
                + "\"\(rendition.name)\""
            if let codec = rendition.codec {
                detail += " CODECS=\(codec)"
            }
            pairs.append(("  Rendition:", detail))
        }
    }

    private func formatDefinitionLabel(
        _ def: VariableDefinition
    ) -> String {
        switch def.type {
        case .value:
            return "\(def.name)=\"\(def.value)\""
        case .import:
            return "IMPORT=\"\(def.name)\""
        case .queryParam:
            return "QUERYPARAM=\"\(def.name)\""
        }
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
