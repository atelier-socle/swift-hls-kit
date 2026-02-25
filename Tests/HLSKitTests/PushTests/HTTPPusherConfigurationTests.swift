// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("HTTPPusherConfiguration", .timeLimit(.minutes(1)))
struct HTTPPusherConfigurationTests {

    @Test("httpPut preset values")
    func httpPutPreset() {
        let config = HTTPPusherConfiguration.httpPut(
            baseURL: "https://origin.example.com/live/"
        )
        #expect(config.method == .put)
        #expect(
            config.baseURL
                == "https://origin.example.com/live/"
        )
        #expect(config.headers.isEmpty)
    }

    @Test("httpPost preset values")
    func httpPostPreset() {
        let config = HTTPPusherConfiguration.httpPost(
            baseURL: "https://cdn.example.com/ingest/"
        )
        #expect(config.method == .post)
    }

    @Test("Auth token added to headers")
    func authToken() {
        let config = HTTPPusherConfiguration.httpPut(
            baseURL: "https://origin.example.com/",
            authToken: "my-secret-token"
        )
        #expect(
            config.headers["Authorization"]
                == "Bearer my-secret-token"
        )
    }

    @Test("s3Compatible preset includes correct headers")
    func s3Compatible() {
        let config = HTTPPusherConfiguration.s3Compatible(
            bucket: "my-bucket",
            prefix: "live/stream1",
            region: "us-east-1"
        )
        #expect(config.method == .put)
        #expect(
            config.baseURL.contains("my-bucket.s3.us-east-1")
        )
        #expect(config.headers["x-amz-acl"] == "public-read")
        #expect(
            config.headers["x-amz-storage-class"] == "STANDARD"
        )
    }

    @Test("Default content types")
    func defaultContentTypes() {
        let config = HTTPPusherConfiguration(
            baseURL: "https://example.com/"
        )
        #expect(
            config.playlistContentType
                == "application/vnd.apple.mpegurl"
        )
        #expect(config.segmentContentType == nil)
        #expect(config.includeContentLength)
    }

    @Test("Custom headers merge in init")
    func customHeaders() {
        let config = HTTPPusherConfiguration(
            baseURL: "https://example.com/",
            headers: ["X-Custom": "value", "X-Other": "val2"]
        )
        #expect(config.headers["X-Custom"] == "value")
        #expect(config.headers["X-Other"] == "val2")
    }
}
