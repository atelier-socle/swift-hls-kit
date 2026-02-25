// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for HTTP-based segment pushing.
///
/// Defines the base URL, HTTP method, headers, retry policy,
/// and content types for pushing segments and playlists to an
/// origin server or CDN.
public struct HTTPPusherConfiguration: Sendable, Equatable {

    /// HTTP method for push operations.
    public enum HTTPMethod: String, Sendable, Equatable {
        case put = "PUT"
        case post = "POST"
    }

    /// Base URL for the push destination.
    public var baseURL: String

    /// HTTP method to use for pushing.
    public var method: HTTPMethod

    /// Custom headers (e.g., auth tokens, content type overrides).
    public var headers: [String: String]

    /// Retry policy.
    public var retryPolicy: PushRetryPolicy

    /// Content type for segments.
    public var segmentContentType: String?

    /// Content type for playlists.
    public var playlistContentType: String

    /// Whether to include Content-Length header.
    public var includeContentLength: Bool

    /// Creates an HTTP pusher configuration.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL for the destination.
    ///   - method: HTTP method. Default `.put`.
    ///   - headers: Custom headers. Default empty.
    ///   - retryPolicy: Retry policy. Default `.default`.
    ///   - segmentContentType: Segment content type. Default `nil`.
    ///   - playlistContentType: Playlist content type.
    ///   - includeContentLength: Include Content-Length. Default `true`.
    public init(
        baseURL: String,
        method: HTTPMethod = .put,
        headers: [String: String] = [:],
        retryPolicy: PushRetryPolicy = .default,
        segmentContentType: String? = nil,
        playlistContentType: String =
            "application/vnd.apple.mpegurl",
        includeContentLength: Bool = true
    ) {
        self.baseURL = baseURL
        self.method = method
        self.headers = headers
        self.retryPolicy = retryPolicy
        self.segmentContentType = segmentContentType
        self.playlistContentType = playlistContentType
        self.includeContentLength = includeContentLength
    }

    // MARK: - Presets

    /// Standard HTTP PUT to origin server.
    ///
    /// - Parameters:
    ///   - baseURL: The origin server base URL.
    ///   - authToken: Optional Bearer auth token.
    /// - Returns: A configured pusher configuration.
    public static func httpPut(
        baseURL: String, authToken: String? = nil
    ) -> HTTPPusherConfiguration {
        var headers = [String: String]()
        if let token = authToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return HTTPPusherConfiguration(
            baseURL: baseURL,
            method: .put,
            headers: headers
        )
    }

    /// HTTP POST (for CDNs that expect POST).
    ///
    /// - Parameters:
    ///   - baseURL: The CDN base URL.
    ///   - authToken: Optional Bearer auth token.
    /// - Returns: A configured pusher configuration.
    public static func httpPost(
        baseURL: String, authToken: String? = nil
    ) -> HTTPPusherConfiguration {
        var headers = [String: String]()
        if let token = authToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return HTTPPusherConfiguration(
            baseURL: baseURL,
            method: .post,
            headers: headers
        )
    }

    /// AWS S3 compatible (PUT with specific headers).
    ///
    /// - Parameters:
    ///   - bucket: The S3 bucket name.
    ///   - prefix: The key prefix within the bucket.
    ///   - region: The AWS region.
    /// - Returns: A configured pusher configuration.
    public static func s3Compatible(
        bucket: String, prefix: String, region: String
    ) -> HTTPPusherConfiguration {
        let baseURL =
            "https://\(bucket).s3.\(region).amazonaws.com/\(prefix)"
        return HTTPPusherConfiguration(
            baseURL: baseURL,
            method: .put,
            headers: [
                "x-amz-acl": "public-read",
                "x-amz-storage-class": "STANDARD"
            ],
            retryPolicy: .conservative
        )
    }
}
