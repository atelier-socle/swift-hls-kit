// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - Icecast Auth Mode

/// Authentication mode for Icecast connections.
///
/// Matches IcecastKit 0.2.0's authentication styles.
/// `.basic` is the default for backward compatibility
/// with standard Icecast servers.
public enum IcecastAuthMode: String, Sendable, Equatable, CaseIterable {

    /// HTTP Basic Auth (RFC 7617). Default for Icecast.
    case basic

    /// HTTP Digest Auth (RFC 7616).
    case digest

    /// Authorization: Bearer token.
    case bearer

    /// Token passed as URL query parameter.
    case queryToken

    /// SHOUTcast v1 password-only authentication.
    case shoutcast

    /// SHOUTcast v2 user:password authentication.
    case shoutcastV2
}

// MARK: - Icecast Credentials

/// Credentials for Icecast SOURCE connection.
///
/// Icecast uses HTTP-style basic authentication with a
/// username (typically `"source"`) and password.
public struct IcecastCredentials: Sendable, Equatable {

    /// Username for authentication.
    public var username: String

    /// Password for authentication.
    public var password: String

    /// Authentication mode to use for the connection.
    ///
    /// Matches IcecastKit 0.2.0's authentication styles.
    /// Defaults to `.basic` for backward compatibility.
    public var authenticationMode: IcecastAuthMode

    /// Creates Icecast credentials.
    ///
    /// - Parameters:
    ///   - username: Username. Default `"source"`.
    ///   - password: Password.
    ///   - authenticationMode: Auth mode. Default `.basic`.
    public init(
        username: String = "source",
        password: String,
        authenticationMode: IcecastAuthMode = .basic
    ) {
        self.username = username
        self.password = password
        self.authenticationMode = authenticationMode
    }
}

// MARK: - Icecast Metadata

/// ICY metadata for Icecast streams.
///
/// Represents the metadata fields sent inline with the audio
/// stream using the ICY metadata protocol.
public struct IcecastMetadata: Sendable, Equatable {

    /// Current track title (`StreamTitle` in ICY protocol).
    public var streamTitle: String?

    /// Stream URL.
    public var streamURL: String?

    /// Custom metadata fields.
    public var customFields: [String: String]

    /// Creates Icecast metadata.
    ///
    /// - Parameters:
    ///   - streamTitle: Current track title. Default `nil`.
    ///   - streamURL: Stream URL. Default `nil`.
    ///   - customFields: Custom fields. Default empty.
    public init(
        streamTitle: String? = nil,
        streamURL: String? = nil,
        customFields: [String: String] = [:]
    ) {
        self.streamTitle = streamTitle
        self.streamURL = streamURL
        self.customFields = customFields
    }
}

// MARK: - Icecast Transport Protocol

/// Protocol for Icecast SOURCE protocol operations.
///
/// Users implement this for Icecast/SHOUTcast streaming.
/// swift-hls-kit handles the HLS-specific orchestration while
/// the transport handles raw Icecast communication.
public protocol IcecastTransport: Sendable {

    /// Connect to an Icecast server as a SOURCE client.
    ///
    /// - Parameters:
    ///   - url: The Icecast server URL.
    ///   - credentials: Authentication credentials.
    ///   - mountpoint: The mountpoint path (e.g., `"/live.mp3"`).
    func connect(
        to url: String,
        credentials: IcecastCredentials,
        mountpoint: String
    ) async throws

    /// Disconnect from the Icecast server.
    func disconnect() async

    /// Send audio data.
    ///
    /// - Parameter data: The audio data to send.
    func send(_ data: Data) async throws

    /// Update ICY metadata (song title, etc.).
    ///
    /// - Parameter metadata: The metadata to broadcast.
    func updateMetadata(
        _ metadata: IcecastMetadata
    ) async throws

    /// Whether the transport is currently connected.
    var isConnected: Bool { get async }

    /// Server version detected during the Icecast handshake.
    ///
    /// Transports that parse the HTTP response `Server` header
    /// override this to report the server's version string
    /// (e.g., `"Icecast 2.5.0"`). The default returns `nil`.
    var serverVersion: String? { get async }

    /// Current stream statistics from the transport.
    ///
    /// Transports that track connection metrics override this
    /// to report real-time statistics. Matches IcecastKit 0.2.0's
    /// `ConnectionStatistics`. The default returns `nil`.
    var streamStatistics: IcecastStreamStatistics? { get async }
}

// MARK: - Default Implementations

extension IcecastTransport {

    /// Default returns `nil` for backward compatibility.
    public var serverVersion: String? {
        get async { nil }
    }

    /// Default returns `nil` for backward compatibility.
    public var streamStatistics: IcecastStreamStatistics? {
        get async { nil }
    }
}
