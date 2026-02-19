// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("FFmpeg Coverage — Edge Cases")
    struct FFmpegEdgeCaseTests {

        // MARK: - Source Analyzer Edge Cases

        @Test("Source analyzer: unusual frame rate 60000/1001")
        func unusualFrameRate() throws {
            let json: [String: Any] = [
                "format": ["duration": "10.0"],
                "streams": [
                    [
                        "codec_type": "video",
                        "codec_name": "h264",
                        "width": 1920,
                        "height": 1080,
                        "r_frame_rate": "60000/1001",
                        "bit_rate": "5000000"
                    ] as [String: Any]
                ]
            ]
            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )
            #expect(info.videoFrameRate != nil)
            #expect(
                abs((info.videoFrameRate ?? 0) - 59.94) < 0.01
            )
        }

        @Test("Source analyzer: very large bitrate")
        func veryLargeBitrate() throws {
            let json: [String: Any] = [
                "format": ["duration": "5.0"],
                "streams": [
                    [
                        "codec_type": "video",
                        "codec_name": "prores",
                        "width": 3840,
                        "height": 2160,
                        "r_frame_rate": "24/1",
                        "bit_rate": "500000000"
                    ] as [String: Any]
                ]
            ]
            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )
            #expect(info.videoBitrate == 500_000_000)
        }

        @Test("Source analyzer: empty streams array")
        func emptyStreams() throws {
            let json: [String: Any] = [
                "format": ["duration": "10.0"],
                "streams": [] as [[String: Any]]
            ]
            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )
            #expect(!info.hasVideoTrack)
            #expect(!info.hasAudioTrack)
            #expect(info.duration == 10.0)
        }

        @Test("Source analyzer: bitrate as integer")
        func bitrateAsInteger() throws {
            let json: [String: Any] = [
                "format": ["duration": "10.0"],
                "streams": [
                    [
                        "codec_type": "audio",
                        "codec_name": "aac",
                        "bit_rate": 128_000,
                        "sample_rate": 44_100,
                        "channels": 2
                    ] as [String: Any]
                ]
            ]
            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )
            #expect(info.audioBitrate == 128_000)
            #expect(info.audioSampleRate == 44_100)
        }

        @Test("Source analyzer: sample rate as integer")
        func sampleRateAsInteger() throws {
            let json: [String: Any] = [
                "format": ["duration": "10.0"],
                "streams": [
                    [
                        "codec_type": "audio",
                        "codec_name": "aac",
                        "sample_rate": 48_000,
                        "channels": 1
                    ] as [String: Any]
                ]
            ]
            let data = try JSONSerialization.data(
                withJSONObject: json
            )
            let info = try FFmpegSourceAnalyzer.parseProbeOutput(
                data
            )
            #expect(info.audioSampleRate == 48_000)
            #expect(info.audioChannels == 1)
        }

        // MARK: - Progress Parser Edge Cases

        @Test("Parse time with high precision")
        func highPrecisionTime() {
            let line =
                "frame=1 fps=0 time=00:00:00.0167 bitrate=N/A"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time != nil)
            #expect(abs((time ?? 0) - 0.0167) < 0.001)
        }

        @Test("Parse time in middle of noisy output")
        func timeInNoisyOutput() {
            let line =
                "size=    1024kB time=00:05:30.50 bitrate=  25.3kbits/s dup=0 drop=0 speed=10.5x"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time != nil)
            #expect(abs((time ?? 0) - 330.5) < 0.01)
        }

        // MARK: - Error Extraction Edge Cases

        @Test("Extract error from single line stderr")
        func singleLineError() {
            let stderr = "Permission denied: /output/path"
            let msg =
                FFmpegProcessRunner.extractErrorMessage(
                    from: stderr
                )
            #expect(msg.contains("Permission denied"))
        }

        @Test("Extract error skips all progress lines")
        func multipleProgressLines() {
            let stderr = """
                frame=   10 fps=0 size=0kB time=00:00:00.33
                frame=   20 fps=0 size=0kB time=00:00:00.67
                frame=   30 fps=0 size=0kB time=00:00:01.00
                Conversion failed!
                """
            let msg =
                FFmpegProcessRunner.extractErrorMessage(
                    from: stderr
                )
            #expect(msg == "Conversion failed!")
        }

        // MARK: - FFmpegTranscoder Properties

        @Test("FFmpegTranscoder init with custom paths stores them")
        func initCustomPaths() {
            let transcoder = FFmpegTranscoder(
                ffmpegPath: "/custom/ffmpeg",
                ffprobePath: "/custom/ffprobe"
            )
            _ = transcoder
            #expect(FFmpegTranscoder.name == "FFmpeg")
        }

        @Test("ProcessResult stores all fields")
        func processResult() {
            let result = ProcessResult(
                exitCode: 0,
                stderr: "some warning",
                stdout: "output"
            )
            #expect(result.exitCode == 0)
            #expect(result.stderr == "some warning")
            #expect(result.stdout == "output")
        }

        // MARK: - Effective Preset Edge Cases

        @Test(
            "Effective preset with nil source bitrate uses preset"
        )
        func effectivePresetNilSourceBitrate() {
            let source = FFmpegSourceInfo(
                duration: 10.0,
                hasVideoTrack: true,
                hasAudioTrack: true,
                videoResolution: Resolution(
                    width: 640, height: 360
                ),
                videoCodec: "h264",
                videoFrameRate: 30.0,
                videoBitrate: nil,
                audioCodec: "aac",
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = FFmpegTranscoder.effectivePreset(
                .p1080, source: source
            )
            #expect(effective.resolution?.width == 640)
            #expect(
                effective.videoBitrate
                    == QualityPreset.p1080.videoBitrate
            )
        }

        @Test(
            "Effective preset: source larger keeps preset"
        )
        func effectivePresetLargerSource() {
            let source = FFmpegSourceInfo(
                duration: 10.0,
                hasVideoTrack: true,
                hasAudioTrack: true,
                videoResolution: Resolution(
                    width: 3840, height: 2160
                ),
                videoCodec: "h264",
                videoFrameRate: 30.0,
                videoBitrate: 20_000_000,
                audioCodec: "aac",
                audioBitrate: 128_000,
                audioSampleRate: 44_100,
                audioChannels: 2
            )
            let effective = FFmpegTranscoder.effectivePreset(
                .p720, source: source
            )
            #expect(effective.resolution?.width == 1280)
            #expect(effective.resolution?.height == 720)
        }
    }

#endif
