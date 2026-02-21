// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("HTTPClient")
struct HTTPClientTests {

    // MARK: - HTTPResponse

    @Test("HTTPResponse stores status code")
    func responseStatusCode() {
        let response = HTTPResponse(
            statusCode: 200, headers: [:], body: Data()
        )
        #expect(response.statusCode == 200)
    }

    @Test("HTTPResponse stores headers")
    func responseHeaders() {
        let response = HTTPResponse(
            statusCode: 200,
            headers: ["Content-Type": "application/json"],
            body: Data()
        )
        #expect(response.headers["Content-Type"] == "application/json")
    }

    @Test("HTTPResponse stores body")
    func responseBody() {
        let body = Data("test".utf8)
        let response = HTTPResponse(
            statusCode: 200, headers: [:], body: body
        )
        #expect(response.body == body)
    }

    @Test("HTTPResponse with error status code")
    func responseErrorCode() {
        let response = HTTPResponse(
            statusCode: 500, headers: [:], body: Data()
        )
        #expect(response.statusCode == 500)
    }

    @Test("HTTPResponse with empty body")
    func responseEmptyBody() {
        let response = HTTPResponse(
            statusCode: 204, headers: [:], body: Data()
        )
        #expect(response.body.isEmpty)
    }

    // MARK: - URLSessionHTTPClient Existence

    @Test("URLSessionHTTPClient can be instantiated")
    func urlSessionClientConformance() {
        let client = URLSessionHTTPClient()
        _ = client
    }
}
