// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation

    /// Analyzes source media using ffprobe.
    ///
    /// Provides source file information (duration, tracks, codecs)
    /// using `ffprobe` instead of AVFoundation. Works on Linux.
    ///
    /// - SeeAlso: ``FFmpegTranscoder``, ``FFmpegSourceInfo``
    struct FFmpegSourceAnalyzer: Sendable {

        /// The process runner for executing ffprobe.
        let runner: FFmpegProcessRunner

        // Uses synthesized memberwise initializer.

        /// Analyze a source file.
        ///
        /// - Parameter url: Source file URL.
        /// - Returns: Source information from ffprobe.
        /// - Throws: ``TranscodingError`` if analysis fails.
        func analyze(_ url: URL) async throws -> FFmpegSourceInfo {
            let builder = FFmpegCommandBuilder()
            let args = builder.buildProbeArguments(
                input: url.path
            )

            let result = try await runner.runFFprobe(
                arguments: args
            )

            guard let data = result.stdout.data(using: .utf8)
            else {
                throw TranscodingError.decodingFailed(
                    "Cannot read ffprobe output"
                )
            }

            return try Self.parseProbeOutput(data)
        }
    }

    // MARK: - JSON Parsing

    extension FFmpegSourceAnalyzer {

        /// Parse ffprobe JSON output into ``FFmpegSourceInfo``.
        ///
        /// Exposed as static for unit testing without ffprobe.
        ///
        /// - Parameter data: Raw JSON data from ffprobe.
        /// - Returns: Parsed source information.
        /// - Throws: ``TranscodingError`` if JSON is invalid.
        static func parseProbeOutput(
            _ data: Data
        ) throws -> FFmpegSourceInfo {
            let parsed: Any
            do {
                parsed = try JSONSerialization.jsonObject(
                    with: data
                )
            } catch {
                throw TranscodingError.decodingFailed(
                    "Invalid JSON: \(error.localizedDescription)"
                )
            }

            guard let json = parsed as? [String: Any] else {
                throw TranscodingError.decodingFailed(
                    "Invalid ffprobe JSON output"
                )
            }

            let format = json["format"] as? [String: Any]
            let streams =
                json["streams"] as? [[String: Any]] ?? []

            let videoStream = streams.first {
                ($0["codec_type"] as? String) == "video"
            }
            let audioStream = streams.first {
                ($0["codec_type"] as? String) == "audio"
            }

            let duration = parseDuration(
                format: format, streams: streams
            )

            return FFmpegSourceInfo(
                duration: duration,
                hasVideoTrack: videoStream != nil,
                hasAudioTrack: audioStream != nil,
                videoResolution: parseResolution(
                    from: videoStream
                ),
                videoCodec: videoStream?["codec_name"]
                    as? String,
                videoFrameRate: parseFrameRate(
                    from: videoStream
                ),
                videoBitrate: parseBitrate(from: videoStream),
                audioCodec: audioStream?["codec_name"]
                    as? String,
                audioBitrate: parseBitrate(from: audioStream),
                audioSampleRate: parseSampleRate(
                    from: audioStream
                ),
                audioChannels: audioStream?["channels"] as? Int
            )
        }

        private static func parseDuration(
            format: [String: Any]?,
            streams: [[String: Any]]
        ) -> Double {
            if let durationStr = format?["duration"] as? String,
                let duration = Double(durationStr)
            {
                return duration
            }

            for stream in streams {
                if let durationStr = stream["duration"]
                    as? String,
                    let duration = Double(durationStr)
                {
                    return duration
                }
            }

            return 0
        }

        private static func parseResolution(
            from stream: [String: Any]?
        ) -> Resolution? {
            guard let stream,
                let width = stream["width"] as? Int,
                let height = stream["height"] as? Int
            else {
                return nil
            }
            return Resolution(width: width, height: height)
        }

        private static func parseFrameRate(
            from stream: [String: Any]?
        ) -> Double? {
            guard
                let rateStr = stream?["r_frame_rate"] as? String
            else {
                return nil
            }
            let parts = rateStr.split(separator: "/")
            guard parts.count == 2,
                let num = Double(parts[0]),
                let den = Double(parts[1]),
                den > 0
            else {
                return Double(rateStr)
            }
            return num / den
        }

        private static func parseBitrate(
            from stream: [String: Any]?
        ) -> Int? {
            if let bitrateStr = stream?["bit_rate"] as? String {
                return Int(bitrateStr)
            }
            return stream?["bit_rate"] as? Int
        }

        private static func parseSampleRate(
            from stream: [String: Any]?
        ) -> Int? {
            if let rateStr = stream?["sample_rate"] as? String {
                return Int(rateStr)
            }
            return stream?["sample_rate"] as? Int
        }
    }

    // MARK: - FFmpegSourceInfo

    /// Source information from ffprobe analysis.
    ///
    /// Contains the same kind of information as
    /// ``SourceAnalyzer/SourceInfo`` but obtained via ffprobe.
    ///
    /// - SeeAlso: ``FFmpegSourceAnalyzer``
    struct FFmpegSourceInfo: Sendable {

        /// Total duration in seconds.
        let duration: Double

        /// Whether the file contains a video track.
        let hasVideoTrack: Bool

        /// Whether the file contains an audio track.
        let hasAudioTrack: Bool

        /// Video resolution (nil if no video).
        let videoResolution: Resolution?

        /// Video codec name (e.g., "h264", "hevc").
        let videoCodec: String?

        /// Video frame rate in fps.
        let videoFrameRate: Double?

        /// Video bitrate in bits per second.
        let videoBitrate: Int?

        /// Audio codec name (e.g., "aac", "mp3").
        let audioCodec: String?

        /// Audio bitrate in bits per second.
        let audioBitrate: Int?

        /// Audio sample rate in Hz.
        let audioSampleRate: Int?

        /// Audio channel count.
        let audioChannels: Int?
    }

#endif
