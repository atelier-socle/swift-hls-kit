// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// AWS Elemental MediaConvert transcoding provider.
///
/// Uses the MediaConvert REST API for cloud transcoding.
/// Requires an S3 bucket for input/output staging and an
/// IAM role with MediaConvert and S3 permissions.
///
/// ## Configuration
/// - `apiKey`: `"ACCESS_KEY_ID:SECRET_ACCESS_KEY"`
/// - `region`: AWS region (e.g., `"us-east-1"`)
/// - `storageBucket`: S3 bucket for staging
/// - `roleARN`: IAM role ARN for MediaConvert
///
/// - SeeAlso: ``ManagedTranscoder``,
///   ``ManagedTranscodingProvider``
struct AWSMediaConvertProvider: ManagedTranscodingProvider,
    Sendable
{

    static var name: String { "AWS MediaConvert" }

    let httpClient: HTTPClient

    // MARK: - Upload

    func upload(
        fileURL: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> String {
        let (region, bucket) = try requireAWSConfig(config)
        let credentials = try parseCredentials(config.apiKey)
        let assetID = UUID().uuidString

        let s3URL = try s3ObjectURL(
            bucket: bucket, region: region,
            key: "input/\(assetID)/source.mp4"
        )

        let signer = AWSSignatureV4(
            accessKeyID: credentials.accessKeyID,
            secretAccessKey: credentials.secretAccessKey,
            region: region, service: "s3"
        )

        let headers = signer.sign(
            method: "PUT", url: s3URL,
            headers: [
                "Content-Type": "application/octet-stream"
            ],
            payload: nil
        )

        let response = try await httpClient.upload(
            url: s3URL, fileURL: fileURL,
            method: "PUT", headers: headers,
            progress: progress
        )

        guard (200..<300).contains(response.statusCode) else {
            throw TranscodingError.uploadFailed(
                "S3 upload failed: HTTP \(response.statusCode)"
            )
        }

        return assetID
    }

    // MARK: - Create Job

    func createJob(
        assetID: String,
        variants: [QualityPreset],
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        let (region, bucket) = try requireAWSConfig(config)
        let credentials = try parseCredentials(config.apiKey)

        guard let roleARN = config.roleARN else {
            throw TranscodingError.invalidConfig(
                "roleARN is required for AWS MediaConvert"
            )
        }

        let endpoint = try mediaConvertEndpoint(
            config: config, region: region
        )

        let jobsURL = endpoint.appendingPathComponent(
            "2017-08-29/jobs"
        )

        let jobJSON = AWSJobSettingsBuilder.buildJobJSON(
            inputS3Path:
                "s3://\(bucket)/input/\(assetID)/source.mp4",
            outputS3Path:
                "s3://\(bucket)/output/\(assetID)/",
            roleARN: roleARN,
            variants: variants,
            outputFormat: config.outputFormat
        )

        let body = try JSONSerialization.data(
            withJSONObject: jobJSON
        )

        let signer = AWSSignatureV4(
            accessKeyID: credentials.accessKeyID,
            secretAccessKey: credentials.secretAccessKey,
            region: region, service: "mediaconvert"
        )

        let headers = signer.sign(
            method: "POST", url: jobsURL,
            headers: ["Content-Type": "application/json"],
            payload: body
        )

        let response = try await httpClient.request(
            url: jobsURL, method: "POST",
            headers: headers, body: body
        )

        guard (200..<300).contains(response.statusCode) else {
            throw TranscodingError.jobFailed(
                "Job creation failed: HTTP \(response.statusCode)"
            )
        }

        let jobID = try extractJobID(from: response.body)

        return ManagedTranscodingJob(
            jobID: jobID, assetID: assetID,
            status: .queued
        )
    }

    // MARK: - Check Status

    func checkStatus(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        let (region, _) = try requireAWSConfig(config)
        let credentials = try parseCredentials(config.apiKey)

        let endpoint = try mediaConvertEndpoint(
            config: config, region: region
        )

        let statusURL = endpoint.appendingPathComponent(
            "2017-08-29/jobs/\(job.jobID)"
        )

        let signer = AWSSignatureV4(
            accessKeyID: credentials.accessKeyID,
            secretAccessKey: credentials.secretAccessKey,
            region: region, service: "mediaconvert"
        )

        let headers = signer.sign(
            method: "GET", url: statusURL,
            headers: [:], payload: nil
        )

        let response = try await httpClient.request(
            url: statusURL, method: "GET",
            headers: headers, body: nil
        )

        guard (200..<300).contains(response.statusCode) else {
            throw TranscodingError.jobFailed(
                "Status check failed: HTTP \(response.statusCode)"
            )
        }

        return try parseJobStatus(
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
        let (region, bucket) = try requireAWSConfig(config)
        let credentials = try parseCredentials(config.apiKey)

        let keys = try await listS3Objects(
            bucket: bucket, region: region,
            prefix: "output/\(job.assetID)/",
            credentials: credentials
        )

        guard !keys.isEmpty else {
            throw TranscodingError.downloadFailed(
                "No output files found in S3"
            )
        }

        var downloaded: [URL] = []
        let total = Double(keys.count)

        for (index, key) in keys.enumerated() {
            let remoteURL = try s3ObjectURL(
                bucket: bucket, region: region, key: key
            )

            let filename = URL(fileURLWithPath: key)
                .lastPathComponent
            let destination =
                outputDirectory
                .appendingPathComponent(filename)

            let signer = AWSSignatureV4(
                accessKeyID: credentials.accessKeyID,
                secretAccessKey: credentials.secretAccessKey,
                region: region, service: "s3"
            )

            let headers = signer.sign(
                method: "GET", url: remoteURL,
                headers: [:], payload: nil
            )

            try await httpClient.download(
                url: remoteURL, to: destination,
                headers: headers, progress: nil
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
        let (region, bucket) = try requireAWSConfig(config)
        let credentials = try parseCredentials(config.apiKey)

        for prefix in [
            "input/\(job.assetID)/",
            "output/\(job.assetID)/"
        ] {
            let keys = try await listS3Objects(
                bucket: bucket, region: region,
                prefix: prefix, credentials: credentials
            )
            for key in keys {
                try await deleteS3Object(
                    bucket: bucket, region: region,
                    key: key, credentials: credentials
                )
            }
        }
    }
}
