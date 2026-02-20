// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SendableProvider Type Erasure")
struct SendableProviderTests {

    private func makeConfig() -> ManagedTranscodingConfig {
        ManagedTestHelper.makeConfig()
    }

    @Test("SendableProvider wraps provider correctly")
    func sendableProvider() async throws {
        let mock = MockManagedProvider()
        let wrapped = SendableProvider(mock)

        #expect(SendableProvider.name == "Wrapped")

        let config = makeConfig()
        let result = try await wrapped.upload(
            fileURL: URL(fileURLWithPath: "/test.mp4"),
            config: config,
            progress: nil
        )
        #expect(result == "asset-123")
    }

    @Test("SendableProvider forwards createJob")
    func sendableProviderCreateJob() async throws {
        let mock = MockManagedProvider()
        let wrapped = SendableProvider(mock)
        let config = makeConfig()

        let job = try await wrapped.createJob(
            assetID: "asset-123",
            variants: [.p720],
            config: config
        )
        #expect(job.assetID == "asset-123")
    }

    @Test("SendableProvider forwards checkStatus")
    func sendableProviderCheckStatus() async throws {
        let mock = MockManagedProvider()
        let wrapped = SendableProvider(mock)
        let config = makeConfig()

        let job = ManagedTranscodingJob(
            jobID: "job-1", assetID: "asset-1"
        )
        let updated = try await wrapped.checkStatus(
            job: job, config: config
        )
        #expect(updated.status == .completed)
    }

    @Test("SendableProvider forwards download")
    func sendableProviderDownload() async throws {
        let mock = MockManagedProvider()
        let wrapped = SendableProvider(mock)
        let config = makeConfig()

        let job = ManagedTranscodingJob(
            jobID: "job-1", assetID: "asset-1",
            status: .completed
        )
        let files = try await wrapped.download(
            job: job,
            outputDirectory: URL(fileURLWithPath: "/out"),
            config: config,
            progress: nil
        )
        #expect(files.isEmpty)
    }

    @Test("SendableProvider forwards cleanup")
    func sendableProviderCleanup() async throws {
        let mock = MockManagedProvider()
        let wrapped = SendableProvider(mock)
        let config = makeConfig()

        let job = ManagedTranscodingJob(
            jobID: "job-1", assetID: "asset-1",
            status: .completed
        )
        try await wrapped.cleanup(
            job: job, config: config
        )
    }
}
