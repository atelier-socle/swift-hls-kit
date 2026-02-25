// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Icecast/SHOUTcast audio stream pusher.
///
/// Designed for audio-only live streams (podcasts, web radio).
/// The actual Icecast transport is provided by the user via
/// ``IcecastTransport`` protocol, keeping the library
/// dependency-free.
///
/// - Note: `pushPlaylist` and `pushInitSegment` are no-ops
///   for Icecast since they have no equivalent concept.
public actor IcecastPusher: SegmentPusher {

    /// Configuration for this pusher.
    public let configuration: IcecastPusherConfiguration

    // Transport closures (generic init avoids `any Protocol`).
    private let connectFn:
        @Sendable (
            String, IcecastCredentials, String
        ) async throws -> Void
    private let disconnectFn: @Sendable () async -> Void
    private let sendFn: @Sendable (Data) async throws -> Void
    private let updateMetadataFn: @Sendable (IcecastMetadata) async throws -> Void
    private let isConnectedFn: @Sendable () async -> Bool

    private var _connectionState: PushConnectionState = .disconnected
    private var _stats: PushStats = .zero
    private var currentMetadata: IcecastMetadata?

    /// Creates an Icecast pusher with a transport implementation.
    ///
    /// - Parameters:
    ///   - configuration: The Icecast pusher configuration.
    ///   - transport: An Icecast transport conforming to
    ///     ``IcecastTransport``.
    public init<T: IcecastTransport>(
        configuration: IcecastPusherConfiguration,
        transport: T
    ) {
        self.configuration = configuration
        self.connectFn = { url, credentials, mountpoint in
            try await transport.connect(
                to: url,
                credentials: credentials,
                mountpoint: mountpoint
            )
        }
        self.disconnectFn = {
            await transport.disconnect()
        }
        self.sendFn = { data in
            try await transport.send(data)
        }
        self.updateMetadataFn = { metadata in
            try await transport.updateMetadata(metadata)
        }
        self.isConnectedFn = {
            await transport.isConnected
        }
    }

    // MARK: - SegmentPusher

    /// Current connection state.
    public var connectionState: PushConnectionState {
        _connectionState
    }

    /// Current push statistics.
    public var stats: PushStats { _stats }

    /// Connect to the Icecast server.
    public func connect() async throws {
        guard !configuration.serverURL.isEmpty else {
            throw PushError.invalidConfiguration(
                "Server URL is empty"
            )
        }
        _connectionState = .connecting
        do {
            try await connectFn(
                configuration.serverURL,
                configuration.credentials,
                configuration.mountpoint
            )
            _connectionState = .connected
        } catch {
            _connectionState = .failed
            throw PushError.connectionFailed(
                underlying: error.localizedDescription
            )
        }
    }

    /// Disconnect from the Icecast server.
    public func disconnect() async {
        await disconnectFn()
        _connectionState = .disconnected
        currentMetadata = nil
    }

    /// Push a completed segment as audio data.
    public func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        try await sendData(segment.data)
    }

    /// Push a partial segment as audio data.
    public func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        // LLPartialSegment is metadata-only; send empty data.
        try await sendData(Data())
    }

    /// Push a playlist — no-op for Icecast.
    ///
    /// Icecast does not have a playlist concept. This method
    /// completes without error.
    public func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        // No-op: Icecast doesn't transport playlists.
    }

    /// Push an init segment — no-op for Icecast.
    ///
    /// Icecast streams raw audio without initialization
    /// segments. This method completes without error.
    public func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        // No-op: Icecast doesn't use init segments.
    }

    // MARK: - Icecast-specific

    /// Update the stream metadata (ICY metadata).
    ///
    /// Sends metadata to the Icecast server for broadcast
    /// to connected listeners. Only works when
    /// `enableMetadata` is `true` in the configuration.
    ///
    /// - Parameter metadata: The metadata to broadcast.
    public func updateMetadata(
        _ metadata: IcecastMetadata
    ) async throws {
        guard _connectionState == .connected else {
            throw PushError.notConnected
        }
        guard configuration.enableMetadata else { return }
        try await updateMetadataFn(metadata)
        currentMetadata = metadata
    }

    // MARK: - Private

    private func sendData(_ data: Data) async throws {
        guard _connectionState == .connected else {
            throw PushError.notConnected
        }
        let start = Date()
        do {
            try await sendFn(data)
            let latency = Date().timeIntervalSince(start)
            _stats.recordSuccess(
                bytes: Int64(data.count), latency: latency
            )
        } catch {
            _stats.recordFailure()
            throw PushError.connectionFailed(
                underlying: error.localizedDescription
            )
        }
    }
}
