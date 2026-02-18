// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("FFmpegCommandBuilder — Argument Generation")
struct FFmpegCommandBuilderTests {

    private let builder = FFmpegCommandBuilder()

    // MARK: - Video Codec

    @Test("H.264 720p generates correct video arguments")
    func h264Video720p() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p720,
            config: TranscodingConfig(audioPassthrough: false)
        )

        #expect(args.contains("-c:v"))
        #expect(args.contains("libx264"))
        #expect(args.contains("-b:v"))
        #expect(args.contains("2800k"))
        #expect(args.contains("-vf"))
        #expect(args.contains("scale=1280:720"))
        #expect(args.contains("-profile:v"))
        #expect(args.contains("high"))
        #expect(args.contains("-level"))
        #expect(args.contains("3.1"))
    }

    @Test("H.265 1080p generates libx265 with hvc1 tag")
    func h265Video1080p() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p1080,
            config: TranscodingConfig(
                videoCodec: .h265,
                audioPassthrough: false
            )
        )

        #expect(args.contains("libx265"))
        #expect(args.contains("-tag:v"))
        #expect(args.contains("hvc1"))
        #expect(args.contains("scale=1920:1080"))
    }

    @Test("Audio-only preset uses -vn flag")
    func audioOnlyNoVideo() {
        let args = builder.buildTranscodeArguments(
            input: "/in.m4a",
            output: "/out.m4a",
            preset: .audioOnly,
            config: TranscodingConfig(audioPassthrough: false)
        )

        #expect(args.contains("-vn"))
        #expect(!args.contains("-c:v"))
        #expect(!args.contains("libx264"))
    }

    // MARK: - Audio Codec

    @Test("Audio passthrough uses -c:a copy")
    func audioPassthrough() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p720,
            config: TranscodingConfig(audioPassthrough: true)
        )

        #expect(args.contains("-c:a"))
        #expect(args.contains("copy"))
        #expect(!args.contains("-b:a"))
    }

    @Test("AAC audio encoding with correct parameters")
    func aacEncoding() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p720,
            config: TranscodingConfig(audioPassthrough: false)
        )

        #expect(args.contains("-c:a"))
        #expect(args.contains("aac"))
        #expect(args.contains("-b:a"))
        #expect(args.contains("128k"))
        #expect(args.contains("-ar"))
        #expect(args.contains("44100"))
        #expect(args.contains("-ac"))
        #expect(args.contains("2"))
    }

    @Test("No audio uses -an flag")
    func noAudio() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p720,
            config: TranscodingConfig(includeAudio: false)
        )

        #expect(args.contains("-an"))
        #expect(!args.contains("-c:a"))
    }

    // MARK: - Keyframe Interval

    @Test("Keyframe interval generates correct GOP size")
    func keyframeInterval() {
        let preset = QualityPreset(
            name: "test",
            resolution: .p720,
            videoBitrate: 2_800_000,
            frameRate: 30.0,
            keyFrameInterval: 2.0
        )

        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: preset,
            config: TranscodingConfig()
        )

        #expect(args.contains("-g"))
        #expect(args.contains("60"))
        #expect(args.contains("-keyint_min"))
    }

    @Test("Custom frame rate affects GOP size")
    func customFrameRate() {
        let preset = QualityPreset(
            name: "test",
            resolution: .p720,
            videoBitrate: 2_800_000,
            frameRate: 24.0,
            keyFrameInterval: 2.0
        )

        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: preset,
            config: TranscodingConfig()
        )

        #expect(args.contains("48"))
    }

    // MARK: - Output Options

    @Test("movflags +faststart present")
    func movflags() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p720,
            config: TranscodingConfig()
        )

        #expect(args.contains("-movflags"))
        #expect(args.contains("+faststart"))
    }

    @Test("-y overwrite flag present")
    func overwriteFlag() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p720,
            config: TranscodingConfig()
        )

        #expect(args.contains("-y"))
    }

    @Test("Input and output paths in correct positions")
    func inputOutputPositions() throws {
        let args = builder.buildTranscodeArguments(
            input: "/path/to/source.mp4",
            output: "/path/to/output.mp4",
            preset: .p720,
            config: TranscodingConfig()
        )

        let inputIdx = try #require(args.firstIndex(of: "-i"))
        #expect(args[inputIdx + 1] == "/path/to/source.mp4")
        #expect(args.last == "/path/to/output.mp4")
    }

    // MARK: - Max Bitrate

    @Test("Max bitrate generates maxrate and bufsize")
    func maxBitrate() {
        let args = builder.buildTranscodeArguments(
            input: "/in.mp4",
            output: "/out.mp4",
            preset: .p720,
            config: TranscodingConfig()
        )

        #expect(args.contains("-maxrate"))
        #expect(args.contains("4200k"))
        #expect(args.contains("-bufsize"))
        #expect(args.contains("8400k"))
    }

    // MARK: - Probe Arguments

    @Test("Probe arguments contain required flags")
    func probeArguments() {
        let args = builder.buildProbeArguments(
            input: "/path/to/source.mp4"
        )

        #expect(args.contains("-v"))
        #expect(args.contains("quiet"))
        #expect(args.contains("-print_format"))
        #expect(args.contains("json"))
        #expect(args.contains("-show_format"))
        #expect(args.contains("-show_streams"))
        #expect(args.contains("/path/to/source.mp4"))
    }
}
