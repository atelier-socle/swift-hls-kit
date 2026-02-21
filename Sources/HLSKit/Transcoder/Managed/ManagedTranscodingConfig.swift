// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for managed (cloud) transcoding.
///
/// Contains API credentials and provider-specific settings.
/// Sensitive values (API keys) should come from environment
/// variables or a secrets manager, never hardcoded.
///
/// ```swift
/// let config = ManagedTranscodingConfig(
///     provider: .cloudflareStream,
///     apiKey: ProcessInfo.processInfo.environment["CF_API_KEY"] ?? "",
///     accountID: ProcessInfo.processInfo.environment["CF_ACCOUNT_ID"] ?? ""
/// )
/// ```
///
/// - SeeAlso: ``ManagedTranscoder``
public struct ManagedTranscodingConfig: Sendable {

    /// Which cloud provider to use.
    public var provider: ProviderType

    /// API key or token.
    public var apiKey: String

    /// Account/project identifier.
    public var accountID: String

    /// Optional custom API endpoint (for testing or private
    /// instances).
    public var endpoint: URL?

    /// Optional AWS region (for MediaConvert).
    public var region: String?

    /// Optional S3 bucket for input/output (for MediaConvert).
    public var storageBucket: String?

    /// Optional IAM role ARN (for MediaConvert).
    public var roleARN: String?

    /// Polling interval in seconds (default: 5).
    public var pollingInterval: TimeInterval

    /// Maximum wait time in seconds before timeout
    /// (default: 3600 = 1 hour).
    public var timeout: TimeInterval

    /// Whether to delete remote assets after download
    /// (default: true).
    public var cleanupAfterDownload: Bool

    /// Default quality preset for single-variant transcoding.
    /// Default: `.p720` (standard HD, matching Apple/FFmpeg).
    public var defaultPreset: QualityPreset

    /// Output container format preference.
    public var outputFormat: OutputFormat

    /// Supported provider types.
    public enum ProviderType: String, Sendable, Hashable, Codable {

        /// Cloudflare Stream API.
        case cloudflareStream

        /// AWS Elemental MediaConvert.
        case awsMediaConvert

        /// Mux Video API.
        case mux
    }

    /// Output format.
    public enum OutputFormat: String, Sendable, Hashable, Codable {

        /// Fragmented MP4 (preferred).
        case fmp4

        /// MPEG-TS.
        case ts
    }

    /// Creates a managed transcoding configuration.
    ///
    /// - Parameters:
    ///   - provider: Cloud provider to use.
    ///   - apiKey: API key or token.
    ///   - accountID: Account/project identifier.
    ///   - endpoint: Custom API endpoint.
    ///   - region: AWS region.
    ///   - storageBucket: S3 bucket name.
    ///   - roleARN: IAM role ARN.
    ///   - pollingInterval: Status polling interval in seconds.
    ///   - timeout: Maximum wait time in seconds.
    ///   - cleanupAfterDownload: Whether to delete remote assets.
    ///   - defaultPreset: Quality preset for single-variant
    ///     transcoding.
    ///   - outputFormat: Output container format.
    public init(
        provider: ProviderType,
        apiKey: String,
        accountID: String,
        endpoint: URL? = nil,
        region: String? = nil,
        storageBucket: String? = nil,
        roleARN: String? = nil,
        pollingInterval: TimeInterval = 5,
        timeout: TimeInterval = 3600,
        cleanupAfterDownload: Bool = true,
        defaultPreset: QualityPreset = .p720,
        outputFormat: OutputFormat = .fmp4
    ) {
        self.provider = provider
        self.apiKey = apiKey
        self.accountID = accountID
        self.endpoint = endpoint
        self.region = region
        self.storageBucket = storageBucket
        self.roleARN = roleARN
        self.pollingInterval = pollingInterval
        self.timeout = timeout
        self.cleanupAfterDownload = cleanupAfterDownload
        self.defaultPreset = defaultPreset
        self.outputFormat = outputFormat
    }
}
