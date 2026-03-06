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

    /// Connection mode (caller, listener, or rendezvous).
    ///
    /// Matches SRTKit 0.1.0's `ConnectionMode`. Default is
    /// `.caller` for backward compatibility.
    public var mode: SRTConnectionMode

    /// Forward error correction configuration.
    ///
    /// When set, enables SMPTE 2022-1 compatible FEC for
    /// packet loss recovery without retransmission. Matches
    /// SRTKit 0.1.0's FEC subsystem.
    public var fecConfiguration: SRTFECConfiguration?

    /// Congestion control algorithm.
    ///
    /// `.live` for real-time streaming, `.file` for
    /// high-throughput bulk transfer. Matches SRTKit 0.1.0's
    /// LiveCC and FileCC algorithms.
    public var congestionControl: SRTCongestionControl

    /// ARQ (Automatic Repeat Request) mode for FEC.
    ///
    /// Controls retransmission behavior when FEC is enabled.
    /// Matches SRTKit 0.1.0's `FECConfiguration.ARQMode`.
    public var arqMode: SRTARQMode

    /// Connection group bonding mode.
    ///
    /// When set, enables multi-link bonding for redundancy
    /// or load balancing. Matches SRTKit 0.1.0's connection
    /// group subsystem. `nil` disables bonding.
    public var bondingMode: SRTBondingMode?

    /// Creates SRT connection options.
    ///
    /// - Parameters:
    ///   - passphrase: AES passphrase. Default `nil`.
    ///   - keyLength: Key length. Default `.aes128`.
    ///   - latency: Latency in ms. Default `120`.
    ///   - maxBandwidth: Max bandwidth. Default `0` (unlimited).
    ///   - streamID: Stream ID. Default `nil`.
    ///   - mode: Connection mode. Default `.caller`.
    ///   - fecConfiguration: FEC config. Default `nil`.
    ///   - congestionControl: Congestion algorithm. Default `.live`.
    ///   - arqMode: ARQ mode for FEC. Default `.always`.
    ///   - bondingMode: Bonding mode. Default `nil`.
    public init(
        passphrase: String? = nil,
        keyLength: KeyLength = .aes128,
        latency: Int = 120,
        maxBandwidth: Int64 = 0,
        streamID: String? = nil,
        mode: SRTConnectionMode = .caller,
        fecConfiguration: SRTFECConfiguration? = nil,
        congestionControl: SRTCongestionControl = .live,
        arqMode: SRTARQMode = .always,
        bondingMode: SRTBondingMode? = nil
    ) {
        self.passphrase = passphrase
        self.keyLength = keyLength
        self.latency = latency
        self.maxBandwidth = maxBandwidth
        self.streamID = streamID
        self.mode = mode
        self.fecConfiguration = fecConfiguration
        self.congestionControl = congestionControl
        self.arqMode = arqMode
        self.bondingMode = bondingMode
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

// MARK: - SRT Connection Mode

/// SRT connection mode.
///
/// Matches SRTKit 0.1.0's connection modes: caller initiates
/// to a listener, listener accepts incoming connections, and
/// rendezvous allows both sides to initiate simultaneously.
public enum SRTConnectionMode: String, Sendable, Equatable, CaseIterable {

    /// Initiates connection to a remote listener.
    case caller

    /// Accepts incoming connections.
    case listener

    /// Both sides initiate simultaneously.
    case rendezvous
}

// MARK: - SRT FEC Configuration

/// Forward error correction configuration for SRT.
///
/// Mirrors SRTKit 0.1.0's SMPTE 2022-1 XOR-based FEC with
/// configurable row and column protection.
public struct SRTFECConfiguration: Sendable, Equatable {

    /// FEC packet layout strategy.
    ///
    /// Matches SRTKit 0.1.0's `FECConfiguration.Layout`.
    public enum Layout: String, Sendable, Equatable, CaseIterable {
        /// Row groups align with column groups.
        case even
        /// Row groups offset to spread burst errors.
        case staircase
    }

    /// Packet layout strategy.
    public let layout: Layout

    /// Number of rows in the FEC matrix.
    public let rows: Int

    /// Number of columns in the FEC matrix.
    public let columns: Int

    /// Creates an FEC configuration.
    ///
    /// - Parameters:
    ///   - layout: Packet layout strategy.
    ///   - rows: Number of rows.
    ///   - columns: Number of columns.
    public init(layout: Layout, rows: Int, columns: Int) {
        self.layout = layout
        self.rows = rows
        self.columns = columns
    }

    /// SMPTE 2022-1 standard configuration.
    ///
    /// Uses staircase layout with 5×5 matrix for balanced
    /// burst and random loss protection.
    public static let smpte2022 = SRTFECConfiguration(
        layout: .staircase, rows: 5, columns: 5
    )
}

// MARK: - SRT Congestion Control

/// SRT congestion control algorithm.
///
/// Matches SRTKit 0.1.0's LiveCC (pacing-based, low latency)
/// and FileCC (AIMD windowing, high throughput).
public enum SRTCongestionControl: String, Sendable, Equatable, CaseIterable {

    /// Pacing-based control for real-time streaming.
    case live

    /// AIMD windowing for high-throughput file transfer.
    case file
}

// MARK: - SRT ARQ Mode

/// ARQ (Automatic Repeat Request) mode for SRT FEC.
///
/// Controls retransmission behavior when forward error
/// correction is enabled. Matches SRTKit 0.1.0's
/// `FECConfiguration.ARQMode`.
public enum SRTARQMode: String, Sendable, Equatable, CaseIterable {

    /// FEC and ARQ both active (default).
    case always

    /// FEC first, ARQ only on explicit request.
    case onreq

    /// FEC only, no retransmission.
    case never
}

// MARK: - SRT Bonding Mode

/// Connection group bonding mode for SRT multi-link.
///
/// Matches SRTKit 0.1.0's `GroupMode` for multi-link
/// bonding with broadcast, failover, and load balancing.
public enum SRTBondingMode: String, Sendable, Equatable, CaseIterable {

    /// Send on all links simultaneously; receiver deduplicates.
    case broadcast

    /// One active link with standby backups and failover.
    case mainBackup

    /// Distribute packets across links for aggregate bandwidth.
    case balancing
}

// MARK: - SRT Network Stats

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

    /// Send buffer level in milliseconds.
    public var sendBufferMs: Double

    /// Receive buffer level in milliseconds.
    public var receiveBufferMs: Double

    /// RTT variance (jitter indicator) in seconds.
    public var rttVariance: Double

    /// Flow control window size in packets.
    public var flowWindowSize: Int

    /// Creates SRT network statistics.
    ///
    /// - Parameters:
    ///   - roundTripTime: RTT in seconds.
    ///   - bandwidth: Bandwidth in bytes/sec.
    ///   - packetLossRate: Loss rate (0.0–1.0).
    ///   - retransmitRate: Retransmit rate (0.0–1.0).
    ///   - sendBufferMs: Send buffer in ms. Default `0.0`.
    ///   - receiveBufferMs: Receive buffer in ms. Default `0.0`.
    ///   - rttVariance: RTT variance. Default `0.0`.
    ///   - flowWindowSize: Flow window in packets. Default `0`.
    public init(
        roundTripTime: TimeInterval,
        bandwidth: Double,
        packetLossRate: Double,
        retransmitRate: Double,
        sendBufferMs: Double = 0.0,
        receiveBufferMs: Double = 0.0,
        rttVariance: Double = 0.0,
        flowWindowSize: Int = 0
    ) {
        self.roundTripTime = roundTripTime
        self.bandwidth = bandwidth
        self.packetLossRate = packetLossRate
        self.retransmitRate = retransmitRate
        self.sendBufferMs = sendBufferMs
        self.receiveBufferMs = receiveBufferMs
        self.rttVariance = rttVariance
        self.flowWindowSize = flowWindowSize
    }
}

// MARK: - SRT Transport Protocol

/// Protocol for SRT (Secure Reliable Transport) operations.
///
/// Users implement this with their preferred SRT library
/// (e.g., swift-srt-kit, libsrt wrapper). swift-hls-kit
/// handles the HLS-specific orchestration.
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

    /// SRT-specific connection quality assessment.
    ///
    /// Transports that perform quality scoring (e.g.,
    /// swift-srt-kit 0.1.0) override this to report composite
    /// quality metrics. The default implementation returns `nil`.
    var connectionQuality: SRTConnectionQuality? { get async }

    /// Whether the connection is using AES encryption.
    ///
    /// Transports that detect encryption state during the SRT
    /// handshake override this. The default returns `false`.
    var isEncrypted: Bool { get async }
}

// MARK: - Default Implementations

extension SRTTransport {

    /// Default returns `nil` for backward compatibility.
    public var connectionQuality: SRTConnectionQuality? {
        get async { nil }
    }

    /// Default returns `false` for backward compatibility.
    public var isEncrypted: Bool {
        get async { false }
    }
}
