// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// Display information about a media file or HLS stream.
///
/// Inspects MP4 files, M3U8 playlists, or HLS directories and
/// displays track, codec, and structural information.
///
/// ```
/// hlskit info input.mp4
/// hlskit info playlist.m3u8
/// hlskit info ./hls_output/
/// ```
struct InfoCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract: "Display information about a media file or HLS stream."
    )

    @Argument(help: "Media file, M3U8 playlist, or HLS directory")
    var input: String

    @Option(
        name: .long,
        help: "Output format: text, json (default: text)"
    )
    var outputFormat: String = "text"

    func run() async throws {
        let url = URL(fileURLWithPath: input)
        let formatter = OutputFormatter(from: outputFormat)

        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        if input.hasSuffix(".m3u8") {
            try displayManifestInfo(url: url, formatter: formatter)
        } else if input.hasSuffix(".mp4")
            || input.hasSuffix(".m4a")
            || input.hasSuffix(".m4v")
        {
            try displayMP4Info(url: url, formatter: formatter)
        } else {
            try displayDirectoryInfo(
                url: url, formatter: formatter
            )
        }
    }
}

// MARK: - Manifest Info

extension InfoCommand {

    private func displayManifestInfo(
        url: URL, formatter: OutputFormatter
    ) throws {
        let content = try String(contentsOf: url, encoding: .utf8)
        let engine = HLSEngine()
        let manifest = try engine.parse(content)

        switch manifest {
        case .master(let master):
            displayMasterInfo(
                master, filename: url.lastPathComponent,
                formatter: formatter
            )
        case .media(let media):
            displayMediaInfo(
                media, filename: url.lastPathComponent,
                formatter: formatter
            )
        }
    }

    private func displayMasterInfo(
        _ master: MasterPlaylist,
        filename: String,
        formatter: OutputFormatter
    ) {
        if formatter == .json {
            var dict: [String: Any] = [
                "file": filename,
                "type": "HLS Master Playlist",
                "variantCount": master.variants.count,
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
            ("File:", filename),
            ("Type:", "HLS Master Playlist"),
            ("Variants:", "\(master.variants.count)")
        ]

        if let version = master.version {
            pairs.append(("Version:", "\(version.rawValue)"))
        }

        for (index, variant) in master.variants.enumerated() {
            let res =
                variant.resolution.map {
                    "\($0.width)x\($0.height)"
                } ?? "audio"
            let bw = formatBitrate(variant.bandwidth)
            pairs.append(
                (
                    "  \(index + 1).",
                    "\(res) @ \(bw) (\(variant.uri))"
                ))
        }

        print(formatter.formatKeyValues(pairs))
    }

    private func displayMediaInfo(
        _ media: MediaPlaylist,
        filename: String,
        formatter: OutputFormatter
    ) {
        let totalDuration = media.segments.reduce(0.0) {
            $0 + $1.duration
        }

        if formatter == .json {
            var dict: [String: Any] = [
                "file": filename,
                "type": "HLS Media Playlist",
                "segmentCount": media.segments.count,
                "targetDuration": media.targetDuration,
                "totalDuration": Double(
                    String(format: "%.1f", totalDuration)
                ) ?? totalDuration
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
            ("File:", filename),
            ("Type:", "HLS Media Playlist"),
            ("Segments:", "\(media.segments.count)"),
            ("Target duration:", "\(media.targetDuration)s")
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
                String(format: "%.1fs", totalDuration)
            ))

        print(formatter.formatKeyValues(pairs))
    }
}

// MARK: - MP4 Info

extension InfoCommand {

    private func displayMP4Info(
        url: URL, formatter: OutputFormatter
    ) throws {
        let data = try Data(contentsOf: url)
        let reader = MP4BoxReader()
        let boxes = try reader.readBoxes(from: data)
        let parser = MP4InfoParser()
        let info = try parser.parseFileInfo(from: boxes)

        if formatter == .json {
            printJSON(
                [
                    "file": url.lastPathComponent,
                    "type": "MP4 container",
                    "duration": String(
                        format: "%.1fs", info.durationSeconds
                    ),
                    "brands": info.brands.joined(
                        separator: ", "
                    ),
                    "trackCount": info.tracks.count,
                    "tracks": info.tracks.map { t in
                        var d: [String: Any] = [
                            "index": t.trackId,
                            "type": t.mediaType.rawValue,
                            "codec": t.codec
                        ]
                        if let dims = t.dimensions {
                            d["dimensions"] =
                                "\(dims.width)x\(dims.height)"
                        }
                        return d
                    }
                ] as [String: Any])
            return
        }

        var pairs: [(String, String)] = [
            ("File:", url.lastPathComponent),
            ("Type:", "MP4 container"),
            (
                "Duration:",
                String(
                    format: "%.1fs", info.durationSeconds
                )
            ),
            ("Brands:", info.brands.joined(separator: ", ")),
            ("Tracks:", "\(info.tracks.count)")
        ]

        for track in info.tracks {
            let typeStr = track.mediaType.rawValue
            let codec = track.codec
            var detail = "\(typeStr) — \(codec)"
            if let dims = track.dimensions {
                detail += " \(dims.width)x\(dims.height)"
            }
            pairs.append(("  Track \(track.trackId):", detail))
        }

        print(formatter.formatKeyValues(pairs))
    }
}

// MARK: - Directory Info

extension InfoCommand {

    private func displayDirectoryInfo(
        url: URL, formatter: OutputFormatter
    ) throws {
        let fm = FileManager.default
        let contents = try fm.contentsOfDirectory(
            at: url, includingPropertiesForKeys: nil
        )
        let m3u8Files = contents.filter {
            $0.pathExtension == "m3u8"
        }
        let tsFiles = contents.filter {
            $0.pathExtension == "ts"
        }
        let m4sFiles = contents.filter {
            $0.pathExtension == "m4s"
        }

        if formatter == .json {
            printJSON(
                [
                    "directory": url.lastPathComponent,
                    "playlistCount": m3u8Files.count,
                    "tsSegments": tsFiles.count,
                    "fmp4Segments": m4sFiles.count,
                    "playlists": m3u8Files.map(\.lastPathComponent)
                ] as [String: Any])
            return
        }

        var pairs: [(String, String)] = [
            ("Directory:", url.lastPathComponent),
            ("M3U8 playlists:", "\(m3u8Files.count)"),
            ("TS segments:", "\(tsFiles.count)"),
            ("fMP4 segments:", "\(m4sFiles.count)")
        ]

        for m3u8 in m3u8Files {
            pairs.append(("  Playlist:", m3u8.lastPathComponent))
        }

        print(formatter.formatKeyValues(pairs))
    }
}

// MARK: - Helpers

extension InfoCommand {

    private func formatBitrate(_ bps: Int) -> String {
        if bps >= 1_000_000 {
            return String(
                format: "%.1f Mbps", Double(bps) / 1_000_000.0
            )
        }
        return String(
            format: "%.0f kbps", Double(bps) / 1_000.0
        )
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
        var stderr = FileHandleOutputStream(FileHandle.standardError)
        print(message, to: &stderr)
    }
}

/// Output stream that writes to a file handle.
struct FileHandleOutputStream: TextOutputStream, Sendable {
    private let handle: FileHandle
    init(_ handle: FileHandle) { self.handle = handle }
    mutating func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            handle.write(data)
        }
    }
}
