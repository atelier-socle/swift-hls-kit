// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

// MARK: - AWS Credentials

/// Parsed AWS access key pair.
struct AWSCredentials: Sendable {
    let accessKeyID: String
    let secretAccessKey: String
}

// MARK: - Config Validation

extension AWSMediaConvertProvider {

    func parseCredentials(
        _ apiKey: String
    ) throws -> AWSCredentials {
        let parts = apiKey.split(
            separator: ":", maxSplits: 1
        )
        guard parts.count == 2 else {
            throw TranscodingError.authenticationFailed(
                "AWS apiKey must be "
                    + "ACCESS_KEY_ID:SECRET_ACCESS_KEY"
            )
        }
        return AWSCredentials(
            accessKeyID: String(parts[0]),
            secretAccessKey: String(parts[1])
        )
    }

    func requireAWSConfig(
        _ config: ManagedTranscodingConfig
    ) throws -> (region: String, bucket: String) {
        guard let region = config.region else {
            throw TranscodingError.invalidConfig(
                "region is required for AWS MediaConvert"
            )
        }
        guard let bucket = config.storageBucket else {
            throw TranscodingError.invalidConfig(
                "storageBucket is required for "
                    + "AWS MediaConvert"
            )
        }
        return (region, bucket)
    }
}

// MARK: - URL Builders

extension AWSMediaConvertProvider {

    func s3ObjectURL(
        bucket: String, region: String, key: String
    ) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host =
            "\(bucket).s3.\(region).amazonaws.com"
        components.path = "/\(key)"
        guard let url = components.url else {
            throw TranscodingError.invalidConfig(
                "Invalid S3 URL"
            )
        }
        return url
    }

    func mediaConvertEndpoint(
        config: ManagedTranscodingConfig,
        region: String
    ) throws -> URL {
        if let endpoint = config.endpoint {
            return endpoint
        }
        let urlString =
            "https://mediaconvert.\(region).amazonaws.com"
        guard let url = URL(string: urlString) else {
            throw TranscodingError.invalidConfig(
                "Invalid MediaConvert endpoint URL"
            )
        }
        return url
    }
}

// MARK: - Response Parsing

extension AWSMediaConvertProvider {

    func extractJobID(from data: Data) throws -> String {
        let json = try JSONSerialization.jsonObject(
            with: data
        )
        guard
            let root = json as? [String: Any],
            let job = root["job"] as? [String: Any],
            let jobID = job["id"] as? String
        else {
            throw TranscodingError.jobFailed(
                "Missing job ID in MediaConvert response"
            )
        }
        return jobID
    }

    func parseJobStatus(
        data: Data, job: ManagedTranscodingJob
    ) throws -> ManagedTranscodingJob {
        let json = try JSONSerialization.jsonObject(
            with: data
        )
        guard
            let root = json as? [String: Any],
            let jobData = root["job"] as? [String: Any],
            let status = jobData["status"] as? String
        else {
            throw TranscodingError.jobFailed(
                "Invalid status response"
            )
        }

        var updated = job
        let pct =
            jobData["jobPercentComplete"] as? Int ?? 0

        switch status {
        case "COMPLETE":
            updated.status = .completed
            updated.progress = 1.0
            updated.completedAt = Date()
        case "ERROR":
            updated.status = .failed
            updated.errorMessage =
                jobData["errorMessage"] as? String
                ?? "MediaConvert transcoding failed"
        case "CANCELED":
            updated.status = .cancelled
        default:
            updated.status = .processing
            updated.progress = Double(pct) / 100.0
        }

        return updated
    }
}

// MARK: - S3 Operations

extension AWSMediaConvertProvider {

    func listS3Objects(
        bucket: String,
        region: String,
        prefix: String,
        credentials: AWSCredentials
    ) async throws -> [String] {
        var components = URLComponents()
        components.scheme = "https"
        components.host =
            "\(bucket).s3.\(region).amazonaws.com"
        components.path = "/"
        components.queryItems = [
            URLQueryItem(name: "list-type", value: "2"),
            URLQueryItem(name: "prefix", value: prefix)
        ]

        guard let url = components.url else {
            throw TranscodingError.downloadFailed(
                "Invalid S3 list URL"
            )
        }

        let signer = AWSSignatureV4(
            accessKeyID: credentials.accessKeyID,
            secretAccessKey: credentials.secretAccessKey,
            region: region, service: "s3"
        )

        let headers = signer.sign(
            method: "GET", url: url,
            headers: [:], payload: nil
        )

        let response = try await httpClient.request(
            url: url, method: "GET",
            headers: headers, body: nil
        )

        guard (200..<300).contains(response.statusCode)
        else {
            throw TranscodingError.downloadFailed(
                "S3 list failed: HTTP \(response.statusCode)"
            )
        }

        return extractS3Keys(from: response.body)
    }

    func extractS3Keys(from data: Data) -> [String] {
        guard
            let xml = String(data: data, encoding: .utf8)
        else { return [] }

        var keys: [String] = []
        var searchRange = xml.startIndex..<xml.endIndex

        while let startRange = xml.range(
            of: "<Key>", range: searchRange
        ) {
            let valueStart = startRange.upperBound
            guard
                let endRange = xml.range(
                    of: "</Key>",
                    range: valueStart..<xml.endIndex
                )
            else { break }

            let key = String(
                xml[valueStart..<endRange.lowerBound]
            )
            keys.append(key)
            searchRange = endRange.upperBound..<xml.endIndex
        }

        return keys
    }

    func deleteS3Object(
        bucket: String,
        region: String,
        key: String,
        credentials: AWSCredentials
    ) async throws {
        let url = try s3ObjectURL(
            bucket: bucket, region: region, key: key
        )

        let signer = AWSSignatureV4(
            accessKeyID: credentials.accessKeyID,
            secretAccessKey: credentials.secretAccessKey,
            region: region, service: "s3"
        )

        let headers = signer.sign(
            method: "DELETE", url: url,
            headers: [:], payload: nil
        )

        let response = try await httpClient.request(
            url: url, method: "DELETE",
            headers: headers, body: nil
        )

        guard
            (200..<300).contains(response.statusCode)
                || response.statusCode == 404
        else {
            throw TranscodingError.jobFailed(
                "S3 delete failed: "
                    + "HTTP \(response.statusCode)"
            )
        }
    }
}
