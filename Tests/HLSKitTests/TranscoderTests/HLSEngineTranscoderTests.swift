// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("HLSEngine Transcoding")
struct HLSEngineTranscoderTests {

    @Test("isTranscoderAvailable is false")
    func noTranscoderAvailable() {
        let engine = HLSEngine()
        #expect(!engine.isTranscoderAvailable)
    }

    @Test("transcode throws transcoderNotAvailable")
    func transcodeThrows() async {
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

    @Test("transcodeVariants throws transcoderNotAvailable")
    func transcodeVariantsThrows() async {
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
}
