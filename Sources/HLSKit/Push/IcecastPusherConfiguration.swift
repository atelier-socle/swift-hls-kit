// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for Icecast/SHOUTcast streaming.
///
/// Defines the server URL, mountpoint, credentials, content
/// type, and stream metadata for audio-only live streams.
public struct IcecastPusherConfiguration: Sendable, Equatable {

    /// Audio content type for the Icecast stream.
    public enum AudioContentType: String, Sendable, Equatable {
        /// MP3 audio (`audio/mpeg`).
        case mp3 = "audio/mpeg"
        /// AAC audio (`audio/aac`).
        case aac = "audio/aac"
        /// Ogg Vorbis/Opus (`application/ogg`).
        case ogg = "application/ogg"
    }

    /// Icecast server URL.
    public var serverURL: String

    /// Mountpoint path (e.g., `"/live.mp3"`).
    public var mountpoint: String

    /// Authentication credentials.
    public var credentials: IcecastCredentials

    /// Audio content type.
    public var contentType: AudioContentType

    /// Stream name/description.
    public var streamName: String?

    /// Stream description.
    public var streamDescription: String?

    /// Stream genre.
    public var streamGenre: String?

    /// Whether to send ICY metadata updates.
    public var enableMetadata: Bool

    /// Retry policy for reconnection.
    public var retryPolicy: PushRetryPolicy

    /// Creates an Icecast pusher configuration.
    ///
    /// - Parameters:
    ///   - serverURL: Icecast server URL.
    ///   - mountpoint: Mountpoint path.
    ///   - credentials: Authentication credentials.
    ///   - contentType: Audio content type. Default `.mp3`.
    ///   - streamName: Stream name. Default `nil`.
    ///   - streamDescription: Description. Default `nil`.
    ///   - streamGenre: Genre. Default `nil`.
    ///   - enableMetadata: Enable ICY metadata. Default `true`.
    ///   - retryPolicy: Retry policy. Default `.default`.
    public init(
        serverURL: String,
        mountpoint: String,
        credentials: IcecastCredentials,
        contentType: AudioContentType = .mp3,
        streamName: String? = nil,
        streamDescription: String? = nil,
        streamGenre: String? = nil,
        enableMetadata: Bool = true,
        retryPolicy: PushRetryPolicy = .default
    ) {
        self.serverURL = serverURL
        self.mountpoint = mountpoint
        self.credentials = credentials
        self.contentType = contentType
        self.streamName = streamName
        self.streamDescription = streamDescription
        self.streamGenre = streamGenre
        self.enableMetadata = enableMetadata
        self.retryPolicy = retryPolicy
    }

    // MARK: - Presets

    /// MP3 stream configuration.
    ///
    /// - Parameters:
    ///   - serverURL: Icecast server URL.
    ///   - mountpoint: Mountpoint path.
    ///   - password: SOURCE password.
    /// - Returns: Configuration for MP3 streaming.
    public static func mp3Stream(
        serverURL: String,
        mountpoint: String,
        password: String
    ) -> IcecastPusherConfiguration {
        IcecastPusherConfiguration(
            serverURL: serverURL,
            mountpoint: mountpoint,
            credentials: IcecastCredentials(password: password),
            contentType: .mp3
        )
    }

    /// AAC stream configuration.
    ///
    /// - Parameters:
    ///   - serverURL: Icecast server URL.
    ///   - mountpoint: Mountpoint path.
    ///   - password: SOURCE password.
    /// - Returns: Configuration for AAC streaming.
    public static func aacStream(
        serverURL: String,
        mountpoint: String,
        password: String
    ) -> IcecastPusherConfiguration {
        IcecastPusherConfiguration(
            serverURL: serverURL,
            mountpoint: mountpoint,
            credentials: IcecastCredentials(password: password),
            contentType: .aac
        )
    }
}
