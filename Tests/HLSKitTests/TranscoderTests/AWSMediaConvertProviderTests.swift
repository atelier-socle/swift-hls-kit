// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AWSMediaConvertProvider — Upload & CreateJob")
struct AWSMediaConvertProviderTests {

    // MARK: - Upload

    @Test("upload PUT to S3 with correct path")
    func uploadS3Path() async throws {
        actor Capture {
            var url = ""
            func set(_ v: String) { url = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            uploadHandler: { url, _, _, _, _ in
                await cap.set(url.absoluteString)
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }
        let input = try ManagedTestHelper.createInput(
            in: tempDir
        )

        let assetID = try await provider.upload(
            fileURL: input, config: config, progress: nil
        )

        let url = await cap.url
        #expect(
            url.contains(
                "test-bucket.s3.us-east-1.amazonaws.com"
            )
        )
        #expect(url.contains("input/\(assetID)/source.mp4"))
    }

    @Test("upload includes AWS auth headers")
    func uploadAuthHeaders() async throws {
        actor Capture {
            var headers: [String: String] = [:]
            func set(_ v: [String: String]) { headers = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            uploadHandler: { _, _, _, headers, _ in
                await cap.set(headers)
                return HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }
        let input = try ManagedTestHelper.createInput(
            in: tempDir
        )

        _ = try await provider.upload(
            fileURL: input, config: config, progress: nil
        )

        let headers = await cap.headers
        #expect(headers["Authorization"] != nil)
        #expect(headers["x-amz-date"] != nil)
        #expect(headers["x-amz-content-sha256"] != nil)
    }

    @Test("upload returns asset ID")
    func uploadReturnsAssetID() async throws {
        let mock = MockAWSHTTP()
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }
        let input = try ManagedTestHelper.createInput(
            in: tempDir
        )

        let assetID = try await provider.upload(
            fileURL: input, config: config, progress: nil
        )

        #expect(!assetID.isEmpty)
    }

    @Test("upload missing region throws error")
    func uploadMissingRegion() async {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let config = AWSTestHelper.makeAWSConfig(
            region: nil
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/test.mp4"),
                config: config, progress: nil
            )
        }
    }

    @Test("upload missing storageBucket throws error")
    func uploadMissingBucket() async {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let config = AWSTestHelper.makeAWSConfig(
            bucket: nil
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: URL(fileURLWithPath: "/test.mp4"),
                config: config, progress: nil
            )
        }
    }

    @Test("upload S3 error throws uploadFailed")
    func uploadS3Error() async throws {
        let mock = MockAWSHTTP(
            uploadHandler: { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 403, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }
        let input = try ManagedTestHelper.createInput(
            in: tempDir
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.upload(
                fileURL: input, config: config,
                progress: nil
            )
        }
    }

    // MARK: - Create Job

    @Test("createJob POST to MediaConvert endpoint")
    func createJobEndpoint() async throws {
        let endpoint = try #require(
            URL(
                string:
                    "https://mc.us-east-1.amazonaws.com"
            )
        )
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
                    body: AWSTestHelper.jobResponseJSON(
                        jobID: "j-123"
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig(
            endpoint: endpoint
        )

        _ = try await provider.createJob(
            assetID: "asset-1", variants: [.p720],
            config: config
        )

        let url = await cap.url
        #expect(
            url.contains("mc.us-east-1.amazonaws.com")
        )
        #expect(url.contains("2017-08-29/jobs"))
    }

    @Test("createJob returns job with queued status")
    func createJobStatus() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: AWSTestHelper.jobResponseJSON(
                        jobID: "j-456"
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig()

        let job = try await provider.createJob(
            assetID: "asset-1", variants: [.p720],
            config: config
        )

        #expect(job.jobID == "j-456")
        #expect(job.assetID == "asset-1")
        #expect(job.status == .queued)
    }

    @Test("createJob includes IAM role ARN")
    func createJobRoleARN() async throws {
        actor Capture {
            var body: Data?
            func set(_ v: Data?) { body = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, body in
                await cap.set(body)
                return HTTPResponse(
                    statusCode: 201, headers: [:],
                    body: AWSTestHelper.jobResponseJSON(
                        jobID: "j-1"
                    )
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let config = AWSTestHelper.makeAWSConfig(
            roleARN: "arn:aws:iam::999:role/MyRole"
        )

        _ = try await provider.createJob(
            assetID: "a", variants: [.p720],
            config: config
        )

        let bodyData = try #require(await cap.body)
        let json =
            try JSONSerialization.jsonObject(
                with: bodyData
            ) as? [String: Any]
        let role = json?["Role"] as? String
        #expect(role == "arn:aws:iam::999:role/MyRole")
    }

    @Test("createJob missing roleARN throws error")
    func createJobMissingRole() async {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let config = AWSTestHelper.makeAWSConfig(
            roleARN: nil
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.createJob(
                assetID: "a", variants: [.p720],
                config: config
            )
        }
    }
}
