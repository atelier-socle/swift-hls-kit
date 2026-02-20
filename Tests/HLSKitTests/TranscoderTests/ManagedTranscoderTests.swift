// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ManagedTranscoder")
struct ManagedTranscoderTests {

    // MARK: - Static Properties

    @Test("isAvailable always returns true")
    func isAvailable() {
        #expect(ManagedTranscoder.isAvailable)
    }

    @Test("name returns Managed (Cloud)")
    func name() {
        #expect(ManagedTranscoder.name == "Managed (Cloud)")
    }

    // MARK: - Transcode Success

    @Test("Successful transcode returns result")
    func successfulTranscode() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let outputDir = tempDir.appendingPathComponent(
            "output"
        )
        let outputFile = outputDir.appendingPathComponent(
            "out.ts"
        )

        let provider = MockManagedProvider(
            downloadResult: [outputFile]
        )
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
        )

        let result = try await sut.transcode(
            input: inputFile,
            outputDirectory: outputDir,
            config: TranscodingConfig(),
            progress: nil
        )

        #expect(result.preset == .p720)
        #expect(result.transcodingDuration > 0)
    }

    // MARK: - Progress

    @Test("Progress callback receives values")
    func progressReporting() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let outputDir = tempDir.appendingPathComponent(
            "output"
        )

        let provider = MockManagedProvider(downloadResult: [])
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
        )

        actor ProgressCollector {
            var values: [Double] = []
            func append(_ v: Double) { values.append(v) }
        }
        let collector = ProgressCollector()

        _ = try await sut.transcode(
            input: inputFile,
            outputDirectory: outputDir,
            config: TranscodingConfig(),
            progress: { value in
                Task {
                    await collector.append(value)
                }
            }
        )

        let values = await collector.values
        #expect(!values.isEmpty)
    }

    // MARK: - Validation Errors

    @Test("Throws sourceNotFound for missing input")
    func missingInput() async throws {
        let sut = ManagedTestHelper.makeSUT()
        let fakeInput = URL(
            fileURLWithPath: "/nonexistent/file.mp4"
        )
        let outputDir = URL(fileURLWithPath: "/tmp/output")

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: fakeInput,
                outputDirectory: outputDir,
                config: TranscodingConfig(),
                progress: nil
            )
        }
    }

    @Test("Throws authenticationFailed for empty API key")
    func emptyAPIKey() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "",
            accountID: "test-account"
        )
        let sut = ManagedTranscoder(
            config: config,
            provider: MockManagedProvider(),
            httpClient: MockManagedHTTPClient()
        )

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: inputFile,
                outputDirectory:
                    tempDir
                    .appendingPathComponent("output"),
                config: TranscodingConfig(),
                progress: nil
            )
        }
    }

    @Test("Throws authenticationFailed for empty account ID")
    func emptyAccountID() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let config = ManagedTranscodingConfig(
            provider: .cloudflareStream,
            apiKey: "test-key",
            accountID: ""
        )
        let sut = ManagedTranscoder(
            config: config,
            provider: MockManagedProvider(),
            httpClient: MockManagedHTTPClient()
        )

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: inputFile,
                outputDirectory:
                    tempDir
                    .appendingPathComponent("output"),
                config: TranscodingConfig(),
                progress: nil
            )
        }
    }

    // MARK: - Output Directory

    @Test("Creates output directory if missing")
    func createsOutputDirectory() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let outputDir = tempDir.appendingPathComponent(
            "new/nested/output"
        )

        let provider = MockManagedProvider(downloadResult: [])
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
        )

        _ = try await sut.transcode(
            input: inputFile,
            outputDirectory: outputDir,
            config: TranscodingConfig(),
            progress: nil
        )

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(
            atPath: outputDir.path, isDirectory: &isDir
        )
        #expect(exists)
        #expect(isDir.boolValue)
    }

    @Test("Throws if output path is a file")
    func outputPathIsFile() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let outputPath = tempDir.appendingPathComponent(
            "notadir"
        )
        try Data([0x01]).write(to: outputPath)

        let provider = MockManagedProvider(downloadResult: [])
        let sut = ManagedTestHelper.makeSUT(
            provider: provider
        )

        await #expect(throws: TranscodingError.self) {
            try await sut.transcode(
                input: inputFile,
                outputDirectory: outputPath,
                config: TranscodingConfig(),
                progress: nil
            )
        }
    }

    // MARK: - Cleanup

    @Test("Cleanup is skipped when disabled")
    func cleanupSkipped() async throws {
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let inputFile = try ManagedTestHelper.createInput(
            in: tempDir
        )
        let config = ManagedTestHelper.makeConfig(
            cleanupAfterDownload: false
        )
        let provider = MockManagedProvider(downloadResult: [])
        let sut = ManagedTranscoder(
            config: config,
            provider: provider,
            httpClient: MockManagedHTTPClient()
        )

        let result = try await sut.transcode(
            input: inputFile,
            outputDirectory:
                tempDir.appendingPathComponent("output"),
            config: TranscodingConfig(),
            progress: nil
        )

        #expect(result.preset == .p720)
    }
}
