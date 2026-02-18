// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if canImport(AVFoundation)
    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("AppleTranscoder")
    struct AppleTranscoderTests {

        @Test("isAvailable returns true on Apple platforms")
        func isAvailable() {
            #expect(AppleTranscoder.isAvailable)
        }

        @Test("name is Apple VideoToolbox")
        func transcoderName() {
            #expect(AppleTranscoder.name == "Apple VideoToolbox")
        }

        @Test("Transcode requires valid source file")
        func transcodeInvalidSource() async {
            let transcoder = AppleTranscoder()
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            await #expect(throws: TranscodingError.self) {
                _ = try await transcoder.transcode(
                    input: URL(
                        fileURLWithPath: "/nonexistent/source.mp4"
                    ),
                    outputDirectory: outputDir,
                    config: TranscodingConfig(),
                    progress: nil
                )
            }
            try? FileManager.default.removeItem(at: outputDir)
        }

        @Test("Transcoder conforms to Transcoder protocol")
        func protocolConformance() {
            #expect(AppleTranscoder.isAvailable)
            #expect(!AppleTranscoder.name.isEmpty)
        }

        @Test("transcodeVariants requires valid source file")
        func transcodeVariantsInvalidSource() async {
            let transcoder = AppleTranscoder()
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            await #expect(throws: TranscodingError.self) {
                _ = try await transcoder.transcodeVariants(
                    input: URL(
                        fileURLWithPath: "/nonexistent/source.mp4"
                    ),
                    outputDirectory: outputDir,
                    variants: [.p720],
                    config: TranscodingConfig(),
                    progress: nil
                )
            }
            try? FileManager.default.removeItem(at: outputDir)
        }

        @Test("transcodeVariants with audioOnly preset")
        func transcodeVariantsAudioOnlyInvalidSource() async {
            let transcoder = AppleTranscoder()
            let outputDir = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            await #expect(throws: TranscodingError.self) {
                _ = try await transcoder.transcodeVariants(
                    input: URL(
                        fileURLWithPath: "/nonexistent/audio.wav"
                    ),
                    outputDirectory: outputDir,
                    variants: [.audioOnly],
                    config: TranscodingConfig(),
                    progress: nil
                )
            }
            try? FileManager.default.removeItem(at: outputDir)
        }

        @Test("Default initializer creates valid transcoder")
        func defaultInit() {
            let transcoder = AppleTranscoder()
            #expect(type(of: transcoder) == AppleTranscoder.self)
        }
    }

#endif
