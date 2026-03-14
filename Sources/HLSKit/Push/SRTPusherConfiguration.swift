// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Configuration for SRT-based segment pushing.
///
/// Defines the SRT host, port, connection options, and retry
/// behavior for ultra-low-latency segment delivery.
public struct SRTPusherConfiguration: Sendable, Equatable {

    /// SRT host address.
    public var host: String

    /// SRT port number.
    public var port: Int

    /// SRT connection options.
    public var options: SRTOptions

    /// Retry policy for reconnection.
    public var retryPolicy: PushRetryPolicy

    /// Creates an SRT pusher configuration.
    ///
    /// - Parameters:
    ///   - host: SRT host address.
    ///   - port: SRT port number.
    ///   - options: Connection options. Default `.default`.
    ///   - retryPolicy: Retry policy. Default `.default`.
    public init(
        host: String,
        port: Int,
        options: SRTOptions = .default,
        retryPolicy: PushRetryPolicy = .default
    ) {
        self.host = host
        self.port = port
        self.options = options
        self.retryPolicy = retryPolicy
    }

    // MARK: - Presets

    /// Low-latency configuration with default options.
    ///
    /// - Parameters:
    ///   - host: SRT host address.
    ///   - port: SRT port. Default `9000`.
    /// - Returns: Configuration optimized for low latency.
    public static func lowLatency(
        host: String, port: Int = 9000
    ) -> SRTPusherConfiguration {
        SRTPusherConfiguration(
            host: host,
            port: port,
            options: SRTOptions(latency: 50),
            retryPolicy: .aggressive
        )
    }

    /// Encrypted configuration with a passphrase.
    ///
    /// - Parameters:
    ///   - host: SRT host address.
    ///   - port: SRT port. Default `9000`.
    ///   - passphrase: AES encryption passphrase.
    /// - Returns: Configuration with encryption enabled.
    public static func encrypted(
        host: String,
        port: Int = 9000,
        passphrase: String
    ) -> SRTPusherConfiguration {
        SRTPusherConfiguration(
            host: host,
            port: port,
            options: .encrypted(passphrase: passphrase)
        )
    }

    // MARK: - Presets (0.6.0)

    /// Rendezvous mode configuration with encryption.
    ///
    /// Both sides initiate connection simultaneously,
    /// useful for NAT traversal. Matches SRTKit 0.1.0's
    /// rendezvous connection mode.
    ///
    /// - Parameters:
    ///   - host: SRT host address.
    ///   - port: SRT port. Default `9000`.
    ///   - passphrase: AES encryption passphrase.
    /// - Returns: Configuration for rendezvous mode.
    public static func rendezvous(
        host: String,
        port: Int = 9000,
        passphrase: String
    ) -> SRTPusherConfiguration {
        SRTPusherConfiguration(
            host: host,
            port: port,
            options: SRTOptions(
                passphrase: passphrase,
                mode: .rendezvous
            )
        )
    }

    /// High-throughput configuration for bulk transfer.
    ///
    /// Uses file congestion control (AIMD windowing) and
    /// higher latency for maximum throughput. Matches
    /// SRTKit 0.1.0's FileCC algorithm.
    ///
    /// - Parameters:
    ///   - host: SRT host address.
    ///   - port: SRT port. Default `9000`.
    /// - Returns: Configuration optimized for throughput.
    public static func highThroughput(
        host: String, port: Int = 9000
    ) -> SRTPusherConfiguration {
        SRTPusherConfiguration(
            host: host,
            port: port,
            options: SRTOptions(
                latency: 500,
                congestionControl: .file
            )
        )
    }

    /// FEC-enabled configuration for lossy networks.
    ///
    /// Enables SMPTE 2022-1 forward error correction for
    /// packet loss recovery without retransmission. Matches
    /// SRTKit 0.1.0's FEC subsystem.
    ///
    /// - Parameters:
    ///   - host: SRT host address.
    ///   - port: SRT port. Default `9000`.
    ///   - layout: FEC packet layout. Default `.staircase`.
    /// - Returns: Configuration with FEC enabled.
    public static func fec(
        host: String,
        port: Int = 9000,
        layout: SRTFECConfiguration.Layout = .staircase
    ) -> SRTPusherConfiguration {
        SRTPusherConfiguration(
            host: host,
            port: port,
            options: SRTOptions(
                fecConfiguration: SRTFECConfiguration(
                    layout: layout, rows: 5, columns: 5
                )
            )
        )
    }

    /// Broadcast-optimized configuration.
    ///
    /// Combines low latency (50ms) with encryption for
    /// secure live broadcast. Uses aggressive retry for
    /// uninterrupted delivery.
    ///
    /// - Parameters:
    ///   - host: SRT host address.
    ///   - port: SRT port. Default `9000`.
    ///   - passphrase: AES encryption passphrase.
    /// - Returns: Configuration for broadcast use.
    public static func broadcast(
        host: String,
        port: Int = 9000,
        passphrase: String
    ) -> SRTPusherConfiguration {
        SRTPusherConfiguration(
            host: host,
            port: port,
            options: SRTOptions(
                passphrase: passphrase,
                latency: 50,
                congestionControl: .live
            ),
            retryPolicy: .aggressive
        )
    }
}
