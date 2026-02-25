// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Response from an HTTP push operation.
public struct HTTPPushResponse: Sendable {

    /// HTTP status code.
    public let statusCode: Int

    /// Response headers.
    public let headers: [String: String]

    /// Creates an HTTP push response.
    public init(statusCode: Int, headers: [String: String] = [:]) {
        self.statusCode = statusCode
        self.headers = headers
    }
}

/// Protocol for HTTP operations, enabling dependency injection
/// for testing.
public protocol HTTPClientProtocol: Sendable {

    /// Upload data to the given URL.
    ///
    /// - Parameters:
    ///   - data: The data to upload.
    ///   - url: The destination URL string.
    ///   - method: The HTTP method (PUT/POST).
    ///   - headers: Request headers.
    ///   - timeout: Request timeout in seconds.
    /// - Returns: The HTTP response.
    func upload(
        data: Data,
        to url: String,
        method: String,
        headers: [String: String],
        timeout: TimeInterval
    ) async throws -> HTTPPushResponse
}

/// HTTP-based segment pusher.
///
/// Pushes segments, playlists, and init segments via HTTP PUT/POST
/// to an origin server or CDN. Includes retry logic with
/// exponential backoff and circuit breaker protection.
public actor HTTPPusher: SegmentPusher {

    /// Configuration for this pusher.
    public let configuration: HTTPPusherConfiguration

    private let uploadFn:
        @Sendable (
            Data, String, String, [String: String], TimeInterval
        ) async throws -> HTTPPushResponse

    private var _connectionState: PushConnectionState = .disconnected
    private var _stats: PushStats = .zero

    // Circuit breaker state.
    private var consecutiveFailures: Int = 0
    private var circuitBreakerOpenedAt: Date?

    /// Creates an HTTP pusher with a custom HTTP client.
    ///
    /// - Parameters:
    ///   - configuration: The pusher configuration.
    ///   - httpClient: An HTTP client conforming to
    ///     ``HTTPClientProtocol``.
    public init<C: HTTPClientProtocol>(
        configuration: HTTPPusherConfiguration,
        httpClient: C
    ) {
        self.configuration = configuration
        self.uploadFn = { data, url, method, headers, timeout in
            try await httpClient.upload(
                data: data, to: url, method: method,
                headers: headers, timeout: timeout
            )
        }
    }

    // MARK: - SegmentPusher

    /// Current connection state.
    public var connectionState: PushConnectionState {
        _connectionState
    }

    /// Current push statistics.
    public var stats: PushStats { _stats }

    /// Connect to the push destination.
    ///
    /// Sets the state to `.connected`. The base URL is validated
    /// but no network request is made at connect time.
    public func connect() async throws {
        guard !configuration.baseURL.isEmpty else {
            throw PushError.invalidConfiguration(
                "Base URL is empty"
            )
        }
        _connectionState = .connecting
        _connectionState = .connected
        consecutiveFailures = 0
        circuitBreakerOpenedAt = nil
    }

    /// Disconnect from the push destination.
    public func disconnect() async {
        _connectionState = .disconnected
        consecutiveFailures = 0
        circuitBreakerOpenedAt = nil
    }

    /// Push a completed live segment.
    public func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        let contentType =
            configuration.segmentContentType
            ?? "video/mp4"
        try await pushData(
            segment.data, filename: filename,
            contentType: contentType
        )
    }

    /// Push a partial segment (LL-HLS).
    public func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        let contentType =
            configuration.segmentContentType
            ?? "video/mp4"
        // LLPartialSegment is metadata-only; actual data is
        // read from storage by the caller or transport layer.
        try await pushData(
            Data(), filename: filename,
            contentType: contentType
        )
    }

    /// Push an updated playlist.
    public func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        let data = Data(m3u8.utf8)
        try await pushData(
            data, filename: filename,
            contentType: configuration.playlistContentType
        )
    }

    /// Push an init segment.
    public func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        let contentType =
            configuration.segmentContentType
            ?? "video/mp4"
        try await pushData(
            data, filename: filename,
            contentType: contentType
        )
    }

    // MARK: - Internal

    private func pushData(
        _ data: Data,
        filename: String,
        contentType: String
    ) async throws {
        guard _connectionState == .connected else {
            throw PushError.notConnected
        }
        try checkCircuitBreaker()

        let url = buildURL(for: filename)
        let policy = configuration.retryPolicy
        var lastError: String = ""

        for attempt in 0...policy.maxRetries {
            if attempt > 0 {
                _stats.retryCount += 1
                let delay = policy.delay(forAttempt: attempt - 1)
                try await Task.sleep(
                    for: .seconds(delay)
                )
            }

            let start = Date()
            do {
                let response = try await attemptPush(
                    data: data, url: url,
                    contentType: contentType
                )

                if (200..<300).contains(response.statusCode) {
                    let latency = Date().timeIntervalSince(start)
                    _stats.recordSuccess(
                        bytes: Int64(data.count),
                        latency: latency
                    )
                    consecutiveFailures = 0
                    circuitBreakerOpenedAt = nil
                    _stats.circuitBreakerOpen = false
                    return
                }

                lastError = "HTTP \(response.statusCode)"

                if !policy.retryableStatusCodes.contains(
                    response.statusCode
                ) {
                    _stats.recordFailure()
                    recordConsecutiveFailure()
                    throw PushError.httpError(
                        statusCode: response.statusCode,
                        message: nil
                    )
                }

                _stats.recordFailure()
                recordConsecutiveFailure()
            } catch let error as PushError {
                throw error
            } catch {
                lastError = error.localizedDescription
                _stats.recordFailure()
                recordConsecutiveFailure()
            }
        }

        throw PushError.retriesExhausted(
            attempts: policy.maxRetries + 1,
            lastError: lastError
        )
    }

    private func attemptPush(
        data: Data,
        url: String,
        contentType: String
    ) async throws -> HTTPPushResponse {
        let headers = buildHeaders(
            contentType: contentType,
            contentLength: data.count
        )
        return try await uploadFn(
            data, url, configuration.method.rawValue,
            headers, configuration.retryPolicy.requestTimeout
        )
    }

    private func checkCircuitBreaker() throws {
        let threshold =
            configuration.retryPolicy.circuitBreakerThreshold
        guard consecutiveFailures >= threshold else { return }

        if let openedAt = circuitBreakerOpenedAt {
            let elapsed = Date().timeIntervalSince(openedAt)
            let resetInterval =
                configuration.retryPolicy
                .circuitBreakerResetInterval
            if elapsed >= resetInterval {
                // Half-open: allow one attempt.
                return
            }
        }

        throw PushError.circuitBreakerOpen(
            failures: consecutiveFailures
        )
    }

    private func recordConsecutiveFailure() {
        consecutiveFailures += 1
        let threshold =
            configuration.retryPolicy.circuitBreakerThreshold
        if consecutiveFailures >= threshold,
            circuitBreakerOpenedAt == nil
        {
            circuitBreakerOpenedAt = Date()
            _stats.circuitBreakerOpen = true
        }
    }

    private func buildURL(for filename: String) -> String {
        let base = configuration.baseURL
        if base.hasSuffix("/") {
            return base + filename
        }
        return base + "/" + filename
    }

    private func buildHeaders(
        contentType: String, contentLength: Int
    ) -> [String: String] {
        var headers = configuration.headers
        headers["Content-Type"] = contentType
        if configuration.includeContentLength {
            headers["Content-Length"] = "\(contentLength)"
        }
        return headers
    }
}
