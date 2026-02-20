// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

private let cfBaseURLString =
    "https://api.cloudflare.com/client/v4"

/// Cloudflare Stream API provider for managed transcoding.
///
/// Implements the full upload → transcode → download flow via
/// the Cloudflare Stream REST API.
///
/// - SeeAlso: ``ManagedTranscoder``,
///   ``ManagedTranscodingProvider``
struct CloudflareStreamProvider: ManagedTranscodingProvider,
    Sendable
{

    static var name: String { "Cloudflare Stream" }

    private let httpClient: HTTPClient

    /// Creates a Cloudflare Stream provider.
    ///
    /// - Parameter httpClient: HTTP client for API calls.
    init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    // MARK: - Upload

    func upload(
        fileURL: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> String {
        let uploadURL = try streamURL(config: config)

        let response = try await httpClient.upload(
            url: uploadURL,
            fileURL: fileURL,
            method: "POST",
            headers: [
                "Authorization": "Bearer \(config.apiKey)",
                "Content-Type": "application/octet-stream"
            ],
            progress: progress
        )

        guard (200..<300).contains(response.statusCode) else {
            throw TranscodingError.uploadFailed(
                "HTTP \(response.statusCode)"
            )
        }

        return try extractUID(from: response.body)
    }

    // MARK: - Create Job

    func createJob(
        assetID: String,
        variants: [QualityPreset],
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        ManagedTranscodingJob(
            jobID: assetID,
            assetID: assetID,
            status: .processing
        )
    }

    // MARK: - Check Status

    func checkStatus(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        let statusURL = try streamURL(config: config)
            .appendingPathComponent(job.assetID)

        let response = try await httpClient.request(
            url: statusURL,
            method: "GET",
            headers: [
                "Authorization": "Bearer \(config.apiKey)"
            ],
            body: nil
        )

        guard (200..<300).contains(response.statusCode) else {
            throw TranscodingError.jobFailed(
                "HTTP \(response.statusCode)"
            )
        }

        return try parseStatusResponse(
            data: response.body, job: job
        )
    }

    // MARK: - Download

    func download(
        job: ManagedTranscodingJob,
        outputDirectory: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> [URL] {
        guard !job.outputURLs.isEmpty else {
            throw TranscodingError.downloadFailed(
                "No output URLs available"
            )
        }

        var downloaded: [URL] = []
        let total = Double(job.outputURLs.count)

        for (index, remoteURL) in job.outputURLs.enumerated() {
            let filename =
                remoteURL.lastPathComponent.isEmpty
                ? "output_\(index).m3u8"
                : remoteURL.lastPathComponent
            let destination =
                outputDirectory
                .appendingPathComponent(filename)

            try await httpClient.download(
                url: remoteURL,
                to: destination,
                headers: [
                    "Authorization":
                        "Bearer \(config.apiKey)"
                ],
                progress: nil
            )

            downloaded.append(destination)
            progress?(Double(index + 1) / total)
        }

        return downloaded
    }

    // MARK: - Cleanup

    func cleanup(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws {
        let deleteURL = try streamURL(config: config)
            .appendingPathComponent(job.assetID)

        let response = try await httpClient.request(
            url: deleteURL,
            method: "DELETE",
            headers: [
                "Authorization": "Bearer \(config.apiKey)"
            ],
            body: nil
        )

        guard (200..<300).contains(response.statusCode) else {
            throw TranscodingError.jobFailed(
                "Cleanup failed: HTTP \(response.statusCode)"
            )
        }
    }
}

// MARK: - Private Helpers

extension CloudflareStreamProvider {

    private func streamURL(
        config: ManagedTranscodingConfig
    ) throws -> URL {
        let base: URL
        if let endpoint = config.endpoint {
            base = endpoint
        } else if let url = URL(string: cfBaseURLString) {
            base = url
        } else {
            throw TranscodingError.invalidConfig(
                "Invalid Cloudflare API base URL"
            )
        }
        return
            base
            .appendingPathComponent("accounts")
            .appendingPathComponent(config.accountID)
            .appendingPathComponent("stream")
    }

    private func extractUID(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(with: data)

        guard
            let root = json as? [String: Any],
            let result = root["result"] as? [String: Any],
            let uid = result["uid"] as? String
        else {
            throw TranscodingError.uploadFailed(
                "Missing uid in Cloudflare response"
            )
        }

        return uid
    }

    private func parseStatusResponse(
        data: Data,
        job: ManagedTranscodingJob
    ) throws -> ManagedTranscodingJob {
        let json = try JSONSerialization.jsonObject(with: data)

        guard
            let root = json as? [String: Any],
            let result = root["result"] as? [String: Any],
            let status = result["status"] as? [String: Any],
            let state = status["state"] as? String
        else {
            throw TranscodingError.jobFailed(
                "Invalid status response"
            )
        }

        var updated = job
        let pctComplete =
            status["pctComplete"] as? String ?? "0"
        let pct = Double(pctComplete) ?? 0

        switch state {
        case "ready":
            updated.status = .completed
            updated.progress = 1.0
            updated.completedAt = Date()
            if let playback = result["playback"]
                as? [String: Any],
                let hlsURL = playback["hls"] as? String,
                let url = URL(string: hlsURL)
            {
                updated.outputURLs = [url]
            }
        case "error":
            updated.status = .failed
            updated.errorMessage =
                status["errorReasonText"] as? String
                ?? "Cloudflare transcoding failed"
        default:
            updated.status = .processing
            updated.progress = pct / 100.0
        }

        return updated
    }
}
