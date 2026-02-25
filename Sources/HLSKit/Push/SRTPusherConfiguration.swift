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
}
