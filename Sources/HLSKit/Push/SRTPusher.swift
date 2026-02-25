// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// SRT-based segment pusher for ultra-low-latency delivery.
///
/// Sends raw segment data over SRT. The actual SRT transport
/// is provided by the user via ``SRTTransport`` protocol,
/// keeping the library dependency-free.
///
/// SRT's reliable delivery and low latency make it ideal
/// for LL-HLS partial segment pushing.
public actor SRTPusher: SegmentPusher {

    /// Configuration for this pusher.
    public let configuration: SRTPusherConfiguration

    // Transport closures (generic init avoids `any Protocol`).
    private let connectFn: @Sendable (String, Int, SRTOptions) async throws -> Void
    private let disconnectFn: @Sendable () async -> Void
    private let sendFn: @Sendable (Data) async throws -> Void
    private let isConnectedFn: @Sendable () async -> Bool
    private let networkStatsFn: @Sendable () async -> SRTNetworkStats?

    private var _connectionState: PushConnectionState = .disconnected
    private var _stats: PushStats = .zero

    /// Creates an SRT pusher with a transport implementation.
    ///
    /// - Parameters:
    ///   - configuration: The SRT pusher configuration.
    ///   - transport: An SRT transport conforming to
    ///     ``SRTTransport``.
    public init<T: SRTTransport>(
        configuration: SRTPusherConfiguration,
        transport: T
    ) {
        self.configuration = configuration
        self.connectFn = { host, port, options in
            try await transport.connect(
                to: host, port: port, options: options
            )
        }
        self.disconnectFn = {
            await transport.disconnect()
        }
        self.sendFn = { data in
            try await transport.send(data)
        }
        self.isConnectedFn = {
            await transport.isConnected
        }
        self.networkStatsFn = {
            await transport.networkStats
        }
    }

    // MARK: - SegmentPusher

    /// Current connection state.
    public var connectionState: PushConnectionState {
        _connectionState
    }

    /// Current push statistics.
    public var stats: PushStats { _stats }

    /// Connect to the SRT endpoint.
    public func connect() async throws {
        guard !configuration.host.isEmpty else {
            throw PushError.invalidConfiguration(
                "Host is empty"
            )
        }
        _connectionState = .connecting
        do {
            try await connectFn(
                configuration.host,
                configuration.port,
                configuration.options
            )
            _connectionState = .connected
        } catch {
            _connectionState = .failed
            throw PushError.connectionFailed(
                underlying: error.localizedDescription
            )
        }
    }

    /// Disconnect from the SRT endpoint.
    public func disconnect() async {
        await disconnectFn()
        _connectionState = .disconnected
    }

    /// Push a completed live segment over SRT.
    public func push(
        segment: LiveSegment, as filename: String
    ) async throws {
        try await sendData(segment.data)
    }

    /// Push a partial segment over SRT.
    public func push(
        partial: LLPartialSegment, as filename: String
    ) async throws {
        // LLPartialSegment is metadata-only; send empty data.
        try await sendData(Data())
    }

    /// Push a playlist as UTF-8 data over SRT.
    ///
    /// Some SRT setups handle playlist distribution alongside
    /// segment data.
    public func pushPlaylist(
        _ m3u8: String, as filename: String
    ) async throws {
        try await sendData(Data(m3u8.utf8))
    }

    /// Push an init segment over SRT.
    public func pushInitSegment(
        _ data: Data, as filename: String
    ) async throws {
        try await sendData(data)
    }

    // MARK: - SRT-specific

    /// Current network statistics from the SRT transport.
    public var networkStats: SRTNetworkStats? {
        get async {
            await networkStatsFn()
        }
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
