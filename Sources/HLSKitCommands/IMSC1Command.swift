// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// IMSC1 subtitle operations.
///
/// ```
/// hlskit-cli imsc1 parse <file.ttml>
/// hlskit-cli imsc1 render <file.ttml> -o out.ttml
/// hlskit-cli imsc1 segment <file.ttml> -o dir
/// ```
struct IMSC1Command: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "imsc1",
        abstract: "IMSC1 subtitle operations.",
        subcommands: [
            IMSC1ParseCommand.self,
            IMSC1RenderCommand.self,
            IMSC1SegmentCommand.self
        ]
    )
}

// MARK: - Parse Subcommand

/// Parse and display an IMSC1/TTML document.
struct IMSC1ParseCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "parse",
        abstract: "Parse and display an IMSC1/TTML document."
    )

    @Argument(help: "TTML/IMSC1 file path")
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
        let xml = try String(contentsOf: url, encoding: .utf8)
        let document = try IMSC1Parser.parse(xml: xml)
        let formatter = OutputFormatter(from: outputFormat)

        if formatter == .json {
            displayJSON(document)
        } else {
            displayText(document)
        }
    }

    private func displayJSON(_ doc: IMSC1Document) {
        var dict: [String: Any] = [
            "language": doc.language,
            "regionCount": doc.regions.count,
            "styleCount": doc.styles.count,
            "subtitleCount": doc.subtitles.count
        ]
        if !doc.regions.isEmpty {
            dict["regions"] = doc.regions.map { r in
                [
                    "id": r.id,
                    "origin":
                        "\(r.originX)% \(r.originY)%",
                    "extent":
                        "\(r.extentWidth)% \(r.extentHeight)%"
                ] as [String: Any]
            }
        }
        if !doc.styles.isEmpty {
            dict["styles"] = doc.styles.map { s in
                var entry: [String: Any] = ["id": s.id]
                if let ff = s.fontFamily {
                    entry["fontFamily"] = ff
                }
                if let fs = s.fontSize {
                    entry["fontSize"] = fs
                }
                if let c = s.color {
                    entry["color"] = c
                }
                return entry
            }
        }
        dict["subtitles"] = doc.subtitles.map { sub in
            [
                "begin": sub.begin,
                "end": sub.end,
                "text": sub.text
            ] as [String: Any]
        }
        printJSON(dict)
    }

    private func displayText(_ doc: IMSC1Document) {
        var pairs: [(String, String)] = [
            ("Language:", doc.language),
            ("Regions:", "\(doc.regions.count)"),
            ("Styles:", "\(doc.styles.count)"),
            ("Subtitles:", "\(doc.subtitles.count)")
        ]
        for region in doc.regions {
            pairs.append(
                (
                    "  Region:",
                    "\(region.id) origin=\(region.originX)%,"
                        + "\(region.originY)%"
                        + " extent=\(region.extentWidth)%,"
                        + "\(region.extentHeight)%"
                ))
        }
        for style in doc.styles {
            var detail = style.id
            if let ff = style.fontFamily {
                detail += " font=\(ff)"
            }
            if let fs = style.fontSize {
                detail += " size=\(fs)"
            }
            pairs.append(("  Style:", detail))
        }
        for sub in doc.subtitles {
            let begin = formatTime(sub.begin)
            let end = formatTime(sub.end)
            pairs.append(
                (
                    "  \(begin)-\(end):",
                    sub.text
                ))
        }
        let formatter = OutputFormatter.text
        print(formatter.formatKeyValues(pairs))
    }

    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        let ms = Int((seconds - Double(Int(seconds))) * 1000)
        return String(
            format: "%02d:%02d:%02d.%03d", h, m, s, ms
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
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}

// MARK: - Render Subcommand

/// Render an IMSC1 document to normalized TTML.
struct IMSC1RenderCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "render",
        abstract:
            "Render an IMSC1 document to normalized TTML."
    )

    @Argument(help: "TTML/IMSC1 file path")
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
        let xml = try String(contentsOf: url, encoding: .utf8)
        let document = try IMSC1Parser.parse(xml: xml)
        let rendered = IMSC1Renderer.render(document)

        if let outputPath = output {
            try rendered.write(
                toFile: outputPath,
                atomically: true,
                encoding: .utf8
            )
            print("Wrote normalized TTML to \(outputPath)")
        } else {
            print(rendered)
        }
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}

// MARK: - Segment Subcommand

/// Segment an IMSC1 document into fMP4 segments.
struct IMSC1SegmentCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "segment",
        abstract:
            "Segment an IMSC1 document into fMP4 segments."
    )

    @Argument(help: "TTML/IMSC1 file path")
    var input: String

    @Option(
        name: .shortAndLong,
        help: "Output directory for segments"
    )
    var outputDirectory: String

    @Option(
        name: .long,
        help: "Language override (default: from document)"
    )
    var language: String?

    @Option(
        name: .long,
        help: "Segment duration in seconds (default: 6.0)"
    )
    var segmentDuration: Double = 6.0

    @Option(
        name: .long,
        help: "Timescale (default: 1000)"
    )
    var timescale: UInt32 = 1000

    func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        let url = URL(fileURLWithPath: input)
        let xml = try String(contentsOf: url, encoding: .utf8)
        let document = try IMSC1Parser.parse(xml: xml)

        let outURL = URL(fileURLWithPath: outputDirectory)
        try FileManager.default.createDirectory(
            at: outURL, withIntermediateDirectories: true
        )

        let lang = language ?? document.language
        let segmenter = IMSC1Segmenter()

        let initData = segmenter.createInitSegment(
            language: lang, timescale: timescale
        )
        try initData.write(
            to: outURL.appendingPathComponent("init.mp4")
        )

        let segmentFilenames = try writeSegments(
            document: document,
            segmenter: segmenter,
            outURL: outURL
        )

        try writePlaylist(
            segmentFilenames: segmentFilenames,
            outURL: outURL
        )
        printSegmentSummary(segCount: segmentFilenames.count)
    }

    private func writeSegments(
        document: IMSC1Document,
        segmenter: IMSC1Segmenter,
        outURL: URL
    ) throws -> [String] {
        let totalDuration =
            document.subtitles.isEmpty
            ? segmentDuration
            : max(
                document.subtitles.map(\.end).max() ?? 0,
                segmentDuration
            )
        let segCount = max(
            1, Int(ceil(totalDuration / segmentDuration))
        )

        var filenames: [String] = []
        for i in 0..<segCount {
            let baseTime = UInt64(
                Double(i) * segmentDuration
                    * Double(timescale)
            )
            let duration = UInt32(
                segmentDuration * Double(timescale)
            )
            let data = segmenter.createMediaSegment(
                document: document,
                sequenceNumber: UInt32(i),
                baseDecodeTime: baseTime,
                duration: duration
            )
            let filename = String(
                format: "segment_%03d.m4s", i
            )
            try data.write(
                to: outURL.appendingPathComponent(filename)
            )
            filenames.append(filename)
        }
        return filenames
    }

    private func writePlaylist(
        segmentFilenames: [String],
        outURL: URL
    ) throws {
        let playlist = buildPlaylist(
            segmentFilenames: segmentFilenames,
            segmentDuration: segmentDuration
        )
        let playlistURL = outURL.appendingPathComponent(
            "playlist.m3u8"
        )
        try playlist.write(
            to: playlistURL, atomically: true, encoding: .utf8
        )
    }

    private func printSegmentSummary(segCount: Int) {
        print(
            ColorOutput.success(
                "Created \(segCount) segments"
            )
        )
        print("  Init: init.mp4")
        print(
            "  Segments: segment_000.m4s"
                + " — segment_\(String(format: "%03d", segCount - 1)).m4s"
        )
        print("  Playlist: playlist.m3u8")
    }

    private func buildPlaylist(
        segmentFilenames: [String],
        segmentDuration: Double
    ) -> String {
        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:7",
            "#EXT-X-TARGETDURATION:\(Int(ceil(segmentDuration)))",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-PLAYLIST-TYPE:VOD",
            "#EXT-X-MAP:URI=\"init.mp4\""
        ]
        for filename in segmentFilenames {
            let durStr = String(
                format: "%.3f", segmentDuration
            )
            lines.append("#EXTINF:\(durStr),")
            lines.append(filename)
        }
        lines.append("#EXT-X-ENDLIST")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func printErr(_ message: String) {
        var stderr = FileHandleOutputStream(
            FileHandle.standardError
        )
        print(message, to: &stderr)
    }
}
