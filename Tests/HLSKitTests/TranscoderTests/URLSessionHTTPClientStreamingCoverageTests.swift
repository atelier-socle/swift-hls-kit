// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

extension URLSessionHTTPClientAllTests {

    @Suite("Streaming Coverage")
    struct StreamingCoverageTests {

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

        // MARK: - Upload Response Headers

        @Test("upload returns response headers")
        func uploadResponseHeaders() async throws {
            stubOK(
                statusCode: 200,
                headers: ["X-Upload-Id": "abc123"],
                body: Data("ok".utf8)
            )
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/up-hdr"
                )
            )
            let tempFile =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-up-hdr.bin"
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

            #expect(response.statusCode == 200)
            #expect(
                response.headers["X-Upload-Id"]
                    == "abc123"
            )
        }

        // MARK: - Upload Network Error

        @Test("upload propagates network error")
        func uploadNetworkError() async throws {
            StubURLProtocol.setHandler { _ in
                throw TranscodingError.uploadFailed(
                    "Network unreachable"
                )
            }
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/up-net-err"
                )
            )
            let tempFile =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-up-net.bin"
                )
            try Data("x".utf8).write(to: tempFile)
            defer {
                try? FileManager.default.removeItem(
                    at: tempFile
                )
            }

            await #expect(throws: Error.self) {
                try await client.upload(
                    url: url, fileURL: tempFile,
                    method: "PUT", headers: [:],
                    progress: nil
                )
            }
        }

        // MARK: - Download Network Error

        @Test("download propagates network error")
        func downloadNetworkError() async throws {
            StubURLProtocol.setHandler { _ in
                throw TranscodingError.downloadFailed(
                    "Connection reset"
                )
            }
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/dl-net-err"
                )
            )
            let dest =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-dl-net.bin"
                )
            defer {
                try? FileManager.default.removeItem(
                    at: dest
                )
            }

            await #expect(throws: Error.self) {
                try await client.download(
                    url: url, to: dest,
                    headers: [:], progress: nil
                )
            }
        }

        // MARK: - Download Content-Length Progress

        @Test("download reports progress with known size")
        func downloadProgressWithSize() async throws {
            let body = Data(
                repeating: 0x42, count: 256
            )
            stubOK(
                statusCode: 200,
                headers: [
                    "Content-Length":
                        "\(body.count)"
                ],
                body: body
            )
            defer { StubURLProtocol.setHandler(nil) }

            let client = makeClient()
            let url = try #require(
                URL(
                    string:
                        "https://test.local/dl-cl"
                )
            )
            let dest =
                FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "stub-dl-cl.bin"
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
            let data = try Data(contentsOf: dest)
            #expect(data == body)
        }
    }
}
