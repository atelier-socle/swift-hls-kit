// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Mock HTTP client for Cloudflare Stream provider tests.
struct MockCFHTTP: HTTPClient, Sendable {

    let requestHandler:
        @Sendable (URL, String, [String: String], Data?)
            async throws -> HTTPResponse
    let uploadHandler:
        @Sendable (
            URL, URL, String, [String: String],
            (@Sendable (Double) -> Void)?
        ) async throws -> HTTPResponse
    let downloadHandler:
        @Sendable (
            URL, URL, [String: String],
            (@Sendable (Double) -> Void)?
        ) async throws -> Void

    init(
        requestHandler:
            @escaping @Sendable (
                URL, String, [String: String], Data?
            ) async throws -> HTTPResponse = { _, _, _, _ in
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
        downloadHandler:
            @escaping @Sendable (
                URL, URL, [String: String],
                (@Sendable (Double) -> Void)?
            ) async throws -> Void = { _, _, _, _ in }
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
