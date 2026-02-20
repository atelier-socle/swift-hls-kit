// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Testing

@testable import HLSKit

@Suite("TranscodingError")
struct TranscodingErrorTests {

    // MARK: - Error Descriptions

    @Test("All error cases have non-empty descriptions")
    func allDescriptions() {
        let errors: [TranscodingError] = [
            .sourceNotFound("missing.mp4"),
            .unsupportedSourceFormat("avi"),
            .outputDirectoryError("/bad/path"),
            .codecNotAvailable("h265"),
            .hardwareEncoderNotAvailable("VT"),
            .encodingFailed("buffer overflow"),
            .decodingFailed("corrupt frame"),
            .cancelled,
            .invalidConfig("negative bitrate"),
            .transcoderNotAvailable("no FFmpeg"),
            .uploadFailed("upload error"),
            .jobFailed("job error"),
            .timeout("timeout error"),
            .downloadFailed("download error"),
            .providerNotImplemented("not implemented"),
            .authenticationFailed("auth error")
        ]
        for error in errors {
            let description = error.errorDescription
            #expect(description != nil)
            #expect(description?.isEmpty == false)
        }
    }

    @Test("sourceNotFound includes message")
    func sourceNotFoundMessage() {
        let error = TranscodingError.sourceNotFound(
            "test.mp4"
        )
        let desc = error.errorDescription ?? ""
        #expect(desc.contains("test.mp4"))
    }

    @Test("cancelled has description")
    func cancelledDescription() {
        let desc =
            TranscodingError.cancelled.errorDescription ?? ""
        #expect(desc.contains("cancelled"))
    }

    // MARK: - Hashable

    @Test("Hashable conformance")
    func hashable() {
        let e1 = TranscodingError.cancelled
        let e2 = TranscodingError.cancelled
        #expect(e1 == e2)
        let set: Set<TranscodingError> = [
            .cancelled,
            .sourceNotFound("a"),
            .sourceNotFound("a")
        ]
        #expect(set.count == 2)
    }

    @Test("Different errors are not equal")
    func notEqual() {
        let e1 = TranscodingError.cancelled
        let e2 = TranscodingError.sourceNotFound("x")
        #expect(e1 != e2)
    }
}
