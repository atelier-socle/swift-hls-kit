// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for RTMP-based segment pushing.
///
/// Defines the RTMP server URL, stream key, retry behavior,
/// and optional metadata settings for live streaming.
public struct RTMPPusherConfiguration: Sendable, Equatable {

    /// RTMP server URL (e.g., `"rtmp://live.twitch.tv/app"`).
    public var serverURL: String

    /// Stream key for authentication.
    public var streamKey: String

    /// Retry policy for reconnection.
    public var retryPolicy: PushRetryPolicy

    /// Whether to send metadata (onMetaData) at stream start.
    public var sendMetadata: Bool

    /// Application name (extracted from URL or overridden).
    public var applicationName: String?

    /// Creates an RTMP pusher configuration.
    ///
    /// - Parameters:
    ///   - serverURL: RTMP server URL.
    ///   - streamKey: Stream key for authentication.
    ///   - retryPolicy: Retry policy. Default `.default`.
    ///   - sendMetadata: Send metadata at start. Default `true`.
    ///   - applicationName: Optional application name override.
    public init(
        serverURL: String,
        streamKey: String,
        retryPolicy: PushRetryPolicy = .default,
        sendMetadata: Bool = true,
        applicationName: String? = nil
    ) {
        self.serverURL = serverURL
        self.streamKey = streamKey
        self.retryPolicy = retryPolicy
        self.sendMetadata = sendMetadata
        self.applicationName = applicationName
    }

    /// Full RTMP URL combining server URL and stream key.
    public var fullURL: String {
        let base = serverURL
        if base.hasSuffix("/") {
            return base + streamKey
        }
        return base + "/" + streamKey
    }

    // MARK: - Presets

    /// Twitch live stream configuration.
    ///
    /// - Parameter streamKey: Twitch stream key.
    /// - Returns: Configuration for Twitch RTMP ingest.
    public static func twitch(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmp://live.twitch.tv/app",
            streamKey: streamKey,
            retryPolicy: .aggressive
        )
    }

    /// YouTube Live configuration.
    ///
    /// - Parameter streamKey: YouTube stream key.
    /// - Returns: Configuration for YouTube RTMP ingest.
    public static func youtube(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmp://a.rtmp.youtube.com/live2",
            streamKey: streamKey
        )
    }

    /// Facebook Live configuration.
    ///
    /// - Parameter streamKey: Facebook stream key.
    /// - Returns: Configuration for Facebook RTMP ingest.
    public static func facebook(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmps://live-api-s.facebook.com:443/rtmp",
            streamKey: streamKey
        )
    }

    /// Custom RTMP server configuration.
    ///
    /// - Parameters:
    ///   - serverURL: RTMP server URL.
    ///   - streamKey: Stream key.
    /// - Returns: Configuration with default retry policy.
    public static func custom(
        serverURL: String,
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: serverURL,
            streamKey: streamKey
        )
    }
}
