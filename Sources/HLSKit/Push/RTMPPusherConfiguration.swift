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
            serverURL: "rtmps://live.twitch.tv/app",
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
            serverURL: "rtmps://a.rtmp.youtube.com/live2",
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

    // MARK: - Platform Presets (0.5.0)

    /// Instagram Live configuration.
    ///
    /// Uses RTMPS ingest at `live-upload.instagram.com`.
    /// Mirrors RTMPKit 0.2.0 `PlatformPreset.instagram`.
    ///
    /// - Parameter streamKey: Instagram stream key.
    /// - Returns: Configuration for Instagram RTMPS ingest.
    public static func instagram(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmps://live-upload.instagram.com:443/rtmp/",
            streamKey: streamKey
        )
    }

    /// TikTok Live configuration.
    ///
    /// Uses RTMPS ingest at `push.tiktok.com`.
    /// Mirrors RTMPKit 0.2.0 `PlatformPreset.tiktok`.
    ///
    /// - Parameter streamKey: TikTok stream key.
    /// - Returns: Configuration for TikTok RTMPS ingest.
    public static func tiktok(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmps://push.tiktok.com/rtmp/",
            streamKey: streamKey
        )
    }

    /// Twitter/X Live configuration.
    ///
    /// Uses RTMPS ingest via Periscope infrastructure.
    /// Mirrors RTMPKit 0.2.0 `PlatformPreset.twitter`.
    ///
    /// - Parameter streamKey: Twitter/X stream key.
    /// - Returns: Configuration for Twitter RTMPS ingest.
    public static func twitter(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmps://prod-rtmp-publish.periscope.tv:443/",
            streamKey: streamKey
        )
    }

    /// Rumble Live configuration.
    ///
    /// Uses RTMP (non-TLS) ingest at `publish.rumble.com`.
    /// Mirrors RTMPKit 0.2.0 `PlatformPreset.rumble`.
    ///
    /// - Parameter streamKey: Rumble stream key.
    /// - Returns: Configuration for Rumble RTMP ingest.
    public static func rumble(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmp://publish.rumble.com/live/",
            streamKey: streamKey
        )
    }

    /// Kick Live configuration.
    ///
    /// Uses RTMP ingest via global CDN.
    /// Mirrors RTMPKit 0.2.0 `PlatformPreset.kick`.
    ///
    /// - Parameter streamKey: Kick stream key.
    /// - Returns: Configuration for Kick RTMP ingest.
    public static func kick(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL:
                "rtmp://fa723fc1b171.global-contribute.live-video.net/app/",
            streamKey: streamKey
        )
    }

    /// LinkedIn Live configuration.
    ///
    /// Uses RTMPS ingest at `livein.linkedin.com`.
    /// Mirrors RTMPKit 0.2.0 `PlatformPreset.linkedin`.
    ///
    /// - Parameter streamKey: LinkedIn stream key.
    /// - Returns: Configuration for LinkedIn RTMPS ingest.
    public static func linkedin(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmps://livein.linkedin.com:443/live/",
            streamKey: streamKey
        )
    }

    /// Trovo Live configuration.
    ///
    /// Uses RTMP (non-TLS) ingest at `livepush.trovo.live`.
    /// Mirrors RTMPKit 0.2.0 `PlatformPreset.trovo`.
    ///
    /// - Parameter streamKey: Trovo stream key.
    /// - Returns: Configuration for Trovo RTMP ingest.
    public static func trovo(
        streamKey: String
    ) -> RTMPPusherConfiguration {
        RTMPPusherConfiguration(
            serverURL: "rtmp://livepush.trovo.live/live/",
            streamKey: streamKey
        )
    }
}
