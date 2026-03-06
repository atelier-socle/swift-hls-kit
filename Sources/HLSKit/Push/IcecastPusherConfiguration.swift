// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

// MARK: - Icecast Server Preset

/// Known Icecast/SHOUTcast server platforms.
///
/// Identifies the server software to help transports apply
/// platform-specific defaults (ports, mount patterns, auth
/// styles). Matches IcecastKit 0.2.0's server preset catalog.
public enum IcecastServerPreset: String, Sendable, Equatable,
    CaseIterable
{
    /// AzuraCast self-hosted radio platform.
    case azuracast

    /// LibreTime broadcast automation.
    case libretime

    /// Radio.co managed streaming service.
    case radioCo

    /// Centova Cast control panel.
    case centovaCast

    /// SHOUTcast DNAS server.
    case shoutcastDNAS

    /// Official Icecast server.
    case icecastOfficial
}

// MARK: - Configuration

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

    /// Server platform preset, if applicable.
    ///
    /// Helps transports apply platform-specific behavior
    /// (protocol negotiation, auth style, etc.).
    public var serverPreset: IcecastServerPreset?

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
    ///   - serverPreset: Server preset. Default `nil`.
    public init(
        serverURL: String,
        mountpoint: String,
        credentials: IcecastCredentials,
        contentType: AudioContentType = .mp3,
        streamName: String? = nil,
        streamDescription: String? = nil,
        streamGenre: String? = nil,
        enableMetadata: Bool = true,
        retryPolicy: PushRetryPolicy = .default,
        serverPreset: IcecastServerPreset? = nil
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
        self.serverPreset = serverPreset
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

    // MARK: - Server Presets (0.4.0)

    /// AzuraCast configuration.
    ///
    /// Uses AzuraCast defaults: port 8000, MP3 content type,
    /// basic auth. Matches IcecastKit 0.2.0's AzuraCast preset.
    ///
    /// - Parameters:
    ///   - host: Server hostname or IP.
    ///   - mountpoint: Mount path. Default `"/radio.mp3"`.
    ///   - password: SOURCE password.
    /// - Returns: Configuration for AzuraCast.
    public static func azuracast(
        host: String,
        mountpoint: String = "/radio.mp3",
        password: String
    ) -> IcecastPusherConfiguration {
        IcecastPusherConfiguration(
            serverURL: "http://\(host):8000",
            mountpoint: mountpoint,
            credentials: IcecastCredentials(password: password),
            contentType: .mp3,
            serverPreset: .azuracast
        )
    }

    /// LibreTime configuration.
    ///
    /// Uses LibreTime defaults: port 8000, `/main.mp3`
    /// mountpoint, basic auth. Matches IcecastKit 0.2.0's
    /// LibreTime preset.
    ///
    /// - Parameters:
    ///   - host: Server hostname or IP.
    ///   - password: SOURCE password.
    /// - Returns: Configuration for LibreTime.
    public static func libretime(
        host: String,
        password: String
    ) -> IcecastPusherConfiguration {
        IcecastPusherConfiguration(
            serverURL: "http://\(host):8000",
            mountpoint: "/main.mp3",
            credentials: IcecastCredentials(password: password),
            contentType: .mp3,
            serverPreset: .libretime
        )
    }

    /// SHOUTcast DNAS configuration.
    ///
    /// Uses SHOUTcast defaults: port 8000, root mountpoint,
    /// password-only auth. Matches IcecastKit 0.2.0's
    /// SHOUTcast DNAS preset.
    ///
    /// - Note: SHOUTcast uses a different protocol from
    ///   standard Icecast. The transport implementation
    ///   should handle protocol differences.
    ///
    /// - Parameters:
    ///   - host: Server hostname or IP.
    ///   - password: SOURCE password.
    /// - Returns: Configuration for SHOUTcast DNAS.
    public static func shoutcastDNAS(
        host: String,
        password: String
    ) -> IcecastPusherConfiguration {
        IcecastPusherConfiguration(
            serverURL: "http://\(host):8000",
            mountpoint: "/",
            credentials: IcecastCredentials(password: password),
            contentType: .mp3,
            serverPreset: .shoutcastDNAS
        )
    }
}
