// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Transcoder that delegates to cloud services via REST APIs.
///
/// Implements the same ``Transcoder`` protocol as ``AppleTranscoder``
/// and ``FFmpegTranscoder``, but offloads encoding to a cloud
/// provider (Cloudflare Stream, AWS MediaConvert, or Mux).
///
/// ## Usage
///
/// ```swift
/// let config = ManagedTranscodingConfig(
///     provider: .cloudflareStream,
///     apiKey: "your-api-key",
///     accountID: "your-account-id"
/// )
/// let transcoder = ManagedTranscoder(config: config)
/// let result = try await transcoder.transcode(
///     input: sourceURL,
///     outputDirectory: outputDir,
///     config: TranscodingConfig(),
///     progress: { print("Progress: \($0 * 100)%") }
/// )
/// ```
///
/// - SeeAlso: ``ManagedTranscodingProvider``,
///   ``ManagedTranscodingConfig``
public struct ManagedTranscoder: Transcoder, Sendable {

    private let managedConfig: ManagedTranscodingConfig
    private let provider: SendableProvider
    private let httpClient: HTTPClient

    /// Creates a managed transcoder with the specified
    /// configuration.
    ///
    /// Selects the appropriate cloud provider based on the
    /// configuration.
    ///
    /// - Parameter config: Cloud provider configuration.
    public init(config: ManagedTranscodingConfig) {
        self.managedConfig = config
        self.httpClient = URLSessionHTTPClient()
        switch config.provider {
        case .cloudflareStream:
            self.provider = SendableProvider(
                CloudflareStreamProvider(
                    httpClient: self.httpClient
                )
            )
        case .awsMediaConvert:
            self.provider = SendableProvider(
                AWSMediaConvertProvider()
            )
        case .mux:
            self.provider = SendableProvider(MuxProvider())
        }
    }

    /// Creates a managed transcoder with a custom provider
    /// (for testing).
    ///
    /// - Parameters:
    ///   - config: Cloud provider configuration.
    ///   - provider: Custom provider implementation.
    ///   - httpClient: Custom HTTP client.
    init<P: ManagedTranscodingProvider>(
        config: ManagedTranscodingConfig,
        provider: P,
        httpClient: HTTPClient
    ) {
        self.managedConfig = config
        self.provider = SendableProvider(provider)
        self.httpClient = httpClient
    }

    /// Always available (network-dependent at runtime).
    public static var isAvailable: Bool { true }

    /// Human-readable name.
    public static var name: String { "Managed (Cloud)" }

    // MARK: - Transcoder

    /// Transcode a single file via cloud service.
    public func transcode(
        input: URL,
        outputDirectory: URL,
        config: TranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> TranscodingResult {
        let startTime = Date().timeIntervalSinceReferenceDate

        try validateInputs(input: input)
        try prepareOutputDirectory(outputDirectory)

        progress?(0.05)

        let assetID = try await provider.upload(
            fileURL: input,
            config: managedConfig,
            progress: { p in
                progress?(0.05 + p * 0.25)
            }
        )

        progress?(0.30)

        var job = try await provider.createJob(
            assetID: assetID,
            variants: [.p720],
            config: managedConfig
        )

        job = try await pollUntilComplete(
            job: job, progress: progress
        )

        progress?(0.80)

        let files = try await provider.download(
            job: job,
            outputDirectory: outputDirectory,
            config: managedConfig,
            progress: { p in
                progress?(0.80 + p * 0.15)
            }
        )

        if managedConfig.cleanupAfterDownload {
            try? await provider.cleanup(
                job: job, config: managedConfig
            )
        }

        progress?(1.0)

        let elapsed =
            Date().timeIntervalSinceReferenceDate - startTime
        let outputSize = files.reduce(UInt64(0)) { total, url in
            let attrs =
                try? FileManager.default.attributesOfItem(
                    atPath: url.path
                )
            return total + (attrs?[.size] as? UInt64 ?? 0)
        }

        return TranscodingResult(
            preset: .p720,
            outputDirectory: outputDirectory,
            transcodingDuration: elapsed,
            sourceDuration: 0,
            outputSize: outputSize
        )
    }
}

// MARK: - Polling

extension ManagedTranscoder {

    private func pollUntilComplete(
        job: ManagedTranscodingJob,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> ManagedTranscodingJob {
        var current = job
        let deadline =
            Date().timeIntervalSinceReferenceDate
            + managedConfig.timeout

        while !current.isTerminal {
            let now = Date().timeIntervalSinceReferenceDate
            guard now < deadline else {
                throw TranscodingError.timeout(
                    "Timeout after \(managedConfig.timeout)s"
                )
            }

            try await Task.sleep(
                for: .seconds(managedConfig.pollingInterval)
            )

            current = try await provider.checkStatus(
                job: current, config: managedConfig
            )

            if let p = current.progress {
                progress?(0.30 + p * 0.50)
            }
        }

        if current.status == .failed {
            throw TranscodingError.jobFailed(
                current.errorMessage
                    ?? "Cloud transcoding failed"
            )
        }

        if current.status == .cancelled {
            throw TranscodingError.cancelled
        }

        return current
    }
}

// MARK: - Validation

extension ManagedTranscoder {

    private func validateInputs(input: URL) throws {
        guard
            FileManager.default.fileExists(atPath: input.path)
        else {
            throw TranscodingError.sourceNotFound(
                input.lastPathComponent
            )
        }

        guard !managedConfig.apiKey.isEmpty else {
            throw TranscodingError.authenticationFailed(
                "API key is empty"
            )
        }

        guard !managedConfig.accountID.isEmpty else {
            throw TranscodingError.authenticationFailed(
                "Account ID is empty"
            )
        }
    }

    private func prepareOutputDirectory(_ url: URL) throws {
        var isDir: ObjCBool = false
        if !FileManager.default.fileExists(
            atPath: url.path, isDirectory: &isDir
        ) {
            do {
                try FileManager.default.createDirectory(
                    at: url,
                    withIntermediateDirectories: true
                )
            } catch {
                throw TranscodingError.outputDirectoryError(
                    error.localizedDescription
                )
            }
        } else if !isDir.boolValue {
            throw TranscodingError.outputDirectoryError(
                "Path exists but is not a directory: \(url.path)"
            )
        }
    }
}

// MARK: - Type-Erased Provider

/// Type-erased wrapper for ``ManagedTranscodingProvider``.
///
/// Avoids `any Protocol` while supporting different provider types.
struct SendableProvider: ManagedTranscodingProvider, Sendable {

    static var name: String { "Wrapped" }

    private let _upload:
        @Sendable (
            URL, ManagedTranscodingConfig,
            (@Sendable (Double) -> Void)?
        ) async throws -> String

    private let _createJob:
        @Sendable (
            String, [QualityPreset], ManagedTranscodingConfig
        ) async throws -> ManagedTranscodingJob

    private let _checkStatus:
        @Sendable (
            ManagedTranscodingJob, ManagedTranscodingConfig
        ) async throws -> ManagedTranscodingJob

    private let _download:
        @Sendable (
            ManagedTranscodingJob, URL, ManagedTranscodingConfig,
            (@Sendable (Double) -> Void)?
        ) async throws -> [URL]

    private let _cleanup:
        @Sendable (
            ManagedTranscodingJob, ManagedTranscodingConfig
        ) async throws -> Void

    init<P: ManagedTranscodingProvider>(_ provider: P) {
        self._upload = { url, config, progress in
            try await provider.upload(
                fileURL: url, config: config,
                progress: progress
            )
        }
        self._createJob = { assetID, variants, config in
            try await provider.createJob(
                assetID: assetID, variants: variants,
                config: config
            )
        }
        self._checkStatus = { job, config in
            try await provider.checkStatus(
                job: job, config: config
            )
        }
        self._download = { job, dir, config, progress in
            try await provider.download(
                job: job, outputDirectory: dir,
                config: config, progress: progress
            )
        }
        self._cleanup = { job, config in
            try await provider.cleanup(
                job: job, config: config
            )
        }
    }

    func upload(
        fileURL: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> String {
        try await _upload(fileURL, config, progress)
    }

    func createJob(
        assetID: String,
        variants: [QualityPreset],
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        try await _createJob(assetID, variants, config)
    }

    func checkStatus(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        try await _checkStatus(job, config)
    }

    func download(
        job: ManagedTranscodingJob,
        outputDirectory: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> [URL] {
        try await _download(
            job, outputDirectory, config, progress
        )
    }

    func cleanup(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws {
        try await _cleanup(job, config)
    }
}
