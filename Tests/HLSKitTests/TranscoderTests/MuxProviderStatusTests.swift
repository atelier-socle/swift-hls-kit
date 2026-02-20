// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MuxProvider — Status & Download")
struct MuxProviderStatusTests {

    // MARK: - Helpers

    private func makeConfig(
        endpoint: URL? = nil
    ) -> ManagedTranscodingConfig {
        ManagedTranscodingConfig(
            provider: .mux,
            apiKey: "tokenId:tokenSecret",
            accountID: "unused",
            endpoint: endpoint
        )
    }

    private func muxAssetStatusJSON(
        status: String,
        playbackID: String? = nil,
        errorType: String? = nil
    ) -> Data {
        var data: [String: Any] = [
            "id": "asset-1",
            "status": status
        ]
        if let pid = playbackID {
            data["playback_ids"] = [
                ["id": pid, "policy": "public"]
            ]
        }
        if let err = errorType {
            data["errors"] = ["type": err]
        }
        let json: [String: Any] = ["data": data]
        return
            (try? JSONSerialization.data(
                withJSONObject: json
            )) ?? Data()
    }

    // MARK: - Check Status

    @Test("checkStatus maps preparing to processing")
    func statusPreparing() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: self.muxAssetStatusJSON(
                        status: "preparing"
                    )
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "up-1"
        )

        let updated = try await provider.checkStatus(
            job: job, config: makeConfig()
        )

        #expect(updated.status == .processing)
    }

    @Test("checkStatus maps ready to completed")
    func statusReady() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: self.muxAssetStatusJSON(
                        status: "ready",
                        playbackID: "playback-123"
                    )
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "up-1"
        )

        let updated = try await provider.checkStatus(
            job: job, config: makeConfig()
        )

        #expect(updated.status == .completed)
        #expect(updated.progress == 1.0)
        #expect(updated.completedAt != nil)
        let outputURL = try #require(
            updated.outputURLs.first
        )
        #expect(
            outputURL.absoluteString.contains(
                "playback-123.m3u8"
            )
        )
    }

    @Test("checkStatus maps errored to failed")
    func statusErrored() async throws {
        let mock = MockAWSHTTP(
            requestHandler: { _, _, _, _ in
                HTTPResponse(
                    statusCode: 200, headers: [:],
                    body: self.muxAssetStatusJSON(
                        status: "errored",
                        errorType: "invalid_input"
                    )
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "asset-1", assetID: "up-1"
        )

        let updated = try await provider.checkStatus(
            job: job, config: makeConfig()
        )

        #expect(updated.status == .failed)
        #expect(updated.errorMessage == "invalid_input")
    }

    // MARK: - Download

    @Test("download fetches from playback URL")
    func downloadFromPlaybackURL() async throws {
        let playbackURL = try #require(
            URL(
                string:
                    "https://stream.mux.com/pb-1.m3u8"
            )
        )
        actor Capture {
            var url = ""
            func set(_ v: String) { url = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            downloadHandler: { url, _, _, _ in
                await cap.set(url.absoluteString)
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "a-1", assetID: "u-1",
            outputURLs: [playbackURL]
        )
        let tempDir = ManagedTestHelper.makeTempDir()
        defer { ManagedTestHelper.cleanup(tempDir) }

        let files = try await provider.download(
            job: job, outputDirectory: tempDir,
            config: makeConfig(), progress: nil
        )

        let url = await cap.url
        #expect(url.contains("stream.mux.com"))
        #expect(files.count == 1)
        #expect(
            files.first?.lastPathComponent
                == "master.m3u8"
        )
    }

    @Test("download no playback URL throws error")
    func downloadNoPlaybackURL() async {
        let provider = MuxProvider(
            httpClient: MockAWSHTTP()
        )
        let job = ManagedTranscodingJob(
            jobID: "a-1", assetID: "u-1"
        )

        await #expect(throws: TranscodingError.self) {
            try await provider.download(
                job: job,
                outputDirectory: URL(
                    fileURLWithPath: "/tmp"
                ),
                config: self.makeConfig(), progress: nil
            )
        }
    }

    // MARK: - Cleanup

    @Test("cleanup DELETE asset")
    func cleanupDeletesAsset() async throws {
        actor Capture {
            var method = ""
            var url = ""
            func set(m: String, u: String) {
                method = m
                url = u
            }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            requestHandler: { url, method, _, _ in
                await cap.set(
                    m: method, u: url.absoluteString
                )
                return HTTPResponse(
                    statusCode: 204, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "asset-del", assetID: "up-del"
        )

        try await provider.cleanup(
            job: job, config: makeConfig()
        )

        let method = await cap.method
        let url = await cap.url
        #expect(method == "DELETE")
        #expect(url.contains("video/v1/assets/asset-del"))
    }

    @Test("cleanup uses Basic auth")
    func cleanupUsesAuth() async throws {
        actor Capture {
            var auth = ""
            func set(_ v: String) { auth = v }
        }
        let cap = Capture()
        let mock = MockAWSHTTP(
            requestHandler: { _, _, headers, _ in
                let a = headers["Authorization"] ?? ""
                await cap.set(a)
                return HTTPResponse(
                    statusCode: 204, headers: [:],
                    body: Data()
                )
            }
        )
        let provider = MuxProvider(httpClient: mock)
        let job = ManagedTranscodingJob(
            jobID: "a-1", assetID: "u-1"
        )

        try await provider.cleanup(
            job: job, config: makeConfig()
        )

        let auth = await cap.auth
        #expect(auth.hasPrefix("Basic "))
    }

    // MARK: - Static

    @Test("MuxProvider name")
    func providerName() {
        #expect(MuxProvider.name == "Mux")
    }
}
