// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CloudflareStreamProvider — Upload & Job")
struct CloudflareStreamProviderTests {

    // MARK: - Helpers

    private func makeConfig(
        endpoint: URL? = nil
    ) -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "test-api-key",
            accountID: "test-account-id",
            endpoint: endpoint
        )
    }

    // MARK: - Static Properties

    @Test("Name is Cloudflare Stream")
    func name() {
        #expect(
            CloudflareStreamProvider.name
                == "Cloudflare Stream"
        )
    }

    // MARK: - Upload

    @Test("Upload returns asset ID from response")
    func uploadSuccess() async throws {
        let responseJSON: [String: Any] = [
            "success": true,
            "result": ["uid": "cf-asset-456"]
        ]
        let responseData = try JSONSerialization.data(
            withJSONObject: responseJSON
        )

        let http = MockCFHTTP(
            uploadHandler: { _, _, _, _, progress in
                progress?(1.0)
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: responseData
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        let assetID = try await provider.upload(
            fileURL: URL(fileURLWithPath: "/test.mp4"),
            config: makeConfig(),
            progress: nil
        )
        #expect(assetID == "cf-asset-456")
    }

    @Test("Upload throws on HTTP error")
    func uploadHTTPError() async throws {
        let http = MockCFHTTP(
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 403, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/test.mp4"),
                config: makeConfig(),
                progress: nil
            )
        }
    }

    @Test("Upload throws on invalid JSON response")
    func uploadInvalidJSON() async throws {
        let http = MockCFHTTP(
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data("not json".utf8)
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )

        await #expect(throws: (any Error).self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/test.mp4"),
                config: makeConfig(),
                progress: nil
            )
        }
    }

    @Test("Upload throws on missing uid in response")
    func uploadMissingUID() async throws {
        let responseJSON: [String: Any] = [
            "success": true,
            "result": ["name": "no-uid-here"]
        ]
        let responseData = try JSONSerialization.data(
            withJSONObject: responseJSON
        )

        let http = MockCFHTTP(
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: responseData
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/test.mp4"),
                config: makeConfig(),
                progress: nil
            )
        }
    }

    @Test("Upload uses custom endpoint")
    func uploadCustomEndpoint() async throws {
        let customURL = try #require(
            URL(string: "https://custom.cf.test/v4")
        )
        let responseJSON: [String: Any] = [
            "success": true,
            "result": ["uid": "custom-asset"]
        ]
        let responseData = try JSONSerialization.data(
            withJSONObject: responseJSON
        )

        actor URLCapture {
            var capturedURL: URL?
            func set(_ url: URL) { capturedURL = url }
        }
        let capture = URLCapture()

        let http = MockCFHTTP(
            uploadHandler: { url, _, _, _, _ in
                await capture.set(url)
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: responseData
                )
            }
        )

        let provider = CloudflareStreamProvider(
            httpClient: http
        )
        _ = try await provider.upload(
            fileURL: URL(fileURLWithPath: "/test.mp4"),
            config: makeConfig(endpoint: customURL),
            progress: nil
        )

        let captured = await capture.capturedURL
        #expect(
            captured?.absoluteString.hasPrefix(
                "https://custom.cf.test/v4"
            ) == true
        )
    }

    // MARK: - Create Job

    @Test("createJob returns processing job")
    func createJob() async throws {
        let http = MockCFHTTP()
        let provider = CloudflareStreamProvider(
            httpClient: http
        )

        let job = try await provider.createJob(
            assetID: "asset-789",
            variants: [.p720],
            config: makeConfig()
        )
        #expect(job.jobID == "asset-789")
        #expect(job.assetID == "asset-789")
        #expect(job.status == .processing)
    }
}
