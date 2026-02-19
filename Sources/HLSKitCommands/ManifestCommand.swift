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

        if isDir.boolValue {
            let playlistURL = try generateFromDirectory(
                URL(fileURLWithPath: input)
            )
            print("Wrote playlist to \(playlistURL.path)")
            return
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
            version: config.version.flatMap {
                HLSVersion(rawValue: $0)
            },
            variants: variants
        )
    }

    // MARK: - Directory Generation

    private func generateFromDirectory(
        _ directory: URL
    ) throws -> URL {
        let contents = try FileManager.default
            .contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )

        let m4sFiles =
            contents
            .filter { $0.pathExtension == "m4s" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let tsFiles =
            contents
            .filter { $0.pathExtension == "ts" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let initURL = contents.first {
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

        let durations = computeSegmentDurations(
            segmentFiles, initURL: initURL, isFMP4: isFMP4
        )
        let maxDuration = durations.max() ?? 6.0
        let targetDuration = Int(ceil(maxDuration))
        let version = isFMP4 ? 7 : 3

        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-VERSION:\(version)",
            "#EXT-X-TARGETDURATION:\(targetDuration)",
            "#EXT-X-MEDIA-SEQUENCE:0",
            "#EXT-X-PLAYLIST-TYPE:VOD"
        ]

        if isFMP4 && initURL != nil {
            lines.append(
                "#EXT-X-MAP:URI=\"init.mp4\""
            )
        }

        for (file, dur) in zip(segmentFiles, durations) {
            let durStr = String(format: "%.3f", dur)
            lines.append(
                "#EXTINF:\(durStr),\n\(file.lastPathComponent)"
            )
        }

        lines.append("#EXT-X-ENDLIST")
        lines.append("")

        let m3u8 = lines.joined(separator: "\n")
        let playlistURL = directory.appendingPathComponent(
            "playlist.m3u8"
        )
        try m3u8.write(
            to: playlistURL, atomically: true, encoding: .utf8
        )
        return playlistURL
    }

    // MARK: - Segment Duration Computation

    private func computeSegmentDurations(
        _ files: [URL], initURL: URL?, isFMP4: Bool
    ) -> [Double] {
        if isFMP4, let initURL,
            let trackMeta = readTrackMeta(from: initURL)
        {
            return files.map {
                readSegmentDuration(
                    $0, trackID: trackMeta.trackID,
                    timescale: trackMeta.timescale
                ) ?? 6.0
            }
        }
        return files.map { _ in 6.0 }
    }

    private func readTrackMeta(
        from initURL: URL
    ) -> (trackID: UInt32, timescale: UInt32)? {
        guard let data = try? Data(contentsOf: initURL),
            let boxes = try? MP4BoxReader().readBoxes(from: data),
            let info = try? MP4InfoParser().parseFileInfo(
                from: boxes
            ),
            let track = info.videoTrack ?? info.audioTrack
        else { return nil }
        return (track.trackId, track.timescale)
    }

    private func readSegmentDuration(
        _ url: URL, trackID: UInt32, timescale: UInt32
    ) -> Double? {
        guard timescale > 0,
            let data = try? Data(contentsOf: url),
            let boxes = try? MP4BoxReader().readBoxes(from: data)
        else { return nil }
        var total: UInt64 = 0
        for moof in boxes where moof.type == "moof" {
            for traf in moof.children
            where traf.type == "traf" {
                let tfhdInfo = readTfhdInfo(traf)
                guard tfhdInfo.trackID == trackID
                else { continue }
                for trun in traf.children
                where trun.type == "trun" {
                    total += readTrunDuration(
                        trun,
                        defaultDuration: tfhdInfo.defaultDuration
                    )
                }
            }
        }
        return Double(total) / Double(timescale)
    }

    // MARK: - fMP4 Box Parsing

    private func readTfhdInfo(
        _ traf: MP4Box
    ) -> (trackID: UInt32, defaultDuration: UInt32?) {
        guard let tfhd = traf.findChild("tfhd"),
            let payload = tfhd.payload,
            payload.count >= 8
        else { return (0, nil) }
        var reader = BinaryReader(data: payload)
        guard let vf = try? reader.readUInt32(),
            let trackID = try? reader.readUInt32()
        else { return (0, nil) }
        let flags = vf & 0x00FF_FFFF
        if flags & 0x01 != 0 { _ = try? reader.skip(8) }
        if flags & 0x02 != 0 { _ = try? reader.skip(4) }
        if flags & 0x08 != 0 {
            return (trackID, try? reader.readUInt32())
        }
        return (trackID, nil)
    }

    private func readTrunDuration(
        _ trun: MP4Box, defaultDuration: UInt32?
    ) -> UInt64 {
        guard let payload = trun.payload,
            payload.count >= 8
        else { return 0 }
        var reader = BinaryReader(data: payload)
        guard let vf = try? reader.readUInt32(),
            let count = try? reader.readUInt32()
        else { return 0 }
        let flags = vf & 0x00FF_FFFF
        if flags & 0x001 != 0 { _ = try? reader.skip(4) }
        if flags & 0x004 != 0 { _ = try? reader.skip(4) }
        guard flags & 0x100 != 0 else {
            return UInt64(count)
                * UInt64(defaultDuration ?? 0)
        }
        var total: UInt64 = 0
        let hasSize = flags & 0x200 != 0
        let hasFlags = flags & 0x400 != 0
        let hasComp = flags & 0x800 != 0
        for _ in 0..<count {
            if let dur = try? reader.readUInt32() {
                total += UInt64(dur)
            }
            if hasSize { _ = try? reader.skip(4) }
            if hasFlags { _ = try? reader.skip(4) }
            if hasComp { _ = try? reader.skip(4) }
        }
        return total
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
