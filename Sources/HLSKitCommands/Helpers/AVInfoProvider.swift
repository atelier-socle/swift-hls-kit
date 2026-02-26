// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation) && !os(watchOS)
    import ArgumentParser
    @preconcurrency import AVFoundation
    import Foundation
    import HLSKit

    extension InfoCommand {

        func displayAVFoundationInfo(
            url: URL, formatter: OutputFormatter
        ) async throws {
            let asset = AVURLAsset(url: url)
            let duration: CMTime
            let tracks: [AVAssetTrack]
            do {
                duration = try await asset.load(.duration)
                tracks = try await asset.load(.tracks)
            } catch {
                var stderr = FileHandleOutputStream(
                    FileHandle.standardError
                )
                print(
                    "Error: cannot read \(url.lastPathComponent)"
                        + " — \(error.localizedDescription)",
                    to: &stderr
                )
                throw ExitCode(ExitCodes.generalError)
            }

            let infos = await extractTrackInfos(tracks)

            if formatter == .json {
                printAVInfoJSON(
                    url: url, duration: duration.seconds,
                    tracks: infos
                )
            } else {
                printAVInfoText(
                    url: url, duration: duration.seconds,
                    tracks: infos
                )
            }
        }
    }

    // MARK: - Track Info Extraction

    extension InfoCommand {

        struct AVTrackInfo: Sendable {
            let index: Int
            let mediaType: String
            let codec: String
            let sampleRate: Double?
            let channels: Int?
            let bitrate: Float
            let resolution: String?
        }

        private func extractTrackInfos(
            _ tracks: [AVAssetTrack]
        ) async -> [AVTrackInfo] {
            var infos: [AVTrackInfo] = []
            for (i, track) in tracks.enumerated() {
                let mediaType =
                    track.mediaType == .audio
                    ? "audio"
                    : track.mediaType == .video
                        ? "video" : track.mediaType.rawValue

                let descs =
                    (try? await track.load(
                        .formatDescriptions
                    )) ?? []

                let codec = codecFromDescriptions(
                    descs, mediaType: track.mediaType
                )

                var sampleRate: Double?
                var channels: Int?
                if track.mediaType == .audio,
                    let desc = descs.first
                {
                    let asbd =
                        CMAudioFormatDescriptionGetStreamBasicDescription(
                            desc
                        )
                    sampleRate = asbd?.pointee.mSampleRate
                    channels = asbd.map {
                        Int($0.pointee.mChannelsPerFrame)
                    }
                }

                var resolution: String?
                if track.mediaType == .video {
                    let size =
                        (try? await track.load(
                            .naturalSize
                        )) ?? .zero
                    if size.width > 0 && size.height > 0 {
                        resolution =
                            "\(Int(size.width))x\(Int(size.height))"
                    }
                }

                let bitrate =
                    (try? await track.load(
                        .estimatedDataRate
                    )) ?? 0

                infos.append(
                    AVTrackInfo(
                        index: i + 1,
                        mediaType: mediaType,
                        codec: codec,
                        sampleRate: sampleRate,
                        channels: channels,
                        bitrate: bitrate,
                        resolution: resolution
                    )
                )
            }
            return infos
        }

        private func codecFromDescriptions(
            _ descs: [CMFormatDescription],
            mediaType: AVMediaType
        ) -> String {
            guard let desc = descs.first else {
                return "unknown"
            }
            let mediaCodecType =
                CMFormatDescriptionGetMediaType(desc)
            let subType =
                CMFormatDescriptionGetMediaSubType(desc)
            let fourCC = fourCharCode(subType)
            if mediaCodecType == kCMMediaType_Audio {
                return audioCodecName(fourCC)
            }
            return fourCC
        }

        private func fourCharCode(_ code: FourCharCode) -> String {
            let bytes: [UInt8] = [
                UInt8((code >> 24) & 0xFF),
                UInt8((code >> 16) & 0xFF),
                UInt8((code >> 8) & 0xFF),
                UInt8(code & 0xFF)
            ]
            return String(bytes.map { Character(UnicodeScalar($0)) })
        }

        private func audioCodecName(
            _ fourCC: String
        ) -> String {
            switch fourCC.trimmingCharacters(
                in: .whitespaces
            ) {
            case "aac", "aac ": return "AAC"
            case ".mp3": return "MP3"
            case "alac": return "ALAC"
            case "flac": return "FLAC"
            case "lpcm": return "LPCM"
            case "mp4a": return "AAC"
            default: return fourCC
            }
        }
    }

    // MARK: - AVFoundation Info Output

    extension InfoCommand {

        private func printAVInfoText(
            url: URL, duration: Double,
            tracks: [AVTrackInfo]
        ) {
            let formatter = OutputFormatter(from: outputFormat)
            var pairs: [(String, String)] = [
                ("File:", url.lastPathComponent),
                ("Type:", "Media file"),
                (
                    "Duration:",
                    String(format: "%.1fs", duration)
                ),
                ("Tracks:", "\(tracks.count)")
            ]

            for t in tracks {
                var detail = "\(t.mediaType) — \(t.codec)"
                if let res = t.resolution {
                    detail += " \(res)"
                }
                if let sr = t.sampleRate {
                    detail += " \(Int(sr)) Hz"
                }
                if let ch = t.channels {
                    detail += " \(ch)ch"
                }
                if t.bitrate > 0 {
                    detail += " @ \(formatBitrateValue(t.bitrate))"
                }
                pairs.append(("  Track \(t.index):", detail))
            }

            print(formatter.formatKeyValues(pairs))
        }

        private func printAVInfoJSON(
            url: URL, duration: Double,
            tracks: [AVTrackInfo]
        ) {
            let dict: [String: Any] = [
                "file": url.lastPathComponent,
                "type": "Media file",
                "duration": String(
                    format: "%.1fs", duration
                ),
                "trackCount": tracks.count,
                "tracks": tracks.map { t in
                    var d: [String: Any] = [
                        "index": t.index,
                        "type": t.mediaType,
                        "codec": t.codec
                    ]
                    if let res = t.resolution {
                        d["resolution"] = res
                    }
                    if let sr = t.sampleRate {
                        d["sampleRate"] = Int(sr)
                    }
                    if let ch = t.channels {
                        d["channels"] = ch
                    }
                    if t.bitrate > 0 {
                        d["bitrate"] = Int(t.bitrate)
                    }
                    return d
                }
            ]
            printJSON(dict)
        }

        private func formatBitrateValue(
            _ bps: Float
        ) -> String {
            if bps >= 1_000_000 {
                return String(
                    format: "%.1f Mbps",
                    Double(bps) / 1_000_000.0
                )
            }
            return String(
                format: "%.0f kbps",
                Double(bps) / 1_000.0
            )
        }
    }

#endif
