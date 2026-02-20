// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol for cloud transcoding service providers.
///
/// Each provider handles the specifics of communicating with a
/// particular cloud transcoding API (upload, job creation, polling,
/// download).
///
/// ## Implementations
/// - ``CloudflareStreamProvider`` — Cloudflare Stream API
/// - ``AWSMediaConvertProvider`` — AWS Elemental MediaConvert
/// - ``MuxProvider`` — Mux Video API
///
/// - SeeAlso: ``ManagedTranscoder``
public protocol ManagedTranscodingProvider: Sendable {

    /// Human-readable name (e.g., "Cloudflare Stream").
    static var name: String { get }

    /// Upload source media to the service.
    ///
    /// - Parameters:
    ///   - fileURL: Local file to upload.
    ///   - config: Provider-specific configuration.
    ///   - progress: Upload progress callback (0.0 to 1.0).
    /// - Returns: Remote asset identifier (provider-specific ID).
    /// - Throws: ``TranscodingError/uploadFailed(_:)``
    func upload(
        fileURL: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> String

    /// Create a transcoding job.
    ///
    /// - Parameters:
    ///   - assetID: Remote asset identifier from upload.
    ///   - variants: Quality variants to produce.
    ///   - config: Provider-specific configuration.
    /// - Returns: Job identifier for polling.
    /// - Throws: ``TranscodingError/jobFailed(_:)``
    func createJob(
        assetID: String,
        variants: [QualityPreset],
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob

    /// Poll job status.
    ///
    /// - Parameters:
    ///   - job: Job to check.
    ///   - config: Provider-specific configuration.
    /// - Returns: Updated job with current status.
    /// - Throws: ``TranscodingError``
    func checkStatus(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob

    /// Download transcoded output.
    ///
    /// Downloads all transcoded variants (segments + playlists)
    /// to a local directory.
    ///
    /// - Parameters:
    ///   - job: Completed job.
    ///   - outputDirectory: Local directory for downloaded files.
    ///   - config: Provider-specific configuration.
    ///   - progress: Download progress callback (0.0 to 1.0).
    /// - Returns: List of downloaded file URLs.
    /// - Throws: ``TranscodingError/downloadFailed(_:)``
    func download(
        job: ManagedTranscodingJob,
        outputDirectory: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> [URL]

    /// Delete remote assets after download (cleanup).
    ///
    /// - Parameters:
    ///   - job: Job whose assets should be cleaned up.
    ///   - config: Provider-specific configuration.
    func cleanup(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws
}
