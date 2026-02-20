// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ManagedTranscoder — Error Paths")
struct ManagedTranscoderErrorTests {

    // MARK: - Upload Failure

    @Test("Upload failure propagates error")
    func uploadFailure() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let provider = MockManagedProvider(
            shouldFailUpload: true
        )
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
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

    // MARK: - Job Failure

    @Test("Job creation failure propagates error")
    func jobCreationFailure() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let provider = MockManagedProvider(
            shouldFailJob: true
        )
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
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

    // MARK: - Failed Job Status

    @Test("Failed job status throws jobFailed")
    func failedJobStatus() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let failedJob = ManagedTranscodingJob(
            jobID: "job-123",
            assetID: "asset-123",
            status: .failed,
            errorMessage: "Encoding error"
        )
        let provider = MockManagedProvider(
            statusSequence: [failedJob]
        )
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
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

    // MARK: - Cancelled Job

    @Test("Cancelled job status throws cancelled")
    func cancelledJobStatus() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let cancelledJob = ManagedTranscodingJob(
            jobID: "job-123",
            assetID: "asset-123",
            status: .cancelled
        )
        let provider = MockManagedProvider(
            statusSequence: [cancelledJob]
        )
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
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

    // MARK: - Download Failure

    @Test("Download failure propagates error")
    func downloadFailure() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let provider = MockManagedProvider(
            shouldFailDownload: true
        )
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
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
