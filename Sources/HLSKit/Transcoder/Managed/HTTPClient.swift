// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Minimal HTTP client abstraction for managed transcoding.
///
/// Allows injection of mock clients in tests.
///
/// - SeeAlso: ``URLSessionHTTPClient``, ``ManagedTranscoder``
protocol HTTPClient: Sendable {

    /// Perform an HTTP request.
    ///
    /// - Parameters:
    ///   - url: Request URL.
    ///   - method: HTTP method (GET, POST, PUT, DELETE).
    ///   - headers: HTTP headers.
    ///   - body: Optional request body.
    /// - Returns: HTTP response.
    func request(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> HTTPResponse

    /// Upload a file.
    ///
    /// - Parameters:
    ///   - url: Upload endpoint URL.
    ///   - fileURL: Local file to upload.
    ///   - method: HTTP method (typically POST or PUT).
    ///   - headers: HTTP headers.
    ///   - progress: Upload progress callback (0.0 to 1.0).
    /// - Returns: HTTP response.
    func upload(
        url: URL,
        fileURL: URL,
        method: String,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> HTTPResponse

    /// Download a file.
    ///
    /// - Parameters:
    ///   - url: URL to download from.
    ///   - destination: Local file path to write to.
    ///   - headers: HTTP headers.
    ///   - progress: Download progress callback (0.0 to 1.0).
    func download(
        url: URL,
        to destination: URL,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws
}

// MARK: - HTTPResponse

/// HTTP response from a managed transcoding request.
struct HTTPResponse: Sendable {

    /// HTTP status code.
    let statusCode: Int

    /// Response headers.
    let headers: [String: String]

    /// Response body data.
    let body: Data
}

// MARK: - URLSession Implementation

/// Default HTTP client using Foundation URLSession.
///
/// Used by ``ManagedTranscoder`` for production network calls.
struct URLSessionHTTPClient: HTTPClient, Sendable {

    func request(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> HTTPResponse {
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(
            for: request
        )

        guard let httpResponse = response as? HTTPURLResponse
        else {
            throw TranscodingError.encodingFailed(
                "Invalid HTTP response"
            )
        }

        let responseHeaders = httpResponse.allHeaderFields
            .reduce(into: [String: String]()) { result, pair in
                if let key = pair.key as? String,
                    let value = pair.value as? String
                {
                    result[key] = value
                }
            }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            body: data
        )
    }

    func upload(
        url: URL,
        fileURL: URL,
        method: String,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> HTTPResponse {
        let fileData = try Data(contentsOf: fileURL)

        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        request.httpBody = fileData

        progress?(0.5)
        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        progress?(1.0)

        guard let httpResponse = response as? HTTPURLResponse
        else {
            throw TranscodingError.uploadFailed(
                "Invalid HTTP response"
            )
        }

        let responseHeaders = httpResponse.allHeaderFields
            .reduce(into: [String: String]()) { result, pair in
                if let key = pair.key as? String,
                    let value = pair.value as? String
                {
                    result[key] = value
                }
            }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            body: data
        )
    }

    func download(
        url: URL,
        to destination: URL,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        progress?(0.5)
        let (data, response) = try await URLSession.shared.data(
            for: request
        )
        progress?(1.0)

        guard let httpResponse = response as? HTTPURLResponse,
            (200..<300).contains(httpResponse.statusCode)
        else {
            throw TranscodingError.downloadFailed(
                "Download failed from \(url)"
            )
        }

        try data.write(to: destination)
    }
}
