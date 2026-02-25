// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// SRT connection options.
///
/// Configures encryption, latency, bandwidth, and access
/// control for an SRT connection.
public struct SRTOptions: Sendable, Equatable {

    /// Encryption key length for AES.
    public enum KeyLength: Int, Sendable, Equatable {
        /// AES-128 (16 bytes).
        case aes128 = 16
        /// AES-192 (24 bytes).
        case aes192 = 24
        /// AES-256 (32 bytes).
        case aes256 = 32
    }

    /// Passphrase for AES encryption. `nil` disables encryption.
    public var passphrase: String?

    /// Encryption key length.
    public var keyLength: KeyLength

    /// Latency in milliseconds.
    public var latency: Int

    /// Maximum bandwidth in bytes per second. `0` means unlimited.
    public var maxBandwidth: Int64

    /// Stream ID for SRT access control.
    public var streamID: String?

    /// Creates SRT connection options.
    ///
    /// - Parameters:
    ///   - passphrase: AES passphrase. Default `nil`.
    ///   - keyLength: Key length. Default `.aes128`.
    ///   - latency: Latency in ms. Default `120`.
    ///   - maxBandwidth: Max bandwidth. Default `0` (unlimited).
    ///   - streamID: Stream ID. Default `nil`.
    public init(
        passphrase: String? = nil,
        keyLength: KeyLength = .aes128,
        latency: Int = 120,
        maxBandwidth: Int64 = 0,
        streamID: String? = nil
    ) {
        self.passphrase = passphrase
        self.keyLength = keyLength
        self.latency = latency
        self.maxBandwidth = maxBandwidth
        self.streamID = streamID
    }

    /// Default options: no encryption, 120ms latency, unlimited
    /// bandwidth.
    public static let `default` = SRTOptions()

    /// Encrypted options with a passphrase.
    ///
    /// - Parameters:
    ///   - passphrase: AES passphrase.
    ///   - keyLength: Key length. Default `.aes128`.
    /// - Returns: Configured SRT options.
    public static func encrypted(
        passphrase: String,
        keyLength: KeyLength = .aes128
    ) -> SRTOptions {
        SRTOptions(
            passphrase: passphrase,
            keyLength: keyLength
        )
    }
}

/// Network statistics from an SRT connection.
///
/// Provides real-time transport metrics for monitoring
/// stream health.
public struct SRTNetworkStats: Sendable, Equatable {

    /// Round-trip time in seconds.
    public var roundTripTime: TimeInterval

    /// Estimated bandwidth in bytes per second.
    public var bandwidth: Double

    /// Packet loss rate (0.0–1.0).
    public var packetLossRate: Double

    /// Retransmission rate (0.0–1.0).
    public var retransmitRate: Double

    /// Creates SRT network statistics.
    ///
    /// - Parameters:
    ///   - roundTripTime: RTT in seconds.
    ///   - bandwidth: Bandwidth in bytes/sec.
    ///   - packetLossRate: Loss rate (0.0–1.0).
    ///   - retransmitRate: Retransmit rate (0.0–1.0).
    public init(
        roundTripTime: TimeInterval,
        bandwidth: Double,
        packetLossRate: Double,
        retransmitRate: Double
    ) {
        self.roundTripTime = roundTripTime
        self.bandwidth = bandwidth
        self.packetLossRate = packetLossRate
        self.retransmitRate = retransmitRate
    }
}

/// Protocol for SRT (Secure Reliable Transport) operations.
///
/// Users implement this with their preferred SRT library
/// (e.g., libsrt wrapper). swift-hls-kit handles the
/// HLS-specific orchestration.
public protocol SRTTransport: Sendable {

    /// Connect to an SRT listener.
    ///
    /// - Parameters:
    ///   - host: The SRT host address.
    ///   - port: The SRT port number.
    ///   - options: Connection options.
    func connect(
        to host: String, port: Int, options: SRTOptions
    ) async throws

    /// Disconnect from the SRT endpoint.
    func disconnect() async

    /// Send data over the SRT connection.
    ///
    /// - Parameter data: The data to send.
    func send(_ data: Data) async throws

    /// Whether the transport is currently connected.
    var isConnected: Bool { get async }

    /// Current network statistics from SRT.
    var networkStats: SRTNetworkStats? { get async }
}
