// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AWSMediaConvertProvider — Status & Download")
struct AWSMediaConvertStatusTests {

    private let dummyJob = ManagedTranscodingJob(
        jobID: "j-123", assetID: "asset-123"
    )

    // MARK: - Check Status

    @Test("checkStatus maps SUBMITTED to processing")
    func statusSubmitted() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.statusResponseJSON(
                        status: "SUBMITTED"
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        let updated = try await provider.checkStatus(
            job: dummyJob, config: config
        )

        #expect(updated.status == .processing)
    }

    @Test("checkStatus maps PROGRESSING with progress")
    func statusProgressing() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.statusResponseJSON(
                        status: "PROGRESSING",
                        percentComplete: 42
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        let updated = try await provider.checkStatus(
            job: dummyJob, config: config
        )

        #expect(updated.status == .processing)
        #expect(updated.progress == 0.42)
    }

    @Test("checkStatus maps COMPLETE to completed")
    func statusComplete() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.statusResponseJSON(
                        status: "COMPLETE",
                        percentComplete: 100
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        let updated = try await provider.checkStatus(
            job: dummyJob, config: config
        )

        #expect(updated.status == .completed)
        #expect(updated.progress == 1.0)
        #expect(updated.completedAt != nil)
    }

    @Test("checkStatus maps ERROR to failed")
    func statusError() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.statusResponseJSON(
                        status: "ERROR",
                        errorMessage: "Codec error"
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        let updated = try await provider.checkStatus(
            job: dummyJob, config: config
        )

        #expect(updated.status == .failed)
        #expect(updated.errorMessage == "Codec error")
    }

    @Test("checkStatus maps CANCELED to cancelled")
    func statusCanceled() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.statusResponseJSON(
                        status: "CANCELED"
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        let updated = try await provider.checkStatus(
            job: dummyJob, config: config
        )

        #expect(updated.status == .cancelled)
    }

    @Test("checkStatus HTTP error throws jobFailed")
    func statusHTTPError() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 500, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        await #expect(throws: TranscodingError.self) {
            try await provider.checkStatus(
                job: dummyJob, config: config
            )
        }
    }

    // MARK: - Download

    @Test("download lists S3 objects and downloads")
    func downloadListsAndDownloads() async throws {
        actor Counter {
            var count = 0
            func inc() { count += 1 }
        }
        let counter = Counter()
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.s3ListXML(keys: [
                        "output/asset-123/master.m3u8",
                        "output/asset-123/720p.m3u8"
                    ])
                )
            },
            downloadHandler: { _, _, _, _ in
                await counter.inc()
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let files = try await provider.download(
            job: dummyJob, outputDirectory: tempDir,
            config: config, progress: nil
        )

        #expect(files.count == 2)
        let count = await counter.count
        #expect(count == 2)
    }

    @Test("download returns local file URLs")
    func downloadReturnsLocalURLs() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.s3ListXML(keys: [
                        "output/asset-123/master.m3u8"
                    ])
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let files = try await provider.download(
            job: dummyJob, outputDirectory: tempDir,
            config: config, progress: nil
        )

        let first = try #require(files.first)
        #expect(
            first.lastPathComponent == "master.m3u8"
        )
        #expect(first.path.contains(tempDir.path))
    }

    @Test("download empty S3 list throws error")
    func downloadEmptyList() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.s3ListXML(
                        keys: []
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        await #expect(throws: TranscodingError.self) {
            try await provider.download(
                job: dummyJob,
                outputDirectory: URL(
                    fileURLWithPath: "/tmp"
                ),
                config: config, progress: nil
            )
        }
    }

    // MARK: - Cleanup

    @Test("cleanup deletes S3 objects")
    func cleanupDeletes() async throws {
        actor Counter {
            var count = 0
            func inc() { count += 1 }
        }
        let counter = Counter()
        let mock = MockAWSHTTP(
            requestHandler: { _, method, _, _ in
                if method == "DELETE" {
                    await counter.inc()
                    return HTTPResponse(
                        statusCode: 204, headers: [:],
                        body: Data()
                    )
                }
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: AWSTestHelper.s3ListXML(
                        keys: ["some/key.mp4"]
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        try await provider.cleanup(
            job: dummyJob, config: config
        )

        let count = await counter.count
        #expect(count >= 2)
    }
}
