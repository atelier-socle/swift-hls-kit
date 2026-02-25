// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Credentials for Icecast SOURCE connection.
///
/// Icecast uses HTTP-style basic authentication with a
/// username (typically `"source"`) and password.
public struct IcecastCredentials: Sendable, Equatable {

    /// Username for authentication.
    public var username: String

    /// Password for authentication.
    public var password: String

    /// Creates Icecast credentials.
    ///
    /// - Parameters:
    ///   - username: Username. Default `"source"`.
    ///   - password: Password.
    public init(username: String = "source", password: String) {
        self.username = username
        self.password = password
    }
}

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
}
