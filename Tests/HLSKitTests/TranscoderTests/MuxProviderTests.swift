// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MuxProvider — Upload & Job")
struct MuxProviderTests {

    // MARK: - Helpers

    private func makeConfig(
        endpoint: URL? = nil
    ) -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .mux,
            apiKey: "tokenId:tokenSecret",
            accountID: "unused",
            endpoint: endpoint
        )
    }

    private func muxUploadResponseJSON(
        uploadID: String,
        uploadURL: String
    ) -> Data {
        let json: [String: Any] = [
            "data": [
                "id": uploadID,
                "url": uploadURL
            ]
        ]
        return
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
    }

    private func muxUploadStatusJSON(
        assetID: String
    ) -> Data {
        let json: [String: Any] = [
            "data": [
                "id": "upload-1",
                "asset_id": assetID
            ]
        ]
        return
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
    }

    // MARK: - Upload

    @Test("upload POST creates direct upload")
    func uploadCreatesDirectUpload() async throws {
        actor Capture {
            var url = ""
            func set(_ v: String) { url = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            requestHandler: { url, _, _, _ in
                await cap.set(url.absoluteString)
                return HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: self.muxUploadResponseJSON(
                        uploadID: "up-123",
                        uploadURL: "https://storage.test/up"
                    )
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        let uploadID = try await provider.upload(
            fileURL: URL(fileURLWithPath: "/test.mp4"),
            config: makeConfig(), progress: nil
        )

        let url = await cap.url
        #expect(url.contains("video/v1/uploads"))
        #expect(uploadID == "up-123")
    }

    @Test("upload uses Basic auth")
    func uploadBasicAuth() async throws {
        actor Capture {
            var auth = ""
            func set(_ v: String) { auth = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            requestHandler: { _, _, headers, _ in
                let a = headers["Authorization"] ?? ""
                await cap.set(a)
                return HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: self.muxUploadResponseJSON(
                        uploadID: "up-1",
                        uploadURL: "https://s.test/up"
                    )
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        _ = try await provider.upload(
            fileURL: URL(fileURLWithPath: "/test.mp4"),
            config: makeConfig(), progress: nil
        )

        let auth = await cap.auth
        #expect(auth.hasPrefix("Basic "))
        let encoded = Data(
            "tokenId:tokenSecret".utf8
        ).base64EncodedString()
        #expect(auth == "Basic \(encoded)")
    }

    @Test("upload PUT file to returned URL")
    func uploadPutsFile() async throws {
        actor Capture {
            var url = ""
            func set(_ v: String) { url = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: self.muxUploadResponseJSON(
                        uploadID: "up-1",
                        uploadURL: "https://store.test/file"
                    )
                )
            },
            uploadHandler: { url, _, _, _, _ in
                await cap.set(url.absoluteString)
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        _ = try await provider.upload(
            fileURL: URL(fileURLWithPath: "/test.mp4"),
            config: makeConfig(), progress: nil
        )

        let url = await cap.url
        #expect(url == "https://store.test/file")
    }

    @Test("upload HTTP error throws uploadFailed")
    func uploadHTTPError() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 401, headers: [:],
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

    // MARK: - Create Job

    @Test("createJob retrieves asset_id from upload")
    func createJobGetsAssetID() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: self.muxUploadStatusJSON(
                        assetID: "asset-xyz"
                    )
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        let job = try await provider.createJob(
            assetID: "upload-1", variants: [.p720],
            config: makeConfig()
        )

        #expect(job.jobID == "asset-xyz")
        #expect(job.assetID == "upload-1")
        #expect(job.status == .processing)
    }

    @Test("createJob HTTP error throws jobFailed")
    func createJobHTTPError() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 500, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)

        await #expect(throws: TranscodingError.self) {
            try await provider.createJob(
                assetID: "up-1", variants: [.p720],
                config: self.makeConfig()
            )
        }
    }
}
