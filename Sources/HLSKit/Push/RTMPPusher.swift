// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// RTMP-based segment pusher.
///
/// Wraps segment data in FLV containers and sends via RTMP.
/// The actual RTMP transport is provided by the user via
/// ``RTMPTransport`` protocol, keeping the library
/// dependency-free.
///
/// - Note: `pushPlaylist` is a no-op for RTMP since playlists
///   are not pushed over this protocol.
public actor RTMPPusher: SegmentPusher {

    /// Configuration for this pusher.
    public let configuration: RTMPPusherConfiguration

    // Transport closures (generic init avoids `any Protocol`).
    private let connectFn: @Sendable (String) async throws -> Void
    private let disconnectFn: @Sendable () async -> Void
    private let sendFn: @Sendable (Data, UInt32, FLVTagType) async throws -> Void
    private let isConnectedFn: @Sendable () async -> Bool

    // v2 transport closures.
    private let sendMetadataFn: @Sendable ([String: String]) async throws -> Void
    private let serverCapabilitiesFn: @Sendable () async -> RTMPServerCapabilities?
    private let connectionQualityFn: (@Sendable () async -> TransportQuality?)?

    /// Stream of transport events from the underlying transport.
    ///
    /// Returns an active stream if the transport conforms to
    /// ``QualityAwareTransport``, otherwise an empty completed stream.
    public nonisolated let transportEvents: AsyncStream<TransportEvent>

    private var _connectionState: PushConnectionState = .disconnected
    private var _stats: PushStats = .zero
    private var currentTimestamp: UInt32 = 0

    /// Creates an RTMP pusher with a transport implementation.
    ///
    /// - Parameters:
    ///   - configuration: The RTMP pusher configuration.
    ///   - transport: An RTMP transport conforming to
    ///     ``RTMPTransport``.
    public init<T: RTMPTransport>(
        configuration: RTMPPusherConfiguration,
        transport: T
    ) {
        self.configuration = configuration
        self.connectFn = { url in
            try await transport.connect(to: url)
        }
        self.disconnectFn = {
            await transport.disconnect()
        }
        self.sendFn = { data, timestamp, type in
            try await transport.send(
                data: data, timestamp: timestamp, type: type
            )
        }
        self.isConnectedFn = {
            await transport.isConnected
        }
        self.sendMetadataFn = { metadata in
            try await transport.sendMetadata(metadata)
        }
        self.serverCapabilitiesFn = {
            await transport.serverCapabilities
        }

        // Capture quality-aware capabilities if the transport
        // conforms to QualityAwareTransport. The existential cast
        // is required because T is only constrained to RTMPTransport.
        if let qualityTransport = transport as? any QualityAwareTransport {
            self.connectionQualityFn = {
                await qualityTransport.connectionQuality
            }
            self.transportEvents = qualityTransport.transportEvents
        } else {
            self.connectionQualityFn = nil
            self.transportEvents = AsyncStream { $0.finish() }
        }
    }

    // MARK: - SegmentPusher

    /// Current connection state.
    public var connectionState: PushConnectionState {
        _connectionState
    }

    /// Current push statistics.
    public var stats: PushStats { _stats }

    /// Connect to the RTMP server.
    ///
    /// Uses the full URL from configuration (server + stream key).
    public func connect() async throws {
        guard !configuration.serverURL.isEmpty else {
            throw PushError.invalidConfiguration(
                "Server URL is empty"
            )
        }
        _connectionState = .connecting
        do {
            try await connectFn(configuration.fullURL)
            _connectionState = .connected
            currentTimestamp = 0
        } catch {
            _connectionState = .failed
            throw PushError.connectionFailed(
                underlying: error.localizedDescription
            )
        }
    }

    /// Disconnect from the RTMP server.
    public func disconnect() async {
        await disconnectFn()
        _connectionState = .disconnected
        currentTimestamp = 0
    }

    /// Push a completed live segment as FLV video data.
    public func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        try guardConnected()
        let start = Date()
        do {
            try await sendFn(
                segment.data, currentTimestamp, .video
            )
            let durationMs = UInt32(segment.duration * 1000)
            currentTimestamp += durationMs
            let latency = Date().timeIntervalSince(start)
            _stats.recordSuccess(
                bytes: Int64(segment.data.count),
                latency: latency
            )
        } catch {
            _stats.recordFailure()
            throw PushError.connectionFailed(
                underlying: error.localizedDescription
            )
        }
    }

    /// Push a partial segment as FLV video data.
    public func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        try guardConnected()
        let start = Date()
        do {
            try await sendFn(Data(), currentTimestamp, .video)
            let latency = Date().timeIntervalSince(start)
            _stats.recordSuccess(
                bytes: 0, latency: latency
            )
        } catch {
            _stats.recordFailure()
            throw PushError.connectionFailed(
                underlying: error.localizedDescription
            )
        }
    }

    /// Push a playlist — no-op for RTMP.
    ///
    /// RTMP does not transport HLS playlists. This method
    /// completes without error.
    public func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        // No-op: RTMP doesn't transport playlists.
    }

    /// Push an init segment as FLV script data.
    public func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        try guardConnected()
        let start = Date()
        do {
            try await sendFn(data, 0, .scriptData)
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

    // MARK: - Transport v2

    /// Current transport quality, if the underlying transport
    /// conforms to ``QualityAwareTransport``.
    ///
    /// Returns `nil` when the transport does not support quality
    /// reporting.
    public var transportQuality: TransportQuality? {
        get async {
            guard let fn = connectionQualityFn else { return nil }
            return await fn()
        }
    }

    /// Update stream metadata on the RTMP connection.
    ///
    /// Delegates to the transport's ``RTMPTransport/sendMetadata(_:)``
    /// method. Requires an active connection.
    ///
    /// - Parameter metadata: Key-value metadata pairs to send.
    public func updateStreamMetadata(
        _ metadata: [String: String]
    ) async throws {
        try guardConnected()
        try await sendMetadataFn(metadata)
    }

    // MARK: - Private

    private func guardConnected() throws {
        guard _connectionState == .connected else {
            throw PushError.notConnected
        }
    }
}
