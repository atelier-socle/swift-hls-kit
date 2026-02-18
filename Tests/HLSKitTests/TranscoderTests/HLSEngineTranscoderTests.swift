// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HLSEngine Transcoding")
struct HLSEngineTranscoderTests {

    @Test("isTranscoderAvailable reflects platform")
    func transcoderAvailability() {
        let engine = HLSEngine()
        #if canImport(AVFoundation)
            #expect(engine.isTranscoderAvailable)
        #else
            #expect(!engine.isTranscoderAvailable)
        #endif
    }

    #if !canImport(AVFoundation)
        @Test("transcode throws on non-Apple platforms")
        func transcodeThrowsOnLinux() async {
            let engine = HLSEngine()
            await #expect(throws: TranscodingError.self) {
                try await engine.transcode(
                    input: URL(
                        fileURLWithPath: "/input.mp4"
                    ),
                    outputDirectory: URL(
                        fileURLWithPath: "/output"
                    )
                )
            }
        }

        @Test("transcodeVariants throws on non-Apple platforms")
        func transcodeVariantsThrowsOnLinux() async {
            let engine = HLSEngine()
            await #expect(throws: TranscodingError.self) {
                try await engine.transcodeVariants(
                    input: URL(
                        fileURLWithPath: "/input.mp4"
                    ),
                    outputDirectory: URL(
                        fileURLWithPath: "/output"
                    )
                )
            }
        }
    #endif

    #if canImport(AVFoundation)
        @Test("transcode throws for non-existent source")
        func transcodeInvalidSourceApple() async {
            let engine = HLSEngine()
            await #expect(throws: TranscodingError.self) {
                try await engine.transcode(
                    input: URL(
                        fileURLWithPath: "/nonexistent/file.mp4"
                    ),
                    outputDirectory: URL(
                        fileURLWithPath: "/tmp/output"
                    )
                )
            }
        }

        @Test("transcodeVariants throws for non-existent source")
        func transcodeVariantsInvalidSourceApple() async {
            let engine = HLSEngine()
            await #expect(throws: TranscodingError.self) {
                try await engine.transcodeVariants(
                    input: URL(
                        fileURLWithPath: "/nonexistent/file.mp4"
                    ),
                    outputDirectory: URL(
                        fileURLWithPath: "/tmp/output"
                    )
                )
            }
        }
    #endif
}
