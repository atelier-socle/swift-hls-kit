// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Provider Stubs")
struct ProviderStubTests {

    private let config = ManagedTranscodingConfig(
        provider: .awsMediaConvert,
        apiKey: "key",
        accountID: "acct"
    )

    private let dummyJob = ManagedTranscodingJob(
        jobID: "j", assetID: "a"
    )

    // MARK: - AWS MediaConvert

    @Test("AWSMediaConvertProvider name")
    func awsName() {
        #expect(
            AWSMediaConvertProvider.name == "AWS MediaConvert"
        )
    }

    @Test("AWS upload throws providerNotImplemented")
    func awsUpload() async {
        let provider = AWSMediaConvertProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/test.mp4"),
                config: config,
                progress: nil
            )
        }
    }

    @Test("AWS createJob throws providerNotImplemented")
    func awsCreateJob() async {
        let provider = AWSMediaConvertProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.createJob(
                assetID: "a", variants: [.p720],
                config: config
            )
        }
    }

    @Test("AWS checkStatus throws providerNotImplemented")
    func awsCheckStatus() async {
        let provider = AWSMediaConvertProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.checkStatus(
                job: dummyJob, config: config
            )
        }
    }

    @Test("AWS download throws providerNotImplemented")
    func awsDownload() async {
        let provider = AWSMediaConvertProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.download(
                job: dummyJob,
                outputDirectory: URL(
                    fileURLWithPath: "/tmp"
                ),
                config: config,
                progress: nil
            )
        }
    }

    @Test("AWS cleanup throws providerNotImplemented")
    func awsCleanup() async {
        let provider = AWSMediaConvertProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.cleanup(
                job: dummyJob, config: config
            )
        }
    }

    // MARK: - Mux

    @Test("MuxProvider name")
    func muxName() {
        #expect(MuxProvider.name == "Mux")
    }

    @Test("Mux upload throws providerNotImplemented")
    func muxUpload() async {
        let provider = MuxProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/test.mp4"),
                config: config,
                progress: nil
            )
        }
    }

    @Test("Mux createJob throws providerNotImplemented")
    func muxCreateJob() async {
        let provider = MuxProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.createJob(
                assetID: "a", variants: [.p720],
                config: config
            )
        }
    }

    @Test("Mux checkStatus throws providerNotImplemented")
    func muxCheckStatus() async {
        let provider = MuxProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.checkStatus(
                job: dummyJob, config: config
            )
        }
    }

    @Test("Mux download throws providerNotImplemented")
    func muxDownload() async {
        let provider = MuxProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.download(
                job: dummyJob,
                outputDirectory: URL(
                    fileURLWithPath: "/tmp"
                ),
                config: config,
                progress: nil
            )
        }
    }

    @Test("Mux cleanup throws providerNotImplemented")
    func muxCleanup() async {
        let provider = MuxProvider()
        await #expect(throws: TranscodingError.self) {
            try await provider.cleanup(
                job: dummyJob, config: config
            )
        }
    }
}
