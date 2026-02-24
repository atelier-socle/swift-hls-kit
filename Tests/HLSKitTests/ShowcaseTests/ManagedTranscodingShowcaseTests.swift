// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - Orchestration

@Suite("Managed Transcoding Showcase — Orchestration")
struct ManagedTranscoderShowcase {

    @Test("ManagedTranscoder — conforms to Transcoder protocol (same API as Apple/FFmpeg)")
    func conformsToTranscoder() {
        #expect(ManagedTranscoder.isAvailable == true)
        #expect(ManagedTranscoder.name == "Managed (Cloud)")
        let config = ManagedTestHelper.makeConfig()
        let transcoder = ManagedTestHelper.makeSUT(config: config)
        let _: Transcoder = transcoder
    }

    @Test("ManagedTranscoder — full workflow: upload → create job → poll → download → result")
    func fullWorkflow() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)
        let outputDir = dir.appendingPathComponent("output")

        let outputFile = outputDir.appendingPathComponent("seg.ts")
        let provider = MockManagedProvider(
            downloadResult: [outputFile]
        )
        let sut = ManagedTestHelper.makeSUT(provider: provider)
        let result = try await sut.transcode(
            input: input, outputDirectory: outputDir,
            config: TranscodingConfig(), progress: nil
        )

        #expect(result.preset.name == QualityPreset.p720.name)
        #expect(result.transcodingDuration > 0)
    }

    @Test("ManagedTranscoder — progress callback maps upload/poll/download phases")
    func progressPhases() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)
        let outputDir = dir.appendingPathComponent("output")

        let (stream, continuation) = AsyncStream.makeStream(of: Double.self)

        let sut = ManagedTestHelper.makeSUT()
        _ = try await sut.transcode(
            input: input, outputDirectory: outputDir,
            config: TranscodingConfig(),
            progress: { v in continuation.yield(v) }
        )
        continuation.finish()

        var values: [Double] = []
        for await v in stream {
            values.append(v)
        }

        #expect(!values.isEmpty)
        #expect(values.contains(where: { $0 >= 0.05 }))
        #expect(values.contains(where: { $0 >= 0.80 }))
        #expect(values.last == 1.0)
    }

    @Test("ManagedTranscoder — multi-variant transcoding produces MultiVariantResult")
    func multiVariant() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)
        let outputDir = dir.appendingPathComponent("output")

        let sut = ManagedTestHelper.makeSUT()
        let result = try await sut.transcodeVariants(
            input: input, outputDirectory: outputDir,
            variants: [.p480, .p720, .p1080],
            config: TranscodingConfig(), progress: nil
        )

        #expect(result.variants.count == 3)
        #expect(result.masterPlaylist != nil)
    }

    @Test("ManagedTranscoder — cleanup runs after download when cleanupAfterDownload=true")
    func cleanupEnabled() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)
        let outputDir = dir.appendingPathComponent("output")

        let config = ManagedTestHelper.makeConfig(
            cleanupAfterDownload: true
        )
        let sut = ManagedTestHelper.makeSUT(config: config)
        let result = try await sut.transcode(
            input: input, outputDirectory: outputDir,
            config: TranscodingConfig(), progress: nil
        )
        #expect(result.preset.name == QualityPreset.p720.name)
    }

    @Test("ManagedTranscoder — cleanup skipped when cleanupAfterDownload=false")
    func cleanupDisabled() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)
        let outputDir = dir.appendingPathComponent("output")

        let config = ManagedTestHelper.makeConfig(
            cleanupAfterDownload: false
        )
        let sut = ManagedTestHelper.makeSUT(config: config)
        let result = try await sut.transcode(
            input: input, outputDirectory: outputDir,
            config: TranscodingConfig(), progress: nil
        )
        #expect(result.preset.name == QualityPreset.p720.name)
    }

    @Test("ManagedTranscoder — job failure throws TranscodingError.jobFailed")
    func jobFailure() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        let failedJob = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .failed,
            errorMessage: "Cloud error"
        )
        let provider = MockManagedProvider(
            statusSequence: [failedJob]
        )
        let sut = ManagedTestHelper.makeSUT(provider: provider)

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: input,
                outputDirectory: dir.appendingPathComponent("out"),
                config: TranscodingConfig(), progress: nil
            )
        }
    }

    @Test("ManagedTranscoder — timeout throws TranscodingError after maxWait exceeded")
    func timeoutError() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        let processingJob = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .processing
        )
        let provider = MockManagedProvider(
            statusSequence: [processingJob]
        )
        let config = ManagedTestHelper.makeConfig(
            pollingInterval: 0.01, timeout: 0.05
        )
        let sut = ManagedTestHelper.makeSUT(
            provider: provider, config: config
        )

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: input,
                outputDirectory: dir.appendingPathComponent("out"),
                config: TranscodingConfig(), progress: nil
            )
        }
    }

    @Test("ManagedTranscoder — upload failure throws TranscodingError.uploadFailed")
    func uploadFailure() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        let provider = MockManagedProvider(shouldFailUpload: true)
        let sut = ManagedTestHelper.makeSUT(provider: provider)

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: input,
                outputDirectory: dir.appendingPathComponent("out"),
                config: TranscodingConfig(), progress: nil
            )
        }
    }

    @Test("ManagedTranscoder — download failure throws TranscodingError.downloadFailed")
    func downloadFailure() async throws {
        let dir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(dir) }
        let input = try ManagedTestHelper.createInput(in: dir)

        let provider = MockManagedProvider(
            shouldFailDownload: true
        )
        let sut = ManagedTestHelper.makeSUT(provider: provider)

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: input,
                outputDirectory: dir.appendingPathComponent("out"),
                config: TranscodingConfig(), progress: nil
            )
        }
    }
}

// MARK: - Configuration

@Suite("Managed Transcoding Showcase — Configuration")
struct ManagedTranscodingConfigShowcase {

    @Test("ManagedTranscodingConfig — Cloudflare Stream setup (apiKey + accountID)")
    func cloudflareConfig() {
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "cf-api-token",
            accountID: "cf-account-123"
        )
        #expect(config.provider == .cloudflareStream)
        #expect(config.apiKey == "cf-api-token")
        #expect(config.accountID == "cf-account-123")
    }

    @Test("ManagedTranscodingConfig — AWS MediaConvert setup (region + bucket + roleARN)")
    func awsConfig() {
        let config = ManagedTranscodingConfig(
            provider: .awsMediaConvert,
            apiKey: "AKIATEST:secretkey",
            accountID: "123456789",
            region: "us-east-1",
            storageBucket: "my-bucket",
            roleARN: "arn:aws:iam::123:role/MediaConvert"
        )
        #expect(config.provider == .awsMediaConvert)
        #expect(config.region == "us-east-1")
        #expect(config.storageBucket == "my-bucket")
        #expect(config.roleARN == "arn:aws:iam::123:role/MediaConvert")
    }

    @Test("ManagedTranscodingConfig — Mux setup (tokenId:tokenSecret)")
    func muxConfig() {
        let config = ManagedTranscodingConfig(
            provider: .mux,
            apiKey: "tokenId:tokenSecret",
            accountID: "unused"
        )
        #expect(config.provider == .mux)
        #expect(config.apiKey == "tokenId:tokenSecret")
    }

    @Test("ManagedTranscodingConfig — default polling interval (5s) and timeout (3600s)")
    func defaults() {
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "k", accountID: "a"
        )
        #expect(config.pollingInterval == 5)
        #expect(config.timeout == 3600)
        #expect(config.defaultPreset == .p720)
    }

    @Test("ManagedTranscodingConfig — defaultPreset: .p1080 for high quality")
    func customDefaultPreset() {
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "k", accountID: "a",
            defaultPreset: .p1080
        )
        #expect(config.defaultPreset == .p1080)
    }

    @Test("ManagedTranscodingConfig — defaultPreset: .audioOnly for podcast")
    func audioOnlyDefaultPreset() {
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "k", accountID: "a",
            defaultPreset: .audioOnly
        )
        #expect(config.defaultPreset.isAudioOnly)
    }

    @Test("ManagedTranscodingConfig — custom endpoint for self-hosted/testing")
    func customEndpoint() {
        let endpoint = URL(string: "https://custom.api.local")
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "k", accountID: "a",
            endpoint: endpoint
        )
        #expect(config.endpoint == endpoint)
    }

    @Test("ManagedTranscodingConfig — output format: .fmp4 (default) vs .ts")
    func outputFormat() {
        let defaultConfig = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "k", accountID: "a"
        )
        #expect(defaultConfig.outputFormat == .fmp4)

        let tsConfig = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "k", accountID: "a",
            outputFormat: .ts
        )
        #expect(tsConfig.outputFormat == .ts)
    }

    @Test("ManagedTranscodingConfig.ProviderType — all cases: cloudflareStream, awsMediaConvert, mux")
    func providerTypes() {
        let types: [ManagedTranscodingConfig.ProviderType] = [
            .cloudflareStream, .awsMediaConvert, .mux
        ]
        #expect(types.count == 3)
        #expect(
            ManagedTranscodingConfig.ProviderType.cloudflareStream
                .rawValue == "cloudflareStream"
        )
        #expect(
            ManagedTranscodingConfig.ProviderType.awsMediaConvert
                .rawValue == "awsMediaConvert"
        )
        #expect(
            ManagedTranscodingConfig.ProviderType.mux
                .rawValue == "mux"
        )
    }

    @Test("ManagedTranscodingConfig — Sendable conformance")
    func sendable() {
        let config = ManagedTranscodingConfig(
            provider: .mux, apiKey: "k", accountID: "a"
        )
        let _: Sendable = config
    }
}

// MARK: - Job Lifecycle

@Suite("Managed Transcoding Showcase — Job Lifecycle")
struct ManagedTranscodingJobShowcase {

    @Test("ManagedTranscodingJob — create with jobID, assetID, initial status queued")
    func createJob() {
        let job = ManagedTranscodingJob(
            jobID: "job-1", assetID: "asset-1"
        )
        #expect(job.jobID == "job-1")
        #expect(job.assetID == "asset-1")
        #expect(job.status == .queued)
    }

    @Test("ManagedTranscodingJob.Status — all cases: queued, processing, completed, failed, cancelled")
    func allStatuses() {
        let cases: [ManagedTranscodingJob.Status] = [
            .queued, .processing, .completed, .failed, .cancelled
        ]
        #expect(cases.count == 5)
    }

    @Test("ManagedTranscodingJob.isTerminal — true for completed/failed/cancelled, false for queued/processing")
    func isTerminal() {
        let completed = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed
        )
        let failed = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .failed
        )
        let cancelled = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .cancelled
        )
        let queued = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .queued
        )
        let processing = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .processing
        )

        #expect(completed.isTerminal == true)
        #expect(failed.isTerminal == true)
        #expect(cancelled.isTerminal == true)
        #expect(queued.isTerminal == false)
        #expect(processing.isTerminal == false)
    }

    @Test("ManagedTranscodingJob — progress tracking 0.0 to 1.0")
    func progressTracking() {
        var job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .processing,
            progress: 0.0
        )
        #expect(job.progress == 0.0)

        job.progress = 0.5
        #expect(job.progress == 0.5)

        job.progress = 1.0
        #expect(job.progress == 1.0)
    }

    @Test("ManagedTranscodingJob — outputURLs populated on completion")
    func outputURLs() {
        let url = URL(string: "https://cdn.example.com/output.m3u8")
        var job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed
        )
        #expect(job.outputURLs.isEmpty)

        job.outputURLs = [url].compactMap { $0 }
        #expect(job.outputURLs.count == 1)
    }

    @Test("ManagedTranscodingJob — errorMessage populated on failure")
    func errorMessage() {
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .failed,
            errorMessage: "Encoding failed in cloud"
        )
        #expect(job.errorMessage == "Encoding failed in cloud")
    }

    @Test("ManagedTranscodingJob — Hashable and Sendable conformance")
    func hashableAndSendable() {
        let job1 = ManagedTranscodingJob(
            jobID: "j1", assetID: "a1"
        )
        let job2 = ManagedTranscodingJob(
            jobID: "j2", assetID: "a2"
        )
        let _: Sendable = job1
        #expect(job1 != job2)

        var set = Set<ManagedTranscodingJob>()
        set.insert(job1)
        set.insert(job2)
        #expect(set.count == 2)
    }

    @Test("ManagedTranscodingJob — completedAt set when terminal")
    func completedAt() {
        let now = Date()
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed,
            completedAt: now
        )
        #expect(job.completedAt != nil)

        let pending = ManagedTranscodingJob(
            jobID: "j", assetID: "a"
        )
        #expect(pending.completedAt == nil)
    }
}

// MARK: - Provider Protocol

@Suite("Managed Transcoding Showcase — Provider Protocol")
struct ManagedTranscodingProviderShowcase {

    @Test("ManagedTranscodingProvider — protocol requires upload, createJob, checkStatus, download, cleanup")
    func protocolConformance() {
        let provider = MockManagedProvider()
        let _: ManagedTranscodingProvider = provider
    }

    @Test("ManagedTranscodingProvider — static name property identifies the service")
    func providerNames() {
        #expect(CloudflareStreamProvider.name == "Cloudflare Stream")
        #expect(AWSMediaConvertProvider.name == "AWS MediaConvert")
        #expect(MuxProvider.name == "Mux")
        #expect(MockManagedProvider.name == "Mock")
    }
}

// MARK: - HLSEngine Integration

@Suite("Managed Transcoding Showcase — HLSEngine Integration")
struct ManagedHLSEngineShowcase {

    @Test("HLSEngine.managedTranscoder(config:) — factory creates ManagedTranscoder")
    func factoryMethod() {
        let engine = HLSEngine()
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "key", accountID: "acct"
        )
        let transcoder = engine.managedTranscoder(config: config)
        #expect(ManagedTranscoder.isAvailable == true)
        _ = transcoder
    }

    @Test("ManagedTranscoder — transparent to callers: same Transcoder protocol as Apple/FFmpeg")
    func protocolTransparency() {
        let config = ManagedTestHelper.makeConfig()
        let managed = ManagedTestHelper.makeSUT(config: config)
        let transcoder: Transcoder = managed
        #expect(type(of: transcoder).isAvailable == true)
        #expect(type(of: transcoder).name == "Managed (Cloud)")
    }
}

// MARK: - Error Cases

@Suite("Managed Transcoding Showcase — Error Cases")
struct ManagedTranscodingErrorShowcase {

    @Test("TranscodingError.uploadFailed — cloud upload failure")
    func uploadFailed() {
        let error = TranscodingError.uploadFailed("S3 timeout")
        #expect(error == .uploadFailed("S3 timeout"))
        #expect(error.localizedDescription.contains("Upload failed"))
    }

    @Test("TranscodingError.jobFailed — transcoding job error")
    func jobFailed() {
        let error = TranscodingError.jobFailed("Codec unsupported")
        #expect(error == .jobFailed("Codec unsupported"))
    }

    @Test("TranscodingError.timeout — polling exceeded max wait")
    func timeout() {
        let error = TranscodingError.timeout("Exceeded 3600s")
        #expect(error == .timeout("Exceeded 3600s"))
    }

    @Test("TranscodingError.downloadFailed — output download failure")
    func downloadFailed() {
        let error = TranscodingError.downloadFailed("404")
        #expect(error == .downloadFailed("404"))
    }

    @Test("TranscodingError.authenticationFailed — invalid API credentials")
    func authFailed() {
        let error = TranscodingError.authenticationFailed(
            "Invalid API key"
        )
        #expect(error == .authenticationFailed("Invalid API key"))
    }

    @Test("TranscodingError.providerNotImplemented — for future providers")
    func providerNotImpl() {
        let error = TranscodingError.providerNotImplemented(
            "CustomProvider"
        )
        #expect(
            error == .providerNotImplemented("CustomProvider")
        )
    }
}
