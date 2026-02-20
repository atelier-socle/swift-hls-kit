// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing
import os

@testable import HLSKit

@Suite("URLSessionHTTPClient", .serialized)
struct URLSessionHTTPClientTests {

    // MARK: - Helpers

    private func makeClient() -> URLSessionHTTPClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: config)
        return URLSessionHTTPClient(session: session)
    }

    private func stubOK(
        statusCode: Int = 200,
        headers: [String: String] = [:],
        body: Data = Data()
    ) {
        StubURLProtocol.setHandler { request in
            guard let url = request.url,
                let resp = HTTPURLResponse(
                    url: url, statusCode: statusCode,
                    httpVersion: nil,
                    headerFields: headers
                )
            else {
                throw TranscodingError.encodingFailed(
                    "Mock response creation failed"
                )
            }
            return (resp, body)
        }
    }

    // MARK: - Request

    @Test("request returns status code and body")
    func requestStatusAndBody() async throws {
        stubOK(
            statusCode: 200,
            body: Data("hello".utf8)
        )
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/api")
        )

        let response = try await client.request(
            url: url, method: "GET",
            headers: [:], body: nil
        )

        #expect(response.statusCode == 200)
        #expect(
            String(data: response.body, encoding: .utf8)
                == "hello"
        )
    }

    @Test("request returns response headers")
    func requestHeaders() async throws {
        stubOK(headers: ["X-Custom": "value"])
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/headers")
        )

        let response = try await client.request(
            url: url, method: "GET",
            headers: [:], body: nil
        )

        #expect(response.headers["X-Custom"] == "value")
    }

    @Test("request sends custom headers")
    func requestSendsHeaders() async throws {
        let headerLock = OSAllocatedUnfairLock<String>(
            initialState: ""
        )
        StubURLProtocol.setHandler { request in
            let val =
                request.value(
                    forHTTPHeaderField: "Accept"
                ) ?? ""
            headerLock.withLock { $0 = val }
            guard let url = request.url,
                let resp = HTTPURLResponse(
                    url: url, statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )
            else {
                throw TranscodingError.encodingFailed(
                    "Mock"
                )
            }
            return (resp, Data())
        }
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/h")
        )

        _ = try await client.request(
            url: url, method: "POST",
            headers: ["Accept": "application/json"],
            body: Data("x".utf8)
        )

        let accept = headerLock.withLock { $0 }
        #expect(accept == "application/json")
    }

    @Test("request with error status returns code")
    func requestErrorStatus() async throws {
        stubOK(statusCode: 500)
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/err")
        )

        let response = try await client.request(
            url: url, method: "GET",
            headers: [:], body: nil
        )

        #expect(response.statusCode == 500)
    }

    // MARK: - Upload

    @Test("upload returns response")
    func uploadReturnsResponse() async throws {
        stubOK(statusCode: 200, body: Data("ok".utf8))
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/upload")
        )
        let tempFile =
            FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-upload.bin")
        try Data("content".utf8).write(to: tempFile)
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
    }

    @Test("upload calls progress callback")
    func uploadProgress() async throws {
        stubOK(statusCode: 200)
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/up-prog")
        )
        let tempFile =
            FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-up-prog.bin")
        try Data("c".utf8).write(to: tempFile)
        defer {
            try? FileManager.default.removeItem(
                at: tempFile
            )
        }

        actor Cap {
            var values: [Double] = []
            func add(_ v: Double) { values.append(v) }
        }
        let cap = Cap()

        _ = try await client.upload(
            url: url, fileURL: tempFile,
            method: "PUT", headers: [:],
            progress: { v in Task { await cap.add(v) } }
        )

        try await Task.sleep(for: .milliseconds(50))
        let values = await cap.values
        #expect(!values.isEmpty)
    }

    // MARK: - Download

    @Test("download writes data to file")
    func downloadWritesFile() async throws {
        let content = Data("downloaded".utf8)
        stubOK(statusCode: 200, body: content)
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/dl")
        )
        let dest =
            FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-dl.bin")
        defer {
            try? FileManager.default.removeItem(at: dest)
        }

        try await client.download(
            url: url, to: dest,
            headers: [:], progress: nil
        )

        let data = try Data(contentsOf: dest)
        #expect(data == content)
    }

    @Test("download throws on HTTP error")
    func downloadHTTPError() async throws {
        stubOK(statusCode: 500)
        defer { StubURLProtocol.setHandler(nil) }

        let client = makeClient()
        let url = try #require(
            URL(string: "https://test.local/dl-fail")
        )
        let dest =
            FileManager.default.temporaryDirectory
            .appendingPathComponent("stub-dl-err.bin")
        defer {
            try? FileManager.default.removeItem(at: dest)
        }

        await #expect(throws: TranscodingError.self) {
            try await client.download(
                url: url, to: dest,
                headers: [:], progress: nil
            )
        }
    }
}
