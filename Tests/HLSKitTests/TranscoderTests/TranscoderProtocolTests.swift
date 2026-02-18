// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Transcoder Protocol")
struct TranscoderProtocolTests {

    // MARK: - Progress Collector

    actor ProgressActor {
        var values: [Double] = []
        func append(_ value: Double) {
            values.append(value)
        }
    }

    // MARK: - Mock Transcoder

    struct MockTranscoder: Transcoder {
        static var isAvailable: Bool { true }
        static var name: String { "MockTranscoder" }

        let progressActor: ProgressActor?

        init(progressActor: ProgressActor? = nil) {
            self.progressActor = progressActor
        }

        func transcode(
            input: URL,
            outputDirectory: URL,
            config: TranscodingConfig,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> TranscodingResult {
            progress?(0.5)
            if let actor = progressActor {
                await actor.append(0.5)
            }
            progress?(1.0)
            if let actor = progressActor {
                await actor.append(1.0)
            }
            return TranscodingResult(
                preset: .p720,
                outputDirectory: outputDirectory,
                transcodingDuration: 1.0,
                sourceDuration: 10.0,
                outputSize: 1024
            )
        }
    }

    // MARK: - Tests

    @Test("Mock transcoder conforms to protocol")
    func conformance() {
        #expect(MockTranscoder.isAvailable)
        #expect(MockTranscoder.name == "MockTranscoder")
    }

    @Test("Mock transcode returns expected result")
    func transcodeResult() async throws {
        let mock = MockTranscoder()
        let result = try await mock.transcode(
            input: URL(fileURLWithPath: "/input.mp4"),
            outputDirectory: URL(
                fileURLWithPath: "/output"
            ),
            config: TranscodingConfig(),
            progress: nil
        )
        #expect(result.preset == .p720)
        #expect(result.sourceDuration == 10.0)
        #expect(result.outputSize == 1024)
    }

    @Test("Mock transcode calls progress callback")
    func progressReporting() async throws {
        let actor = ProgressActor()
        let mock = MockTranscoder(progressActor: actor)
        let result = try await mock.transcode(
            input: URL(fileURLWithPath: "/input.mp4"),
            outputDirectory: URL(
                fileURLWithPath: "/output"
            ),
            config: TranscodingConfig(),
            progress: { _ in }
        )
        let values = await actor.values
        #expect(values == [0.5, 1.0])
        #expect(result.speedFactor == 10.0)
    }

    @Test("Default transcodeVariants uses sequential impl")
    func defaultTranscodeVariants() async throws {
        let mock = MockTranscoder()
        let result = try await mock.transcodeVariants(
            input: URL(fileURLWithPath: "/input.mp4"),
            outputDirectory: URL(
                fileURLWithPath: "/output"
            ),
            variants: [.p360, .p720],
            config: TranscodingConfig(),
            progress: nil
        )
        #expect(result.variants.count == 2)
        #expect(result.masterPlaylist != nil)
    }
}
