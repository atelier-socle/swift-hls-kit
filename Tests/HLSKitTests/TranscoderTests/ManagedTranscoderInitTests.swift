// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ManagedTranscoder — Init & Timeout")
struct ManagedTranscoderInitTests {

    // MARK: - Public Init

    @Test("init with cloudflareStream provider")
    func initCloudflare() {
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "key",
            accountID: "acc"
        )
        let sut = ManagedTranscoder(config: config)
        #expect(type(of: sut) == ManagedTranscoder.self)
    }

    @Test("init with awsMediaConvert provider")
    func initAWS() {
        let config = ManagedTranscodingConfig(
            provider: .awsMediaConvert,
            apiKey: "AKIA:secret",
            accountID: "123456",
            region: "us-east-1",
            storageBucket: "bucket",
            roleARN: "arn:aws:iam::123:role/R"
        )
        let sut = ManagedTranscoder(config: config)
        #expect(type(of: sut) == ManagedTranscoder.self)
    }

    @Test("init with mux provider")
    func initMux() {
        let config = ManagedTranscodingConfig(
            provider: .mux,
            apiKey: "tokenId:tokenSecret",
            accountID: "unused"
        )
        let sut = ManagedTranscoder(config: config)
        #expect(type(of: sut) == ManagedTranscoder.self)
    }

    // MARK: - Polling Timeout

    @Test(
        "polling timeout throws after deadline",
        .timeLimit(.minutes(1))
    )
    func pollingTimeout() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )

        let processingJob = ManagedTranscodingJob(
            jobID: "j-1", assetID: "a-1",
            status: .processing
        )
        let provider = MockManagedProvider(
            statusSequence: [processingJob]
        )
        let config = ManagedTestHelper.makeConfig(
            pollingInterval: 0.01,
            timeout: 0.05
        )
        let sut = ManagedTranscoder(
            config: config,
            provider: provider,
            httpClient: MockManagedHTTPClient()
        )

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: inputFile,
                outputDirectory:
                    tempDir
                    .appendingPathComponent("output"),
                config: TranscodingConfig(),
                progress: nil
            )
        }
    }
}
