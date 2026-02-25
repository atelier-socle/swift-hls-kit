// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

@testable import HLSKit

/// Recorded upload call for mock verification.
struct MockUploadCall: Sendable {
    let data: Data
    let url: String
    let method: String
}

/// Mock HTTP client for ``HTTPPusher`` tests.
///
/// Records upload calls and returns queued or default responses.
actor MockHTTPPushClient: HTTPClientProtocol {

    /// Queued responses returned in order.
    var responses: [HTTPPushResponse] = []

    /// Default response when queue is empty.
    var defaultResponse = HTTPPushResponse(
        statusCode: 200, headers: [:]
    )

    /// Recorded upload calls.
    var uploadCalls: [MockUploadCall] = []

    /// Whether to throw on upload.
    var shouldThrow = false

    /// Error to throw when `shouldThrow` is true.
    var throwError: PushError = .connectionFailed(
        underlying: "mock"
    )

    /// Simulated latency in seconds.
    var uploadDelay: TimeInterval = 0

    /// Set the default response for all uploads.
    func setDefaultResponse(_ response: HTTPPushResponse) {
        defaultResponse = response
    }

    /// Set a queue of responses returned in order.
    func setResponses(_ list: [HTTPPushResponse]) {
        responses = list
    }

    /// Enable throwing on upload.
    func setShouldThrow(
        _ value: Bool,
        error: PushError = .connectionFailed(underlying: "mock")
    ) {
        shouldThrow = value
        throwError = error
    }

    nonisolated func upload(
        data: Data,
        to url: String,
        method: String,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> HTTPPushResponse {
        try await withDelay(
            data: data, url: url, method: method
        )
    }

    private func withDelay(
        data: Data, url: String, method: String
    ) async throws -> HTTPPushResponse {
        uploadCalls.append(
            MockUploadCall(data: data, url: url, method: method)
        )

        if uploadDelay > 0 {
            try await Task.sleep(for: .seconds(uploadDelay))
        }

        if shouldThrow { throw throwError }

        if !responses.isEmpty {
            return responses.removeFirst()
        }
        return defaultResponse
    }
}
