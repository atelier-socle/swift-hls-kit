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

    // v2 transport closures.
    private let connectionQualityFn: @Sendable () async -> SRTConnectionQuality?
    private let isEncryptedFn: @Sendable () async -> Bool
    private let qualityAwareQualityFn: (@Sendable () async -> TransportQuality?)?

    /// Stream of transport events from the underlying transport.
    ///
    /// Returns an active stream if the transport conforms to
    /// ``QualityAwareTransport``, otherwise an empty completed stream.
    public nonisolated let transportEvents: AsyncStream<TransportEvent>

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
        self.connectionQualityFn = {
            await transport.connectionQuality
        }
        self.isEncryptedFn = {
            await transport.isEncrypted
        }

        // Capture quality-aware capabilities if the transport
        // conforms to QualityAwareTransport.
        if let qualityTransport = transport as? any QualityAwareTransport {
            self.qualityAwareQualityFn = {
                await qualityTransport.connectionQuality
            }
            self.transportEvents = qualityTransport.transportEvents
        } else {
            self.qualityAwareQualityFn = nil
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

    // MARK: - Transport v2

    /// Current transport quality, if the underlying transport
    /// conforms to ``QualityAwareTransport``.
    ///
    /// Returns `nil` when the transport does not support quality
    /// reporting.
    public var transportQuality: TransportQuality? {
        get async {
            guard let fn = qualityAwareQualityFn else { return nil }
            return await fn()
        }
    }

    /// SRT-specific connection quality from the transport.
    ///
    /// Delegates to the transport's
    /// ``SRTTransport/connectionQuality`` property.
    public var connectionQuality: SRTConnectionQuality? {
        get async {
            await connectionQualityFn()
        }
    }

    /// Whether the SRT connection is using AES encryption.
    ///
    /// Delegates to the transport's
    /// ``SRTTransport/isEncrypted`` property.
    public var isEncrypted: Bool {
        get async {
            await isEncryptedFn()
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
