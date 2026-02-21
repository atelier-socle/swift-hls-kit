// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Cloudflare Stream

@Suite("Managed Transcoding Showcase — Cloudflare Stream")
struct CloudflareStreamShowcase {

    private func makeProvider(
        http: MockCFHTTP = MockCFHTTP()
    ) -> CloudflareStreamProvider {
        CloudflareStreamProvider(httpClient: http)
    }

    private func cfConfig(
        endpoint: URL? = URL(string: "https://mock.cf.local")
    ) -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "cf-token",
            accountID: "acct-123",
            endpoint: endpoint
        )
    }

    @Test("CloudflareStreamProvider — upload via POST to /client/v4/accounts/{id}/stream")
    func upload() async throws {
        let json: [String: Any] = [
            "result": ["uid": "video-uid-abc"]
        ]
        let body = try JSONSerialization.data(
            withJSONObject: json
        )
        let http = MockCFHTTP(
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:], body: body
                )
            }
        )

        let provider = makeProvider(http: http)
        let config = cfConfig()
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        let assetID = try await provider.upload(
            fileURL: input, config: config, progress: nil
        )
        #expect(assetID == "video-uid-abc")
    }

    @Test("CloudflareStreamProvider — API token in Authorization header")
    func authHeader() async throws {
        let json: [String: Any] = [
            "result": ["uid": "uid-1"]
        ]
        let body = try JSONSerialization.data(
            withJSONObject: json
        )

        actor HeaderCapture {
            var auth = ""
            func set(_ v: String) { auth = v }
        }
        let capture = HeaderCapture()

        let http = MockCFHTTP(
            uploadHandler: { _, _, _, headers, _ in
                let authValue = headers["Authorization"] ?? ""
                await capture.set(authValue)
                return HTTPResponse(
                    statusCode: 200, headers: [:], body: body
                )
            }
        )

        let provider = makeProvider(http: http)
        let config = cfConfig()
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        _ = try await provider.upload(
            fileURL: input, config: config, progress: nil
        )

        let auth = await capture.auth
        #expect(auth == "Bearer cf-token")
    }

    @Test("CloudflareStreamProvider — poll status until video ready")
    func pollStatus() async throws {
        let json: [String: Any] = [
            "result": [
                "uid": "vid-1",
                "status": [
                    "state": "ready",
                    "pctComplete": "100"
                ],
                "playback": [
                    "hls":
                        "https://cdn.cf.com/vid-1/manifest.m3u8"
                ]
            ]
        ]
        let body = try JSONSerialization.data(
            withJSONObject: json
        )
        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:], body: body
                )
            }
        )

        let provider = makeProvider(http: http)
        let config = cfConfig()
        let job = ManagedTranscodingJob(
            jobID: "vid-1", assetID: "vid-1",
            status: .processing
        )

        let updated = try await provider.checkStatus(
            job: job, config: config
        )
        #expect(updated.status == .completed)
        #expect(updated.progress == 1.0)
        #expect(!updated.outputURLs.isEmpty)
    }

    @Test("CloudflareStreamProvider — download HLS from delivery URL")
    func download() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }

        let http = MockCFHTTP(
            downloadHandler: { _, dest, _, _ in
                try Data("manifest".utf8).write(to: dest)
            }
        )

        let provider = makeProvider(http: http)
        let config = cfConfig()
        let hlsURL = URL(
            string: "https://cdn.cf.com/v/manifest.m3u8"
        )
        let job = ManagedTranscodingJob(
            jobID: "v", assetID: "v", status: .completed,
            outputURLs: [hlsURL].compactMap { $0 }
        )

        let files = try await provider.download(
            job: job, outputDirectory: dir,
            config: config, progress: nil
        )
        #expect(files.count == 1)
    }

    @Test("CloudflareStreamProvider — cleanup deletes video asset")
    func cleanup() async throws {
        actor MethodCapture {
            var method = ""
            func set(_ v: String) { method = v }
        }
        let capture = MethodCapture()

        let http = MockCFHTTP(
            requestHandler: { _, method, _, _ in
                await capture.set(method)
                return HTTPResponse(
                    statusCode: 200, headers: [:], body: Data()
                )
            }
        )

        let provider = makeProvider(http: http)
        let config = cfConfig()
        let job = ManagedTranscodingJob(
            jobID: "vid-1", assetID: "vid-1",
            status: .completed
        )

        try await provider.cleanup(job: job, config: config)
        let method = await capture.method
        #expect(method == "DELETE")
    }
}

// MARK: - AWS SigV4

@Suite("Managed Transcoding Showcase — AWS SigV4")
struct AWSSigV4Showcase {

    @Test(
        "AWSSignatureV4 — sign request produces Authorization + x-amz-date headers"
    )
    func signRequest() {
        let signer = AWSSignatureV4(
            accessKeyID: "AKIATEST",
            secretAccessKey: "secret123",
            region: "us-east-1",
            service: "s3"
        )

        let url = URL(
            string:
                "https://bucket.s3.us-east-1.amazonaws.com/key"
        )
        let headers = signer.sign(
            method: "GET",
            url: url ?? URL(fileURLWithPath: "/"),
            headers: [:],
            payload: nil
        )

        #expect(headers["Authorization"] != nil)
        #expect(
            headers["Authorization"]?
                .hasPrefix("AWS4-HMAC-SHA256") == true
        )
        #expect(headers["x-amz-date"] != nil)
        #expect(headers["x-amz-content-sha256"] != nil)
    }

    @Test(
        "AWSSignatureV4 — different payloads produce different signatures"
    )
    func differentPayloads() {
        let signer = AWSSignatureV4(
            accessKeyID: "AKIATEST",
            secretAccessKey: "secret123",
            region: "us-east-1",
            service: "s3"
        )

        let url = URL(
            string:
                "https://bucket.s3.us-east-1.amazonaws.com/key"
        )
        let target = url ?? URL(fileURLWithPath: "/")
        let fixedDate = Date(
            timeIntervalSince1970: 1_700_000_000
        )

        let headers1 = signer.sign(
            method: "PUT", url: target,
            headers: [:],
            payload: Data("payload-1".utf8),
            date: fixedDate
        )

        let headers2 = signer.sign(
            method: "PUT", url: target,
            headers: [:],
            payload: Data("payload-2".utf8),
            date: fixedDate
        )

        #expect(
            headers1["Authorization"]
                != headers2["Authorization"]
        )
    }
}
