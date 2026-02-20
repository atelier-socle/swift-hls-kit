// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

private let muxAPIBaseString = "https://api.mux.com"
private let muxStreamBaseString = "https://stream.mux.com"

/// Mux Video transcoding provider.
///
/// Uses Mux's REST API for video encoding and delivery.
/// Mux automatically handles transcoding and adaptive
/// bitrate.
///
/// ## Configuration
/// - `apiKey`: `"MUX_TOKEN_ID:MUX_TOKEN_SECRET"`
/// - `accountID`: Not used by Mux (token-based auth)
///
/// - SeeAlso: ``ManagedTranscoder``,
///   ``ManagedTranscodingProvider``
struct MuxProvider: ManagedTranscodingProvider, Sendable {

    static var name: String { "Mux" }

    private let httpClient: HTTPClient

    /// Creates a Mux provider.
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
        let auth = basicAuth(config.apiKey)
        let baseURL = try apiBaseURL(config: config)
        let uploadsURL = baseURL.appendingPathComponent(
            "video/v1/uploads"
        )

        let requestBody: [String: Any] = [
            "new_asset_settings": [
                "playback_policy": ["public"]
            ],
            "cors_origin": "*"
        ]

        let body = try JSONSerialization.data(
            withJSONObject: requestBody
        )

        let response = try await httpClient.request(
            url: uploadsURL, method: "POST",
            headers: [
                "Authorization": auth,
                "Content-Type": "application/json"
            ],
            body: body
        )

        guard (200..<300).contains(response.statusCode)
        else {
            throw TranscodingError.uploadFailed(
                "Mux upload creation failed: "
                    + "HTTP \(response.statusCode)"
            )
        }

        let (uploadID, uploadURL) =
            try parseUploadResponse(response.body)

        let uploadResponse = try await httpClient.upload(
            url: uploadURL, fileURL: fileURL,
            method: "PUT",
            headers: [
                "Content-Type": "application/octet-stream"
            ],
            progress: progress
        )

        guard
            (200..<300).contains(
                uploadResponse.statusCode
            )
        else {
            throw TranscodingError.uploadFailed(
                "File upload failed: "
                    + "HTTP \(uploadResponse.statusCode)"
            )
        }

        return uploadID
    }

    // MARK: - Create Job

    func createJob(
        assetID: String,
        variants: [QualityPreset],
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        let auth = basicAuth(config.apiKey)
        let baseURL = try apiBaseURL(config: config)
        let uploadURL = baseURL.appendingPathComponent(
            "video/v1/uploads/\(assetID)"
        )

        let response = try await httpClient.request(
            url: uploadURL, method: "GET",
            headers: ["Authorization": auth],
            body: nil
        )

        guard (200..<300).contains(response.statusCode)
        else {
            throw TranscodingError.jobFailed(
                "Mux upload check failed: "
                    + "HTTP \(response.statusCode)"
            )
        }

        let muxAssetID = try extractAssetID(
            from: response.body
        )

        return ManagedTranscodingJob(
            jobID: muxAssetID, assetID: assetID,
            status: .processing
        )
    }

    // MARK: - Check Status

    func checkStatus(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        let auth = basicAuth(config.apiKey)
        let baseURL = try apiBaseURL(config: config)
        let assetURL = baseURL.appendingPathComponent(
            "video/v1/assets/\(job.jobID)"
        )

        let response = try await httpClient.request(
            url: assetURL, method: "GET",
            headers: ["Authorization": auth],
            body: nil
        )

        guard (200..<300).contains(response.statusCode)
        else {
            throw TranscodingError.jobFailed(
                "Mux status check failed: "
                    + "HTTP \(response.statusCode)"
            )
        }

        return try parseAssetStatus(
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
        guard let playbackURL = job.outputURLs.first else {
            throw TranscodingError.downloadFailed(
                "No playback URL available"
            )
        }

        let destination =
            outputDirectory
            .appendingPathComponent("master.m3u8")

        try await httpClient.download(
            url: playbackURL, to: destination,
            headers: [:], progress: progress
        )

        return [destination]
    }

    // MARK: - Cleanup

    func cleanup(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws {
        let auth = basicAuth(config.apiKey)
        let baseURL = try apiBaseURL(config: config)
        let assetURL = baseURL.appendingPathComponent(
            "video/v1/assets/\(job.jobID)"
        )

        let response = try await httpClient.request(
            url: assetURL, method: "DELETE",
            headers: ["Authorization": auth],
            body: nil
        )

        guard (200..<300).contains(response.statusCode)
        else {
            throw TranscodingError.jobFailed(
                "Mux cleanup failed: "
                    + "HTTP \(response.statusCode)"
            )
        }
    }
}

// MARK: - Private Helpers

extension MuxProvider {

    private func basicAuth(
        _ apiKey: String
    ) -> String {
        let data = Data(apiKey.utf8)
        return "Basic \(data.base64EncodedString())"
    }

    private func apiBaseURL(
        config: ManagedTranscodingConfig
    ) throws -> URL {
        if let endpoint = config.endpoint {
            return endpoint
        }
        guard let url = URL(string: muxAPIBaseString) else {
            throw TranscodingError.invalidConfig(
                "Invalid Mux API URL"
            )
        }
        return url
    }

    private func parseUploadResponse(
        _ data: Data
    ) throws -> (uploadID: String, uploadURL: URL) {
        let json = try JSONSerialization.jsonObject(
            with: data
        )
        guard
            let root = json as? [String: Any],
            let result = root["data"] as? [String: Any],
            let uploadID = result["id"] as? String,
            let urlString = result["url"] as? String,
            let uploadURL = URL(string: urlString)
        else {
            throw TranscodingError.uploadFailed(
                "Invalid Mux upload response"
            )
        }
        return (uploadID, uploadURL)
    }

    private func extractAssetID(
        from data: Data
    ) throws -> String {
        let json = try JSONSerialization.jsonObject(
            with: data
        )
        guard
            let root = json as? [String: Any],
            let result = root["data"] as? [String: Any],
            let assetID = result["asset_id"] as? String
        else {
            throw TranscodingError.jobFailed(
                "Missing asset_id in Mux upload response"
            )
        }
        return assetID
    }

    private func parseAssetStatus(
        data: Data,
        job: ManagedTranscodingJob
    ) throws -> ManagedTranscodingJob {
        let json = try JSONSerialization.jsonObject(
            with: data
        )
        guard
            let root = json as? [String: Any],
            let result = root["data"] as? [String: Any],
            let status = result["status"] as? String
        else {
            throw TranscodingError.jobFailed(
                "Invalid Mux asset status response"
            )
        }

        var updated = job

        switch status {
        case "ready":
            updated.status = .completed
            updated.progress = 1.0
            updated.completedAt = Date()
            if let playbackIDs = result["playback_ids"]
                as? [[String: Any]],
                let first = playbackIDs.first,
                let pid = first["id"] as? String,
                let url = URL(
                    string:
                        "\(muxStreamBaseString)/\(pid).m3u8"
                )
            {
                updated.outputURLs = [url]
            }
        case "errored":
            updated.status = .failed
            let errors =
                result["errors"] as? [String: Any]
            updated.errorMessage =
                errors?["type"] as? String
                ?? "Mux transcoding failed"
        default:
            updated.status = .processing
            if let tracks = result["tracks"]
                as? [[String: Any]]
            {
                let total = Double(tracks.count)
                let ready = Double(
                    tracks.filter {
                        ($0["status"] as? String)
                            == "ready"
                    }.count
                )
                updated.progress =
                    total > 0
                    ? ready / total : 0
            }
        }

        return updated
    }
}
