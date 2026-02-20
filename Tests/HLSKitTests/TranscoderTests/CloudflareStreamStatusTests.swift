// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CloudflareStreamProvider — Status & Download")
struct CloudflareStreamStatusTests {

    // MARK: - Helpers

    private func makeConfig() -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "test-api-key",
            accountID: "test-account-id"
        )
    }

    // MARK: - Check Status

    @Test("checkStatus returns completed for ready state")
    func checkStatusReady() async throws {
        let responseJSON: [String: Any] = [
            "success": true,
            "result": [
                "uid": "asset-1",
                "status": [
                    "state": "ready",
                    "pctComplete": "100"
                ],
                "playback": [
                    "hls":
                        "https://stream.cf.com/asset-1/manifest.m3u8"
                ]
            ]
        ]
        let data = try JSONSerialization.data(
            withJSONObject: responseJSON
        )

        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:], body: data
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "asset-1",
            status: .processing
        )

        let updated = try await provider.checkStatus(
            job: job, config: makeConfig()
        )
        #expect(updated.status == .completed)
        #expect(updated.progress == 1.0)
        #expect(updated.outputURLs.count == 1)
        #expect(updated.completedAt != nil)
    }

    @Test("checkStatus returns failed for error state")
    func checkStatusError() async throws {
        let responseJSON: [String: Any] = [
            "success": true,
            "result": [
                "uid": "asset-1",
                "status": [
                    "state": "error",
                    "errorReasonText": "Invalid codec"
                ]
            ]
        ]
        let data = try JSONSerialization.data(
            withJSONObject: responseJSON
        )

        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:], body: data
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "asset-1",
            status: .processing
        )

        let updated = try await provider.checkStatus(
            job: job, config: makeConfig()
        )
        #expect(updated.status == .failed)
        #expect(updated.errorMessage == "Invalid codec")
    }

    @Test("checkStatus returns processing for inprogress")
    func checkStatusInProgress() async throws {
        let responseJSON: [String: Any] = [
            "success": true,
            "result": [
                "uid": "asset-1",
                "status": [
                    "state": "inprogress",
                    "pctComplete": "42"
                ]
            ]
        ]
        let data = try JSONSerialization.data(
            withJSONObject: responseJSON
        )

        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:], body: data
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "asset-1",
            status: .processing
        )

        let updated = try await provider.checkStatus(
            job: job, config: makeConfig()
        )
        #expect(updated.status == .processing)
        #expect(updated.progress == 0.42)
    }

    @Test("checkStatus throws on HTTP error")
    func checkStatusHTTPError() async throws {
        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 500, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .processing
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.checkStatus(
                job: job, config: makeConfig()
            )
        }
    }

    @Test("checkStatus throws on invalid response")
    func checkStatusInvalidResponse() async throws {
        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data("{}".utf8)
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .processing
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.checkStatus(
                job: job, config: makeConfig()
            )
        }
    }

    // MARK: - Download

    @Test("Download returns file URLs")
    func downloadSuccess() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let http = MockCFHTTP(
            downloadHandler: { _, destination, _, _ in
                try Data("content".utf8).write(
                    to: destination
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let hlsURL = try #require(
            URL(
                string:
                    "https://stream.cf.com/a/manifest.m3u8"
            )
        )
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed,
            outputURLs: [hlsURL]
        )

        let files = try await provider.download(
            job: job,
            outputDirectory: tempDir,
            config: makeConfig(),
            progress: nil
        )
        #expect(files.count == 1)
    }

    @Test("Download throws when no output URLs")
    func downloadNoURLs() async throws {
        let http = MockCFHTTP()
        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed,
            outputURLs: []
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.download(
                job: job,
                outputDirectory: URL(
                    fileURLWithPath: "/tmp"
                ),
                config: makeConfig(),
                progress: nil
            )
        }
    }

    // MARK: - Cleanup

    @Test("Cleanup sends DELETE request")
    func cleanupSuccess() async throws {
        actor MethodCapture {
            var method: String?
            func set(_ m: String) { method = m }
        }
        let capture = MethodCapture()

        let http = MockCFHTTP(
            requestHandler: { _, method, _, _ in
                await capture.set(method)
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed
        )

        try await provider.cleanup(
            job: job, config: makeConfig()
        )

        let capturedMethod = await capture.method
        #expect(capturedMethod == "DELETE")
    }

    @Test("Cleanup throws on HTTP error")
    func cleanupHTTPError() async throws {
        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 404, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.cleanup(
                job: job, config: makeConfig()
            )
        }
    }
}
