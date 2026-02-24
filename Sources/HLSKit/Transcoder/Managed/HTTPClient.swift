// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

#if canImport(os)
    import os
#endif

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

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

// MARK: - Streaming Delegates

#if canImport(Darwin)

    /// Bridges URLSession upload callbacks to async/await via
    /// `CheckedContinuation`. Created per-upload operation.
    private final class UploadDelegate: NSObject,
        URLSessionTaskDelegate, URLSessionDataDelegate
    {
        private let continuation: CheckedContinuation<HTTPResponse, Error>
        private let progressHandler: (@Sendable (Double) -> Void)?
        private let receivedData = OSAllocatedUnfairLock(initialState: Data())

        init(
            continuation: CheckedContinuation<
                HTTPResponse, Error
            >,
            progress: (@Sendable (Double) -> Void)?
        ) {
            self.continuation = continuation
            self.progressHandler = progress
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didSendBodyData bytesSent: Int64,
            totalBytesSent: Int64,
            totalBytesExpectedToSend: Int64
        ) {
            guard totalBytesExpectedToSend > 0 else { return }
            let fraction =
                Double(totalBytesSent)
                / Double(totalBytesExpectedToSend)
            progressHandler?(fraction)
        }

        func urlSession(
            _ session: URLSession,
            dataTask: URLSessionDataTask,
            didReceive data: Data
        ) {
            receivedData.withLock { $0.append(data) }
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error?
        ) {
            session.finishTasksAndInvalidate()
            if let error {
                continuation.resume(throwing: error)
                return
            }
            progressHandler?(1.0)
            guard
                let httpResponse =
                    task.response as? HTTPURLResponse
            else {
                continuation.resume(
                    throwing: TranscodingError.uploadFailed(
                        "Invalid HTTP response"
                    )
                )
                return
            }
            let headers = httpResponse.allHeaderFields
                .reduce(
                    into: [String: String]()
                ) { result, pair in
                    if let key = pair.key as? String,
                        let value = pair.value as? String
                    {
                        result[key] = value
                    }
                }
            let body = receivedData.withLock { $0 }
            continuation.resume(
                returning: HTTPResponse(
                    statusCode: httpResponse.statusCode,
                    headers: headers,
                    body: body
                )
            )
        }
    }

    /// Bridges URLSession download callbacks to async/await via
    /// `CheckedContinuation`. Created per-download operation.
    private final class DownloadDelegate: NSObject,
        URLSessionDownloadDelegate
    {
        private let continuation: CheckedContinuation<URL, Error>
        private let progressHandler: (@Sendable (Double) -> Void)?
        private let downloadedURL = OSAllocatedUnfairLock<URL?>(initialState: nil)

        init(
            continuation: CheckedContinuation<URL, Error>,
            progress: (@Sendable (Double) -> Void)?
        ) {
            self.continuation = continuation
            self.progressHandler = progress
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didFinishDownloadingTo location: URL
        ) {
            let stableURL =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
            do {
                try FileManager.default.moveItem(
                    at: location, to: stableURL
                )
                downloadedURL.withLock { $0 = stableURL }
            } catch {
                // Handled in didCompleteWithError
            }
        }

        func urlSession(
            _ session: URLSession,
            downloadTask: URLSessionDownloadTask,
            didWriteData bytesWritten: Int64,
            totalBytesWritten: Int64,
            totalBytesExpectedToWrite: Int64
        ) {
            guard totalBytesExpectedToWrite > 0 else { return }
            let fraction =
                Double(totalBytesWritten)
                / Double(totalBytesExpectedToWrite)
            progressHandler?(fraction)
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            didCompleteWithError error: Error?
        ) {
            session.finishTasksAndInvalidate()
            if let error {
                continuation.resume(throwing: error)
                return
            }
            progressHandler?(1.0)
            if let httpResponse =
                task.response as? HTTPURLResponse,
                !(200..<300).contains(httpResponse.statusCode)
            {
                continuation.resume(
                    throwing: TranscodingError.downloadFailed(
                        "Download failed with status "
                            + "\(httpResponse.statusCode)"
                    )
                )
                return
            }
            let savedURL = downloadedURL.withLock { $0 }
            guard let url = savedURL else {
                continuation.resume(
                    throwing: TranscodingError.downloadFailed(
                        "Download completed but file not saved"
                    )
                )
                return
            }
            continuation.resume(returning: url)
        }
    }

#endif

// MARK: - URLSession Implementation

/// Default HTTP client using Foundation URLSession.
///
/// On Apple platforms, upload and download operations stream
/// data to/from disk without loading entire files into memory.
/// Each streaming operation creates a dedicated `URLSession`
/// with a per-operation delegate, then invalidates it on
/// completion.
///
/// On Linux, upload and download fall back to in-memory
/// `Data(contentsOf:)` due to `FoundationNetworking`
/// delegate limitations.
///
/// The `request()` method (for small JSON payloads) uses the
/// shared session directly — no streaming needed.
struct URLSessionHTTPClient: HTTPClient, Sendable {

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

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

        let (data, response) = try await session.data(
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
        var request = URLRequest(url: url)
        request.httpMethod = method
        for (key, value) in headers {
            request.setValue(
                value, forHTTPHeaderField: key
            )
        }

        #if canImport(Darwin)
            return try await withCheckedThrowingContinuation { continuation in
                let delegate = UploadDelegate(
                    continuation: continuation,
                    progress: progress
                )
                let config =
                    URLSessionConfiguration.default
                config.protocolClasses =
                    self.session.configuration
                    .protocolClasses
                let opSession = URLSession(
                    configuration: config,
                    delegate: delegate,
                    delegateQueue: nil
                )
                opSession.uploadTask(
                    with: request, fromFile: fileURL
                ).resume()
            }
        #else
            let fileData = try Data(contentsOf: fileURL)
            request.httpBody = fileData
            progress?(0.5)
            let (data, response) = try await session.data(
                for: request
            )
            progress?(1.0)
            guard
                let httpResponse =
                    response as? HTTPURLResponse
            else {
                throw TranscodingError.uploadFailed(
                    "Invalid HTTP response"
                )
            }
            let responseHeaders =
                httpResponse.allHeaderFields
                .reduce(
                    into: [String: String]()
                ) { result, pair in
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
        #endif
    }

    func download(
        url: URL,
        to destination: URL,
        headers: [String: String],
        progress: (@Sendable (Double) -> Void)?
    ) async throws {
        var request = URLRequest(url: url)
        for (key, value) in headers {
            request.setValue(
                value, forHTTPHeaderField: key
            )
        }

        #if canImport(Darwin)
            let tempURL =
                try await withCheckedThrowingContinuation { continuation in
                    let delegate = DownloadDelegate(
                        continuation: continuation,
                        progress: progress
                    )
                    let config =
                        URLSessionConfiguration.default
                    config.protocolClasses =
                        self.session.configuration
                        .protocolClasses
                    let opSession = URLSession(
                        configuration: config,
                        delegate: delegate,
                        delegateQueue: nil
                    )
                    opSession.downloadTask(
                        with: request
                    ).resume()
                }
            try FileManager.default.moveItem(
                at: tempURL, to: destination
            )
        #else
            progress?(0.5)
            let (data, response) = try await session.data(
                for: request
            )
            progress?(1.0)
            guard
                let httpResponse =
                    response as? HTTPURLResponse,
                (200..<300).contains(
                    httpResponse.statusCode
                )
            else {
                throw TranscodingError.downloadFailed(
                    "Download failed from \(url)"
                )
            }
            try data.write(to: destination)
        #endif
    }
}
