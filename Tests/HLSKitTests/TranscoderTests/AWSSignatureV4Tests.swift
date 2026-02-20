// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("AWSSignatureV4")
struct AWSSignatureV4Tests {

    private let signer = AWSSignatureV4(
        accessKeyID: "AKIAIOSFODNN7EXAMPLE",
        secretAccessKey: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
        region: "us-east-1",
        service: "s3"
    )

    private let fixedDate = Date(
        timeIntervalSinceReferenceDate: 800_000_000
    )

    @Test("sign produces Authorization header")
    func signProducesAuthorizationHeader() throws {
        let url = try #require(
            URL(string: "https://example.s3.us-east-1.amazonaws.com/test")
        )

        let headers = signer.sign(
            method: "GET", url: url,
            headers: [:], payload: nil,
            date: fixedDate
        )

        let auth = try #require(headers["Authorization"])
        #expect(auth.hasPrefix("AWS4-HMAC-SHA256"))
        #expect(auth.contains("Credential=AKIAIOSFODNN7EXAMPLE"))
        #expect(auth.contains("Signature="))
    }

    @Test("sign includes x-amz-date header")
    func signIncludesAmzDate() throws {
        let url = try #require(
            URL(string: "https://example.s3.us-east-1.amazonaws.com/test")
        )

        let headers = signer.sign(
            method: "GET", url: url,
            headers: [:], payload: nil,
            date: fixedDate
        )

        let amzDate = try #require(headers["x-amz-date"])
        #expect(amzDate.contains("T"))
        #expect(amzDate.hasSuffix("Z"))
    }

    @Test("sign includes x-amz-content-sha256 header")
    func signIncludesContentSha256() throws {
        let url = try #require(
            URL(string: "https://example.s3.us-east-1.amazonaws.com/test")
        )

        let headers = signer.sign(
            method: "GET", url: url,
            headers: [:], payload: nil,
            date: fixedDate
        )

        let sha = try #require(
            headers["x-amz-content-sha256"]
        )
        #expect(!sha.isEmpty)
    }

    @Test("Different payloads produce different signatures")
    func differentPayloadsDifferentSignatures() throws {
        let mcSigner = AWSSignatureV4(
            accessKeyID: "AKIA",
            secretAccessKey: "secret",
            region: "us-east-1",
            service: "mediaconvert"
        )

        let url = try #require(
            URL(string: "https://mc.us-east-1.amazonaws.com/jobs")
        )

        let headers1 = mcSigner.sign(
            method: "POST", url: url,
            headers: [:],
            payload: Data("payload-1".utf8),
            date: fixedDate
        )

        let headers2 = mcSigner.sign(
            method: "POST", url: url,
            headers: [:],
            payload: Data("payload-2".utf8),
            date: fixedDate
        )

        let sig1 = try #require(headers1["Authorization"])
        let sig2 = try #require(headers2["Authorization"])
        #expect(sig1 != sig2)
    }

    @Test("Empty payload uses UNSIGNED-PAYLOAD for S3")
    func unsignedPayloadForS3() throws {
        let url = try #require(
            URL(string: "https://bucket.s3.us-east-1.amazonaws.com/key")
        )

        let headers = signer.sign(
            method: "GET", url: url,
            headers: [:], payload: nil,
            date: fixedDate
        )

        #expect(
            headers["x-amz-content-sha256"]
                == "UNSIGNED-PAYLOAD"
        )
    }

    @Test("Non-S3 service hashes empty payload")
    func nonS3HashedEmptyPayload() throws {
        let mcSigner = AWSSignatureV4(
            accessKeyID: "AKIA",
            secretAccessKey: "secret",
            region: "us-east-1",
            service: "mediaconvert"
        )

        let url = try #require(
            URL(string: "https://mc.us-east-1.amazonaws.com/jobs")
        )

        let headers = mcSigner.sign(
            method: "GET", url: url,
            headers: [:], payload: nil,
            date: fixedDate
        )

        let sha = try #require(
            headers["x-amz-content-sha256"]
        )
        #expect(sha != "UNSIGNED-PAYLOAD")
        #expect(sha.count == 64)
    }

    @Test("SHA256 produces correct hash")
    func sha256Correctness() {
        let data = Data("hello".utf8)
        let hash = signer.hexString(signer.sha256(data))
        #expect(
            hash
                == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
        )
    }

    @Test("HMAC-SHA256 produces deterministic output")
    func hmacDeterministic() {
        let key = Data("key".utf8)
        let data = Data("message".utf8)
        let h1 = signer.hmacSHA256(key: key, data: data)
        let h2 = signer.hmacSHA256(key: key, data: data)
        #expect(h1 == h2)
        #expect(h1.count == 32)
    }
}
