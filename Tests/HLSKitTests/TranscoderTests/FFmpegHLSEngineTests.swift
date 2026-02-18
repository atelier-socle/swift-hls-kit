// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("HLSEngine — FFmpeg Fallback")
    struct FFmpegHLSEngineTests {

        // MARK: - Transcoder Availability

        @Test("isTranscoderAvailable reflects platform state")
        func transcoderAvailable() {
            let engine = HLSEngine()
            let available = engine.isTranscoderAvailable
            // On macOS with AVFoundation, always true.
            // On Linux, depends on ffmpeg installation.
            #expect(available == true || available == false)
        }

        #if canImport(AVFoundation)

            @Test(
                "macOS prefers AppleTranscoder over FFmpeg"
            )
            func macOSPrefersApple() {
                let engine = HLSEngine()
                #expect(engine.isTranscoderAvailable)
            }

        #else

            @Test("Linux uses FFmpeg when available")
            func linuxUsesFFmpeg() {
                let engine = HLSEngine()
                if FFmpegTranscoder.isAvailable {
                    #expect(engine.isTranscoderAvailable)
                } else {
                    #expect(!engine.isTranscoderAvailable)
                }
            }

        #endif

        // MARK: - FFmpegTranscoder Properties

        @Test("FFmpegTranscoder.isAvailable matches runner")
        func ffmpegAvailabilityConsistent() {
            let fromTranscoder = FFmpegTranscoder.isAvailable
            let fromRunner = FFmpegProcessRunner.isAvailable
            #expect(fromTranscoder == fromRunner)
        }

        @Test("FFmpegTranscoder.name is FFmpeg")
        func ffmpegName() {
            #expect(FFmpegTranscoder.name == "FFmpeg")
        }

        @Test("FFmpegProcessRunner.findExecutable finds ls")
        func findLs() {
            let path = FFmpegProcessRunner.findExecutable("ls")
            #expect(path != nil)
        }
    }

#endif
