// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AWSMediaConvertProvider — Helpers")
struct AWSMediaConvertHelperTests {

    // MARK: - S3 Key Extraction

    @Test("extractS3Keys parses XML correctly")
    func extractS3Keys() {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let xml = AWSTestHelper.s3ListXML(keys: [
            "output/abc/master.m3u8",
            "output/abc/720p/seg0.ts",
            "output/abc/720p/seg1.ts"
        ])

        let keys = provider.extractS3Keys(from: xml)
        #expect(keys.count == 3)
        #expect(keys[0] == "output/abc/master.m3u8")
    }

    @Test("extractS3Keys returns empty for invalid data")
    func extractS3KeysEmpty() {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let keys = provider.extractS3Keys(from: Data())
        #expect(keys.isEmpty)
    }

    // MARK: - Credential Parsing

    @Test("parseCredentials splits key correctly")
    func parseCredentials() throws {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let creds = try provider.parseCredentials(
            "AKIATEST:mySecretKey123"
        )
        #expect(creds.accessKeyID == "AKIATEST")
        #expect(creds.secretAccessKey == "mySecretKey123")
    }

    @Test("parseCredentials invalid format throws")
    func parseCredentialsInvalid() {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        #expect(throws: TranscodingError.self) {
            try provider.parseCredentials("noColonHere")
        }
    }

    // MARK: - Job ID Extraction

    @Test("extractJobID with invalid JSON throws")
    func extractJobIDInvalid() {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        #expect(throws: (any Error).self) {
            try provider.extractJobID(
                from: Data("bad".utf8)
            )
        }
    }

    @Test("extractJobID with missing id throws")
    func extractJobIDMissingID() {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let json: [String: Any] = ["job": ["status": "OK"]]
        let data =
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
        #expect(throws: TranscodingError.self) {
            try provider.extractJobID(from: data)
        }
    }

    // MARK: - Job Status Parsing

    @Test("parseJobStatus with invalid JSON throws")
    func parseJobStatusInvalid() {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let job = ManagedTranscodingJob(
            jobID: "j-1", assetID: "a-1"
        )
        #expect(throws: (any Error).self) {
            try provider.parseJobStatus(
                data: Data("bad".utf8), job: job
            )
        }
    }

    @Test("parseJobStatus with missing status throws")
    func parseJobStatusMissing() {
        let provider = AWSMediaConvertProvider(
            httpClient: MockAWSHTTP()
        )
        let json: [String: Any] = ["job": ["id": "j-1"]]
        let data =
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
        let job = ManagedTranscodingJob(
            jobID: "j-1", assetID: "a-1"
        )
        #expect(throws: TranscodingError.self) {
            try provider.parseJobStatus(
                data: data, job: job
            )
        }
    }

    // MARK: - S3 Operations

    @Test("listS3Objects HTTP error throws")
    func listS3ObjectsHTTPError() async {
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
        let creds = AWSCredentials(
            accessKeyID: "AKIA",
            secretAccessKey: "secret"
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.listS3Objects(
                bucket: "b", region: "us-east-1",
                prefix: "p/", credentials: creds
            )
        }
    }

    @Test("deleteS3Object HTTP error throws")
    func deleteS3ObjectHTTPError() async {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 403, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = AWSMediaConvertProvider(
            httpClient: mock
        )
        let creds = AWSCredentials(
            accessKeyID: "AKIA",
            secretAccessKey: "secret"
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.deleteS3Object(
                bucket: "b", region: "us-east-1",
                key: "k", credentials: creds
            )
        }
    }

    // MARK: - Static

    @Test("AWSMediaConvertProvider name")
    func providerName() {
        #expect(
            AWSMediaConvertProvider.name
                == "AWS MediaConvert"
        )
    }
}
