// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("FFmpegSourceAnalyzer — JSON Parsing")
    struct FFmpegSourceAnalyzerTests {

        // MARK: - Video + Audio

        @Test("Parse video+audio JSON produces correct info")
        func parseVideoAudio() throws {
            let json = makeJSON(
                duration: "125.432",
                videoStream: makeVideoStream(
                    codec: "h264",
                    width: 1920,
                    height: 1080,
                    frameRate: "30/1",
                    bitrate: "3000000"
                ),
                audioStream: makeAudioStream(
                    codec: "aac",
                    sampleRate: "44100",
                    channels: 2,
                    bitrate: "128000"
                )
            )

            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )

            #expect(abs(info.duration - 125.432) < 0.001)
            #expect(info.hasVideoTrack)
            #expect(info.hasAudioTrack)
            #expect(info.videoResolution?.width == 1920)
            #expect(info.videoResolution?.height == 1080)
            #expect(info.videoCodec == "h264")
            #expect(info.videoFrameRate != nil)
            #expect(abs((info.videoFrameRate ?? 0) - 30.0) < 0.01)
            #expect(info.videoBitrate == 3_000_000)
            #expect(info.audioCodec == "aac")
            #expect(info.audioBitrate == 128_000)
            #expect(info.audioSampleRate == 44_100)
            #expect(info.audioChannels == 2)
        }

        // MARK: - Audio-Only

        @Test("Parse audio-only JSON has no video track")
        func parseAudioOnly() throws {
            let json = makeJSON(
                duration: "300.0",
                videoStream: nil,
                audioStream: makeAudioStream(
                    codec: "aac",
                    sampleRate: "48000",
                    channels: 2,
                    bitrate: "192000"
                )
            )

            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )

            #expect(!info.hasVideoTrack)
            #expect(info.hasAudioTrack)
            #expect(info.videoResolution == nil)
            #expect(info.videoCodec == nil)
            #expect(info.audioCodec == "aac")
            #expect(info.audioSampleRate == 48_000)
        }

        // MARK: - Video-Only

        @Test("Parse video-only JSON has no audio track")
        func parseVideoOnly() throws {
            let json = makeJSON(
                duration: "60.0",
                videoStream: makeVideoStream(
                    codec: "hevc",
                    width: 3840,
                    height: 2160,
                    frameRate: "24000/1001",
                    bitrate: "10000000"
                ),
                audioStream: nil
            )

            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )

            #expect(info.hasVideoTrack)
            #expect(!info.hasAudioTrack)
            #expect(info.videoResolution?.width == 3840)
            #expect(info.videoResolution?.height == 2160)
            #expect(info.audioCodec == nil)
        }

        // MARK: - Frame Rate Parsing

        @Test("Parse frame rate 30/1 → 30.0")
        func parseFrameRate30() throws {
            let json = makeJSON(
                duration: "10.0",
                videoStream: makeVideoStream(
                    codec: "h264",
                    width: 1280,
                    height: 720,
                    frameRate: "30/1",
                    bitrate: "2000000"
                ),
                audioStream: nil
            )

            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )

            #expect(info.videoFrameRate != nil)
            #expect(
                abs((info.videoFrameRate ?? 0) - 30.0) < 0.01
            )
        }

        @Test("Parse frame rate 24000/1001 → 23.976")
        func parseFrameRate23976() throws {
            let json = makeJSON(
                duration: "10.0",
                videoStream: makeVideoStream(
                    codec: "h264",
                    width: 1920,
                    height: 1080,
                    frameRate: "24000/1001",
                    bitrate: "5000000"
                ),
                audioStream: nil
            )

            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )

            #expect(info.videoFrameRate != nil)
            #expect(
                abs((info.videoFrameRate ?? 0) - 23.976) < 0.01
            )
        }

        // MARK: - Missing Fields

        @Test("Missing fields produce graceful nil handling")
        func missingFields() throws {
            let json: [String: Any] = [
                "format": ["duration": "10.0"],
                "streams": [
                    [
                        "codec_type": "video",
                        "codec_name": "h264"
                    ] as [String: Any]
                ]
            ]

            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )

            #expect(info.hasVideoTrack)
            #expect(info.videoResolution == nil)
            #expect(info.videoFrameRate == nil)
            #expect(info.videoBitrate == nil)
        }

        // MARK: - Invalid JSON

        @Test("Invalid JSON throws decodingFailed")
        func invalidJSON() {
            let data = Data("not json".utf8)
            #expect(throws: TranscodingError.self) {
                try FFmpegSourceAnalyzer.parseProbeOutput(data)
            }
        }

        @Test("Non-dictionary JSON throws decodingFailed")
        func nonDictionaryJSON() throws {
            let data = try JSONSerialization.data(
                withJSONObject: [1, 2, 3]
            )
            #expect(throws: TranscodingError.self) {
                try FFmpegSourceAnalyzer.parseProbeOutput(data)
            }
        }

        // MARK: - Duration Fallback

        @Test("Duration falls back to stream duration")
        func durationFallback() throws {
            let json: [String: Any] = [
                "format": [:] as [String: Any],
                "streams": [
                    [
                        "codec_type": "audio",
                        "codec_name": "aac",
                        "duration": "45.5"
                    ] as [String: Any]
                ]
            ]

            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )

            #expect(abs(info.duration - 45.5) < 0.01)
        }

        // MARK: - Helpers

        private func makeJSON(
            duration: String,
            videoStream: [String: Any]?,
            audioStream: [String: Any]?
        ) -> [String: Any] {
            var streams: [[String: Any]] = []
            if let video = videoStream {
                streams.append(video)
            }
            if let audio = audioStream {
                streams.append(audio)
            }
            return [
                "format": ["duration": duration],
                "streams": streams
            ]
        }

        private func makeVideoStream(
            codec: String,
            width: Int,
            height: Int,
            frameRate: String,
            bitrate: String
        ) -> [String: Any] {
            [
                "codec_type": "video",
                "codec_name": codec,
                "width": width,
                "height": height,
                "r_frame_rate": frameRate,
                "bit_rate": bitrate
            ]
        }

        private func makeAudioStream(
            codec: String,
            sampleRate: String,
            channels: Int,
            bitrate: String
        ) -> [String: Any] {
            [
                "codec_type": "audio",
                "codec_name": codec,
                "sample_rate": sampleRate,
                "channels": channels,
                "bit_rate": bitrate
            ]
        }
    }

#endif
