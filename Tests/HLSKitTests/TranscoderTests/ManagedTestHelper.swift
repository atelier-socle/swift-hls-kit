// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

// MARK: - Mock Provider

struct MockManagedProvider: ManagedTranscodingProvider,
    Sendable
{

    static var name: String { "Mock" }

    let uploadResult: String
    let jobResult: ManagedTranscodingJob
    let statusSequence: [ManagedTranscodingJob]
    let downloadResult: [URL]
    let shouldFailUpload: Bool
    let shouldFailJob: Bool
    let shouldFailDownload: Bool

    init(
        uploadResult: String = "asset-123",
        jobResult: ManagedTranscodingJob? = nil,
        statusSequence: [ManagedTranscodingJob]? = nil,
        downloadResult: [URL] = [],
        shouldFailUpload: Bool = false,
        shouldFailJob: Bool = false,
        shouldFailDownload: Bool = false
    ) {
        self.uploadResult = uploadResult
        let defaultJob = ManagedTranscodingJob(
            jobID: "job-123",
            assetID: "asset-123",
            status: .processing
        )
        self.jobResult = jobResult ?? defaultJob
        self.statusSequence =
            statusSequence ?? [
                ManagedTranscodingJob(
                    jobID: "job-123",
                    assetID: "asset-123",
                    status: .completed,
                    progress: 1.0,
                    completedAt: Date()
                )
            ]
        self.downloadResult = downloadResult
        self.shouldFailUpload = shouldFailUpload
        self.shouldFailJob = shouldFailJob
        self.shouldFailDownload = shouldFailDownload
    }

    func upload(
        fileURL: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> String {
        if shouldFailUpload {
            throw TranscodingError.uploadFailed(
                "Mock upload failure"
            )
        }
        progress?(0.5)
        progress?(1.0)
        return uploadResult
    }

    func createJob(
        assetID: String,
        variants: [QualityPreset],
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        if shouldFailJob {
            throw TranscodingError.jobFailed(
                "Mock job failure"
            )
        }
        return jobResult
    }

    func checkStatus(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        statusSequence.first ?? job
    }

    func download(
        job: ManagedTranscodingJob,
        outputDirectory: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> [URL] {
        if shouldFailDownload {
            throw TranscodingError.downloadFailed(
                "Mock download failure"
            )
        }
        progress?(1.0)
        return downloadResult
    }

    func cleanup(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws {}
}

// MARK: - Mock HTTP Client

struct MockManagedHTTPClient: HTTPClient, Sendable {

    func request(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> HTTPResponse {
        HTTPResponse(
            statusCode: 200, headers: [:], body: Data()
        )
    }

    func upload(
        url: URL,
        fileURL: URL,
        method: String,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> HTTPResponse {
        HTTPResponse(
            statusCode: 200, headers: [:], body: Data()
        )
    }

    func download(
        url: URL,
        to destination: URL,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws {}
}

// MARK: - Test Helpers

enum ManagedTestHelper {

    static func makeConfig(
        provider: ManagedTranscodingConfig.ProviderType =
            .cloudflareStream,
        pollingInterval: TimeInterval = 0.01,
        timeout: TimeInterval = 5,
        cleanupAfterDownload: Bool = true
    ) -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: provider,
            apiKey: "test-key",
            accountID: "test-account",
            pollingInterval: pollingInterval,
            timeout: timeout,
            cleanupAfterDownload: cleanupAfterDownload
        )
    }

    static func makeSUT(
        provider: MockManagedProvider = MockManagedProvider(),
        config: ManagedTranscodingConfig? = nil
    ) -> ManagedTranscoder {
        let cfg = config ?? makeConfig()
        return ManagedTranscoder(
            config: cfg,
            provider: provider,
            httpClient: MockManagedHTTPClient()
        )
    }

    static func makeTempDir() -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir
    }

    static func createInput(in dir: URL) throws -> URL {
        let file = dir.appendingPathComponent("input.mp4")
        try Data([0x00]).write(to: file)
        return file
    }

    static func cleanup(_ dir: URL) {
        try? FileManager.default.removeItem(at: dir)
    }
}
