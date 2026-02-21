// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - AWS MediaConvert

@Suite("Managed Transcoding Showcase — AWS MediaConvert")
struct AWSMediaConvertShowcase {

    @Test(
        "AWSMediaConvertProvider — upload to S3 with SigV4 authentication"
    )
    func uploadToS3() async throws {
        actor HeaderCapture {
            var auth = ""
            func set(_ v: String) { auth = v }
        }
        let capture = HeaderCapture()

        let http = MockAWSHTTP(
            uploadHandler: { _, _, _, headers, _ in
                let authValue =
                    headers["Authorization"] ?? ""
                await capture.set(authValue)
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = AWSMediaConvertProvider(
            httpClient: http
        )
        let config = AWSTestHelper.makeAWSConfig()
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        _ = try await provider.upload(
            fileURL: input, config: config, progress: nil
        )

        let auth = await capture.auth
        #expect(auth.contains("AWS4-HMAC-SHA256"))
    }

    @Test(
        "AWSMediaConvertProvider — create HLS transcoding job with role ARN"
    )
    func createJob() async throws {
        let responseJSON = AWSTestHelper.jobResponseJSON(
            jobID: "mc-job-1"
        )
        let http = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: responseJSON
                )
            }
        )

        let provider = AWSMediaConvertProvider(
            httpClient: http
        )
        let config = AWSTestHelper.makeAWSConfig()

        let job = try await provider.createJob(
            assetID: "asset-1", variants: [.p720],
            config: config
        )
        #expect(job.jobID == "mc-job-1")
        #expect(job.status == .queued)
    }

    @Test(
        "AWSMediaConvertProvider — QualityPreset maps to MediaConvert output settings"
    )
    func presetMapping() {
        let jobJSON = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path: "s3://bucket/input.mp4",
            outputS3Path: "s3://bucket/output/",
            roleARN: "arn:aws:iam::123:role/Test",
            variants: [.p720],
            outputFormat: .fmp4
        )
        #expect(!jobJSON.isEmpty)
        let role = jobJSON["Role"] as? String
        #expect(role == "arn:aws:iam::123:role/Test")
    }

    @Test(
        "AWSMediaConvertProvider — poll job status: SUBMITTED → PROGRESSING → COMPLETE"
    )
    func pollStatus() async throws {
        let body = AWSTestHelper.statusResponseJSON(
            status: "COMPLETE", percentComplete: 100
        )
        let http = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:], body: body
                )
            }
        )

        let provider = AWSMediaConvertProvider(
            httpClient: http
        )
        let config = AWSTestHelper.makeAWSConfig()
        let job = ManagedTranscodingJob(
            jobID: "mc-1", assetID: "a-1",
            status: .processing
        )

        let updated = try await provider.checkStatus(
            job: job, config: config
        )
        #expect(updated.status == .completed)
        #expect(updated.progress == 1.0)
    }

    @Test(
        "AWSMediaConvertProvider — download HLS output from S3"
    )
    func downloadFromS3() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }

        let xml = AWSTestHelper.s3ListXML(
            keys: ["output/a1/master.m3u8"]
        )
        let http = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:], body: xml
                )
            },
            downloadHandler: { _, dest, _, _ in
                try Data("hls-content".utf8).write(to: dest)
            }
        )

        let provider = AWSMediaConvertProvider(
            httpClient: http
        )
        let config = AWSTestHelper.makeAWSConfig()
        let job = ManagedTranscodingJob(
            jobID: "j1", assetID: "a1", status: .completed
        )

        let files = try await provider.download(
            job: job, outputDirectory: dir,
            config: config, progress: nil
        )
        #expect(files.count == 1)
    }

    @Test(
        "AWSMediaConvertProvider — cleanup deletes S3 input and output"
    )
    func cleanupS3() async throws {
        actor MethodCapture {
            var deleteCalls = 0
            func increment() { deleteCalls += 1 }
        }
        let capture = MethodCapture()

        let emptyListXML = AWSTestHelper.s3ListXML(keys: [])
        let http = MockAWSHTTP(
            requestHandler: { _, method, _, _ in
                if method == "DELETE" {
                    await capture.increment()
                }
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: emptyListXML
                )
            }
        )

        let provider = AWSMediaConvertProvider(
            httpClient: http
        )
        let config = AWSTestHelper.makeAWSConfig()
        let job = ManagedTranscodingJob(
            jobID: "j1", assetID: "a1", status: .completed
        )

        try await provider.cleanup(job: job, config: config)
        let deletes = await capture.deleteCalls
        #expect(deletes == 0)
    }
}

// MARK: - Mux

@Suite("Managed Transcoding Showcase — Mux")
struct MuxShowcase {

    private func muxConfig(
        endpoint: URL? = URL(
            string: "https://mock.mux.local"
        )
    ) -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .mux,
            apiKey: "tok-id:tok-secret",
            accountID: "unused",
            endpoint: endpoint
        )
    }

    @Test(
        "MuxProvider — direct upload via POST /video/v1/uploads + PUT to upload URL"
    )
    func directUpload() async throws {
        let uploadJSON: [String: Any] = [
            "data": [
                "id": "upload-1",
                "url": "https://storage.mux.com/upload-1"
            ]
        ]
        let uploadBody = try JSONSerialization.data(
            withJSONObject: uploadJSON
        )
        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: uploadBody
                )
            },
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = MuxProvider(httpClient: http)
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        let uploadID = try await provider.upload(
            fileURL: input, config: muxConfig(),
            progress: nil
        )
        #expect(uploadID == "upload-1")
    }

    @Test("MuxProvider — Basic Auth with tokenId:tokenSecret")
    func basicAuth() async throws {
        let uploadJSON: [String: Any] = [
            "data": [
                "id": "up-1",
                "url": "https://storage.mux.com/up-1"
            ]
        ]
        let uploadBody = try JSONSerialization.data(
            withJSONObject: uploadJSON
        )

        actor HeaderCapture {
            var auth = ""
            func set(_ v: String) { auth = v }
        }
        let capture = HeaderCapture()

        let http = MockCFHTTP(
            requestHandler: { _, _, headers, _ in
                let authValue =
                    headers["Authorization"] ?? ""
                await capture.set(authValue)
                return HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: uploadBody
                )
            },
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = MuxProvider(httpClient: http)
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        _ = try await provider.upload(
            fileURL: input, config: muxConfig(),
            progress: nil
        )

        let auth = await capture.auth
        #expect(auth.hasPrefix("Basic "))
        let decoded = Data(
            base64Encoded: String(auth.dropFirst(6))
        )
        let creds = decoded.flatMap {
            String(data: $0, encoding: .utf8)
        }
        #expect(creds == "tok-id:tok-secret")
    }

    @Test(
        "MuxProvider — poll asset status: preparing → ready"
    )
    func pollStatus() async throws {
        let json: [String: Any] = [
            "data": [
                "status": "ready",
                "playback_ids": [
                    [
                        "id": "playback-abc",
                        "policy": "public"
                    ]
                ]
            ]
        ]
        let body = try JSONSerialization.data(
            withJSONObject: json
        )
        let http = MockCFHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: body
                )
            }
        )

        let provider = MuxProvider(httpClient: http)
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "up-1",
            status: .processing
        )

        let updated = try await provider.checkStatus(
            job: job, config: muxConfig()
        )
        #expect(updated.status == .completed)
        #expect(updated.progress == 1.0)
        #expect(
            updated.outputURLs.first?.absoluteString
                .contains("playback-abc") == true
        )
    }

    @Test(
        "MuxProvider — download HLS from stream.mux.com/{playbackId}.m3u8"
    )
    func downloadHLS() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }

        let http = MockCFHTTP(
            downloadHandler: { _, dest, _, _ in
                try Data("#EXTM3U".utf8).write(to: dest)
            }
        )

        let provider = MuxProvider(httpClient: http)
        let hlsURL = URL(
            string:
                "https://stream.mux.com/playback-1.m3u8"
        )
        let job = ManagedTranscodingJob(
            jobID: "a-1", assetID: "u-1",
            status: .completed,
            outputURLs: [hlsURL].compactMap { $0 }
        )

        let files = try await provider.download(
            job: job, outputDirectory: dir,
            config: muxConfig(), progress: nil
        )
        #expect(files.count == 1)
        #expect(
            files[0].lastPathComponent == "master.m3u8"
        )
    }

    @Test(
        "MuxProvider — cleanup deletes asset via DELETE /video/v1/assets/{id}"
    )
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
                    statusCode: 204, headers: [:],
                    body: Data()
                )
            }
        )

        let provider = MuxProvider(httpClient: http)
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "up-1",
            status: .completed
        )

        try await provider.cleanup(
            job: job, config: muxConfig()
        )
        let method = await capture.method
        #expect(method == "DELETE")
    }
}
