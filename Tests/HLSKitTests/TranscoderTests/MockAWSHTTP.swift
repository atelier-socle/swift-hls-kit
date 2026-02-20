// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Mock HTTP client for AWS provider tests.
struct MockAWSHTTP: HTTPClient, Sendable {

    let requestHandler: @Sendable (URL, String, [String: String], Data?) async throws -> HTTPResponse
    let uploadHandler: @Sendable (URL, URL, String, [String: String], (@Sendable (Double) -> Void)?) async throws -> HTTPResponse
    let downloadHandler: @Sendable (URL, URL, [String: String], (@Sendable (Double) -> Void)?) async throws -> Void

    init(
        requestHandler: @escaping @Sendable (URL, String, [String: String], Data?) async throws -> HTTPResponse = { _, _, _, _ in
            HTTPResponse(
                statusCode: 200, headers: [:],
                body: Data()
            )
        },
        uploadHandler:
            @escaping @Sendable (
                URL, URL, String, [String: String],
                (@Sendable (Double) -> Void)?
            ) async throws -> HTTPResponse = { _, _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: Data()
                )
            },
        downloadHandler: @escaping @Sendable (URL, URL, [String: String], (@Sendable (Double) -> Void)?) async throws -> Void = { _, _, _, _ in }
    ) {
        self.requestHandler = requestHandler
        self.uploadHandler = uploadHandler
        self.downloadHandler = downloadHandler
    }

    func request(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> HTTPResponse {
        try await requestHandler(url, method, headers, body)
    }

    func upload(
        url: URL,
        fileURL: URL,
        method: String,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> HTTPResponse {
        try await uploadHandler(
            url, fileURL, method, headers, progress
        )
    }

    func download(
        url: URL,
        to destination: URL,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        try await downloadHandler(
            url, destination, headers, progress
        )
    }
}

// MARK: - AWS Test Helpers

enum AWSTestHelper {

    static func makeAWSConfig(
        region: String? = "us-east-1",
        bucket: String? = "test-bucket",
        roleARN: String? = "arn:aws:iam::123:role/Test",
        endpoint: URL? = nil
    ) -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .awsMediaConvert,
            apiKey: "AKIATEST:secretkey123",
            accountID: "123456789012",
            endpoint: endpoint,
            region: region,
            storageBucket: bucket,
            roleARN: roleARN
        )
    }

    static func jobResponseJSON(
        jobID: String
    ) -> Data {
        let json: [String: Any] = [
            "job": [
                "id": jobID,
                "status": "SUBMITTED"
            ]
        ]
        return
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
    }

    static func statusResponseJSON(
        status: String,
        percentComplete: Int = 0,
        errorMessage: String? = nil
    ) -> Data {
        var jobData: [String: Any] = [
            "id": "job-123",
            "status": status,
            "jobPercentComplete": percentComplete
        ]
        if let msg = errorMessage {
            jobData["errorMessage"] = msg
        }
        let json: [String: Any] = ["job": jobData]
        return
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
    }

    static func s3ListXML(
        keys: [String]
    ) -> Data {
        var xml =
            "<?xml version=\"1.0\"?>"
            + "<ListBucketResult>"
        for key in keys {
            xml += "<Contents><Key>\(key)</Key></Contents>"
        }
        xml += "</ListBucketResult>"
        return Data(xml.utf8)
    }
}
