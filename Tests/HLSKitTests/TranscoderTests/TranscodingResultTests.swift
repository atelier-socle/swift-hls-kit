// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TranscodingResult")
struct TranscodingResultTests {

    // MARK: - Speed Factor

    @Test("speedFactor calculation")
    func speedFactor() {
        let result = makeResult(
            transcodingDuration: 10.0,
            sourceDuration: 25.0
        )
        #expect(result.speedFactor == 2.5)
    }

    @Test("speedFactor with zero transcoding duration")
    func speedFactorZero() {
        let result = makeResult(
            transcodingDuration: 0,
            sourceDuration: 10.0
        )
        #expect(result.speedFactor == 0)
    }

    // MARK: - Nil Segmentation

    @Test("Result with nil segmentation")
    func nilSegmentation() {
        let result = makeResult()
        #expect(result.segmentation == nil)
        #expect(result.outputFile == nil)
    }

    // MARK: - MultiVariantResult

    @Test("totalTranscodingDuration sums all variants")
    func totalDuration() {
        let r1 = makeResult(
            transcodingDuration: 10.0,
            sourceDuration: 30.0,
            outputSize: 100
        )
        let r2 = makeResult(
            transcodingDuration: 15.0,
            sourceDuration: 30.0,
            outputSize: 200
        )
        let multi = MultiVariantResult(
            variants: [r1, r2],
            masterPlaylist: nil,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(multi.totalTranscodingDuration == 25.0)
    }

    @Test("totalOutputSize sums all variants")
    func totalSize() {
        let r1 = makeResult(outputSize: 1000)
        let r2 = makeResult(outputSize: 2000)
        let r3 = makeResult(outputSize: 3000)
        let multi = MultiVariantResult(
            variants: [r1, r2, r3],
            masterPlaylist: "#EXTM3U\n",
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(multi.totalOutputSize == 6000)
    }

    @Test("MultiVariantResult with empty variants")
    func emptyVariants() {
        let multi = MultiVariantResult(
            variants: [],
            masterPlaylist: nil,
            outputDirectory: URL(fileURLWithPath: "/tmp")
        )
        #expect(multi.totalTranscodingDuration == 0)
        #expect(multi.totalOutputSize == 0)
    }

    // MARK: - Helpers

    private func makeResult(
        transcodingDuration: Double = 5.0,
        sourceDuration: Double = 10.0,
        outputSize: UInt64 = 500
    ) -> TranscodingResult {
        TranscodingResult(
            preset: .p720,
            outputDirectory: URL(fileURLWithPath: "/tmp"),
            transcodingDuration: transcodingDuration,
            sourceDuration: sourceDuration,
            outputSize: outputSize
        )
    }
}
