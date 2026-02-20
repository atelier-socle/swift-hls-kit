// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// AWS Elemental MediaConvert provider stub.
///
/// This provider is planned but not yet implemented. All methods
/// throw ``TranscodingError/providerNotImplemented(_:)`` with a
/// descriptive message.
///
/// - SeeAlso: ``ManagedTranscoder``,
///   ``ManagedTranscodingProvider``
struct AWSMediaConvertProvider: ManagedTranscodingProvider,
    Sendable
{

    static var name: String { "AWS MediaConvert" }

    func upload(
        fileURL: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> String {
        throw TranscodingError.providerNotImplemented(
            "AWS MediaConvert upload not yet implemented"
        )
    }

    func createJob(
        assetID: String,
        variants: [QualityPreset],
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        throw TranscodingError.providerNotImplemented(
            "AWS MediaConvert job creation not yet implemented"
        )
    }

    func checkStatus(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws -> ManagedTranscodingJob {
        throw TranscodingError.providerNotImplemented(
            "AWS MediaConvert status check not yet implemented"
        )
    }

    func download(
        job: ManagedTranscodingJob,
        outputDirectory: URL,
        config: ManagedTranscodingConfig,
        progress: (@Sendable (Double) -> Void)?
    ) async throws -> [URL] {
        throw TranscodingError.providerNotImplemented(
            "AWS MediaConvert download not yet implemented"
        )
    }

    func cleanup(
        job: ManagedTranscodingJob,
        config: ManagedTranscodingConfig
    ) async throws {
        throw TranscodingError.providerNotImplemented(
            "AWS MediaConvert cleanup not yet implemented"
        )
    }
}
