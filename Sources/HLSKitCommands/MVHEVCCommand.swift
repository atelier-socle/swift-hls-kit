// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import ArgumentParser
import Foundation
import HLSKit

/// MV-HEVC spatial video operations.
///
/// ```
/// hlskit-cli mvhevc package <input.hevc> -o dir
/// hlskit-cli mvhevc info <file.mp4>
/// ```
struct MVHEVCCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "mvhevc",
        abstract: "MV-HEVC spatial video operations.",
        subcommands: [
            MVHEVCPackageCommand.self,
            MVHEVCInfoCommand.self
        ]
    )
}

// MARK: - Package Subcommand

/// Package a raw MV-HEVC bitstream into fMP4 segments.
struct MVHEVCPackageCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "package",
        abstract:
            "Package MV-HEVC bitstream into fMP4 segments."
    )

    @Argument(help: "Input HEVC bitstream (Annex B format)")
    var input: String

    @Option(
        name: .shortAndLong,
        help: "Output directory for segments"
    )
    var outputDirectory: String

    @Option(
        name: .long,
        help: "Channel layout: stereo, mono (default: stereo)"
    )
    var layout: String = "stereo"

    @Option(
        name: .long,
        help: "Segment duration in seconds (default: 6.0)"
    )
    var segmentDuration: Double = 6.0

    @Option(
        name: .long,
        help: "Frame rate (default: 30.0)"
    )
    var frameRate: Double = 30.0

    @Option(name: .long, help: "Video width (default: 1920)")
    var width: Int = 1920

    @Option(name: .long, help: "Video height (default: 1080)")
    var height: Int = 1080

    func run() async throws {
        guard FileManager.default.fileExists(atPath: input) else {
            printErr("Error: file not found: \(input)")
            throw ExitCode(ExitCodes.fileNotFound)
        }

        let inputURL = URL(fileURLWithPath: input)
        let data = try Data(contentsOf: inputURL)

        let processor = MVHEVCSampleProcessor()
        let nalus = processor.extractNALUs(from: data)

        guard
            let paramSets = processor.extractParameterSets(
                from: nalus
            )
        else {
            printErr(
                "Error: no VPS/SPS/PPS found in bitstream"
            )
            throw ExitCode(ExitCodes.generalError)
        }

        let channelLayout: VideoChannelLayout =
            layout.lowercased() == "mono"
            ? .mono : .stereoLeftRight

        let config = SpatialVideoConfiguration(
            baseLayerCodec: "hvc1.2.4.L123.B0",
            channelLayout: channelLayout,
            width: width,
            height: height,
            frameRate: frameRate
        )

        let outURL = URL(fileURLWithPath: outputDirectory)
        try FileManager.default.createDirectory(
            at: outURL, withIntermediateDirectories: true
        )

        try writeInitSegment(
            config: config, paramSets: paramSets,
            outURL: outURL
        )

        let videoNALUs = filterVideoNALUs(
            nalus, processor: processor
        )
        let segmentFilenames = try writeMediaSegments(
            videoNALUs: videoNALUs,
            processor: processor,
            config: config,
            outURL: outURL
        )

        try writePlaylist(
            segmentFilenames: segmentFilenames,
            outURL: outURL
        )

        printSummary(
            segCount: segmentFilenames.count,
            channelLayout: channelLayout
        )
    }

    private func writeInitSegment(
        config: SpatialVideoConfiguration,
        paramSets: HEVCParameterSets,
        outURL: URL
    ) throws {
        let packager = MVHEVCPackager()
        let initData = packager.createInitSegment(
            configuration: config,
            parameterSets: paramSets
        )
        let initURL = outURL.appendingPathComponent("init.mp4")
        try initData.write(to: initURL)
    }

    private func filterVideoNALUs(
        _ nalus: [Data],
        processor: MVHEVCSampleProcessor
    ) -> [Data] {
        nalus.filter { nalu in
            guard let type = processor.naluType(nalu) else {
                return false
            }
            return type != .vps && type != .sps
                && type != .pps
        }
    }

    private func writeMediaSegments(
        videoNALUs: [Data],
        processor: MVHEVCSampleProcessor,
        config: SpatialVideoConfiguration,
        outURL: URL
    ) throws -> [String] {
        let framesPerSeg = Int(segmentDuration * frameRate)
        let timescale: UInt32 = 90_000
        let frameDur = UInt32(Double(timescale) / frameRate)
        let totalFrames = max(1, videoNALUs.count)
        let segCount = max(
            1,
            Int(
                ceil(
                    Double(totalFrames)
                        / Double(framesPerSeg)
                ))
        )

        let packager = MVHEVCPackager()
        var filenames: [String] = []

        for i in 0..<segCount {
            let start = i * framesPerSeg
            let end = min(start + framesPerSeg, totalFrames)
            let durations = [UInt32](
                repeating: frameDur, count: end - start
            )
            let baseTime =
                UInt64(i) * UInt64(framesPerSeg)
                * UInt64(frameDur)

            let segNALUs = sliceNALUs(
                videoNALUs, processor: processor,
                start: start, end: end
            )

            let segData = packager.createMediaSegment(
                nalus: segNALUs,
                configuration: config,
                sequenceNumber: UInt32(i),
                baseDecodeTime: baseTime,
                sampleDurations: durations
            )
            let filename = String(
                format: "segment_%03d.m4s", i
            )
            try segData.write(
                to: outURL.appendingPathComponent(filename)
            )
            filenames.append(filename)
        }
        return filenames
    }

    private func sliceNALUs(
        _ videoNALUs: [Data],
        processor: MVHEVCSampleProcessor,
        start: Int,
        end: Int
    ) -> Data {
        guard start < videoNALUs.count else { return Data() }
        let slice = videoNALUs[
            start..<min(end, videoNALUs.count)
        ]
        return processor.annexBToLengthPrefixed(
            slice.reduce(into: Data()) { result, nalu in
                result.append(
                    contentsOf: [0x00, 0x00, 0x00, 0x01]
                )
                result.append(nalu)
            }
        )
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

    private func printSummary(
        segCount: Int,
        channelLayout: VideoChannelLayout
    ) {
        print(
            ColorOutput.success(
                "Packaged MV-HEVC into \(segCount) segments"
            )
        )
        print("  Layout: \(channelLayout.rawValue)")
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

// MARK: - Info Subcommand

/// Inspect an fMP4 file for MV-HEVC spatial boxes.
struct MVHEVCInfoCommand: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "info",
        abstract:
            "Inspect fMP4 for MV-HEVC spatial video boxes."
    )

    @Argument(help: "fMP4 file to inspect")
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
        let data = try Data(contentsOf: url)
        let reader = MP4BoxReader()
        let boxes = try reader.readBoxes(from: data)

        let spatialBoxes = findSpatialBoxes(in: boxes)
        let formatter = OutputFormatter(from: outputFormat)

        if formatter == .json {
            displayJSON(spatialBoxes, filename: url.lastPathComponent)
        } else {
            displayText(spatialBoxes, filename: url.lastPathComponent)
        }
    }

    private func displayJSON(
        _ info: SpatialBoxInfo, filename: String
    ) {
        let dict: [String: Any] = [
            "file": filename,
            "hasSpatialVideo": info.hasVexu,
            "vexu": info.hasVexu,
            "eyes": info.hasEyes,
            "stri": info.hasStri,
            "hero": info.hasHero,
            "hvcC": info.hasHvcC
        ]
        printJSON(dict)
    }

    private func displayText(
        _ info: SpatialBoxInfo, filename: String
    ) {
        var pairs: [(String, String)] = [
            ("File:", filename),
            (
                "Spatial Video:",
                info.hasVexu ? "Yes" : "No"
            )
        ]
        if info.hasVexu {
            pairs.append(("  vexu:", "present"))
        }
        if info.hasEyes {
            pairs.append(("  eyes:", "present"))
        }
        if info.hasStri {
            pairs.append(("  stri:", "present"))
        }
        if info.hasHero {
            pairs.append(("  hero:", "present"))
        }
        if info.hasHvcC {
            pairs.append(("  hvcC:", "present"))
        }
        if !info.hasVexu {
            pairs.append(
                ("  Note:", "No spatial video boxes found")
            )
        }
        let formatter = OutputFormatter(from: outputFormat)
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

// MARK: - Spatial Box Detection

struct SpatialBoxInfo: Sendable {
    var hasVexu = false
    var hasEyes = false
    var hasStri = false
    var hasHero = false
    var hasHvcC = false
}

func findSpatialBoxes(in boxes: [MP4Box]) -> SpatialBoxInfo {
    var info = SpatialBoxInfo()
    searchBoxes(boxes, info: &info)
    return info
}

private func searchBoxes(
    _ boxes: [MP4Box], info: inout SpatialBoxInfo
) {
    for box in boxes {
        switch box.type {
        case "vexu": info.hasVexu = true
        case "eyes": info.hasEyes = true
        case "stri": info.hasStri = true
        case "hero": info.hasHero = true
        case "hvcC": info.hasHvcC = true
        default: break
        }
        if !box.children.isEmpty {
            searchBoxes(box.children, info: &info)
        }
    }
}
