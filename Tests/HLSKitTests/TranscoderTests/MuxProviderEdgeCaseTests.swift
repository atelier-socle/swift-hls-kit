// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MuxProvider — Edge Cases")
struct MuxProviderEdgeCaseTests {

    // MARK: - Helpers

    private func makeConfig() -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .mux,
            apiKey: "tokenId:tokenSecret",
            accountID: "unused"
        )
    }

    private func validUploadJSON() -> Data {
        let json: [String: Any] = [
            "data": [
                "id": "up-1",
                "url": "https://storage.test/upload"
            ]
        ]
        return
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
    }

    // MARK: - Upload Edge Cases

    @Test("upload invalid JSON response throws")
    func uploadInvalidJSON() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: Data("not json".utf8)
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        await #expect(throws: (any Error).self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/t.mp4"),
                config: self.makeConfig(), progress: nil
            )
        }
    }

    @Test("upload PUT failure throws uploadFailed")
    func uploadPUTFailure() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: self.validUploadJSON()
                )
            },
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 500, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/t.mp4"),
                config: self.makeConfig(), progress: nil
            )
        }
    }

    // MARK: - CreateJob Edge Cases

    @Test("createJob invalid JSON throws")
    func createJobInvalidJSON() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data("bad".utf8)
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        await #expect(throws: (any Error).self) {
            try await provider.createJob(
                assetID: "up-1", variants: [.p720],
                config: self.makeConfig()
            )
        }
    }

    // MARK: - CheckStatus Edge Cases

    @Test("checkStatus HTTP error throws")
    func checkStatusHTTPError() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 500, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "a-1", assetID: "u-1"
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.checkStatus(
                job: job, config: self.makeConfig()
            )
        }
    }

    @Test("checkStatus invalid JSON throws")
    func checkStatusInvalidJSON() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data("bad".utf8)
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "a-1", assetID: "u-1"
        )

        await #expect(throws: (any Error).self) {
            try await provider.checkStatus(
                job: job, config: self.makeConfig()
            )
        }
    }

    @Test("checkStatus with tracks computes progress")
    func checkStatusTracksProgress() async throws {
        let json: [String: Any] = [
            "data": [
                "id": "asset-1",
                "status": "preparing",
                "tracks": [
                    ["id": "t1", "status": "ready"],
                    ["id": "t2", "status": "preparing"]
                ]
            ]
        ]
        let body =
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()

        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: body
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "up-1"
        )

        let updated = try await provider.checkStatus(
            job: job, config: makeConfig()
        )

        #expect(updated.status == .processing)
        #expect(updated.progress == 0.5)
    }

    // MARK: - Cleanup Edge Cases

    @Test("cleanup HTTP error throws")
    func cleanupHTTPError() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 500, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "a-1", assetID: "u-1"
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.cleanup(
                job: job, config: self.makeConfig()
            )
        }
    }
}
