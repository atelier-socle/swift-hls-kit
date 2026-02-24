// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

#if canImport(os)
    import os
#else
    import Synchronization
#endif

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension URLSessionHTTPClientAllTests {

    @Suite("Streaming")
    struct StreamingTests {

        // MARK: - Helpers

        private func makeClient()
            -> URLSessionHTTPClient
        {
            let config =
                URLSessionConfiguration.ephemeral
            config.protocolClasses =
                [StubURLProtocol.self]
            let session = URLSession(
                configuration: config
            )
            return URLSessionHTTPClient(
                session: session
            )
        }

        private func stubOK(
            statusCode: Int = 200,
            headers: [String: String] = [:],
            body: Data = Data()
        ) {
            StubURLProtocol.setHandler { request in
                guard let url = request.url,
                    let resp = HTTPURLResponse(
                        url: url,
                        statusCode: statusCode,
                        httpVersion: nil,
                        headerFields: headers
                    )
                else {
                    throw
                        TranscodingError
                        .encodingFailed(
                            "Mock response failed"
                        )
                }
                return (resp, body)
            }
        }

        // MARK: - Download Progress

        @Test("download calls progress callback")
        func downloadProgress() async throws {
            stubOK(
                statusCode: 200,
                body: Data("progress-test".utf8)
            )
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/dl-prog"
                )
            )
            let dest =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-dl-prog.bin"
                )
            defer {
                try? FileManager.default.removeItem(
                    at: dest
                )
            }

            actor Cap {
                var values: [Double] = []
                func add(_ v: Double) {
                    values.append(v)
                }
            }
            let cap = Cap()

            try await client.download(
                url: url, to: dest,
                headers: [:],
                progress: { v in
                    Task { await cap.add(v) }
                }
            )

            try await Task.sleep(
                for: .milliseconds(50)
            )
            let values = await cap.values
            #expect(!values.isEmpty)
        }

        // MARK: - Upload Method & Headers

        @Test("upload sends correct HTTP method")
        func uploadMethodAndHeaders() async throws {
            #if canImport(os)
                let captured =
                    OSAllocatedUnfairLock<String>(
                        initialState: ""
                    )
            #else
                let captured = Mutex<String>("")
            #endif
            StubURLProtocol.setHandler { request in
                let method =
                    request.httpMethod ?? ""
                captured.withLock { $0 = method }
                guard let url = request.url,
                    let resp = HTTPURLResponse(
                        url: url, statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )
                else {
                    throw
                        TranscodingError
                        .encodingFailed("Mock")
                }
                return (resp, Data())
            }
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/up-method"
                )
            )
            let tempFile =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-up-meth.bin"
                )
            try Data("x".utf8).write(to: tempFile)
            defer {
                try? FileManager.default.removeItem(
                    at: tempFile
                )
            }

            _ = try await client.upload(
                url: url, fileURL: tempFile,
                method: "PUT", headers: [:],
                progress: nil
            )

            let method = captured.withLock { $0 }
            #expect(method == "PUT")
        }

        // MARK: - Upload Error Status

        @Test("upload returns error status code")
        func uploadErrorStatus() async throws {
            stubOK(
                statusCode: 500,
                body: Data("err".utf8)
            )
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/up-500"
                )
            )
            let tempFile =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-up-500.bin"
                )
            try Data("x".utf8).write(to: tempFile)
            defer {
                try? FileManager.default.removeItem(
                    at: tempFile
                )
            }

            let response = try await client.upload(
                url: url, fileURL: tempFile,
                method: "PUT", headers: [:],
                progress: nil
            )

            #expect(response.statusCode == 500)
        }

        // MARK: - Concurrent Uploads

        @Test("concurrent uploads do not interfere")
        func concurrentUploads() async throws {
            stubOK(statusCode: 200, body: Data("ok".utf8))
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(string: "https://test.local/concurrent")
            )
            let tmpDir = FileManager.default.temporaryDirectory
            let file1 = tmpDir.appendingPathComponent("conc1.bin")
            let file2 = tmpDir.appendingPathComponent("conc2.bin")
            try Data("upload1".utf8).write(to: file1)
            try Data("upload2".utf8).write(to: file2)
            defer {
                try? FileManager.default.removeItem(at: file1)
                try? FileManager.default.removeItem(at: file2)
            }

            async let r1 = client.upload(
                url: url, fileURL: file1,
                method: "PUT", headers: [:], progress: nil
            )
            async let r2 = client.upload(
                url: url, fileURL: file2,
                method: "PUT", headers: [:], progress: nil
            )
            let (resp1, resp2) = try await (r1, r2)
            #expect(resp1.statusCode == 200)
            #expect(resp2.statusCode == 200)
        }

        // MARK: - Streaming Upload

        @Test("upload streams from file")
        func uploadStreamsFromFile() async throws {
            stubOK(
                statusCode: 200,
                body: Data("ok".utf8)
            )
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/stream-up"
                )
            )
            let tempFile =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-stream.bin"
                )
            try Data(repeating: 0xAB, count: 1024)
                .write(to: tempFile)
            defer {
                try? FileManager.default.removeItem(
                    at: tempFile
                )
            }

            let response = try await client.upload(
                url: url, fileURL: tempFile,
                method: "PUT", headers: [:],
                progress: nil
            )

            #expect(response.statusCode == 200)
            #expect(!response.body.isEmpty)
        }
    }
}
